#include "parser.h"
#include "unparser.h"
#include "rb_util.h"

void    Init_websocket_driver();

VALUE   wsd_WebSocketParser_initialize(VALUE self, VALUE driver, VALUE require_masking);
VALUE   wsd_WebSocketParser_parse(VALUE self, VALUE chunk);

VALUE   wsd_WebSocketUnparser_initialize(VALUE self, VALUE driver, VALUE masking);
VALUE   wsd_WebSocketUnparser_frame(VALUE self, VALUE head, VALUE masking_key, VALUE payload);

int     wsd_Driver_valid_frame_rsv(VALUE driver, wsd_Frame *frame);

void    wsd_Driver_on_error(VALUE driver, int code, char *reason);
void    wsd_Driver_on_message(VALUE driver, wsd_Message *message);
void    wsd_Driver_on_close(VALUE driver, int code, uint64_t length, uint8_t *reason);
void    wsd_Driver_on_ping(VALUE driver, wsd_Frame *frame);
void    wsd_Driver_on_pong(VALUE driver, wsd_Frame *frame);
void    wsd_Driver_on_frame(VALUE driver, wsd_Frame *frame);

void Init_websocket_driver()
{
    VALUE WSN = rb_define_module("WebSocketNative");

    VALUE Parser = rb_define_class_under(WSN, "Parser", rb_cObject);
    rb_define_method(Parser, "initialize", wsd_WebSocketParser_initialize, 2);
    rb_define_method(Parser, "parse", wsd_WebSocketParser_parse, 1);

    VALUE Unparser = rb_define_class_under(WSN, "Unparser", rb_cObject);
    rb_define_method(Unparser, "initialize", wsd_WebSocketUnparser_initialize, 2);
    rb_define_method(Unparser, "frame", wsd_WebSocketUnparser_frame, 3);
}

VALUE wsd_WebSocketParser_initialize(VALUE self, VALUE driver, VALUE require_masking)
{
    wsd_Extensions *extensions = NULL;
    wsd_Observer *observer = NULL;
    wsd_Parser *parser = NULL;
    VALUE ruby_parser;

    extensions = wsd_Extensions_create(
            (void *) driver,
            (wsd_cb_valid_frame_rsv) wsd_Driver_valid_frame_rsv);

    if (extensions == NULL) return Qnil;

    observer = wsd_Observer_create(
            (void *) driver,
            (wsd_cb_on_error) wsd_Driver_on_error,
            (wsd_cb_on_message) wsd_Driver_on_message,
            (wsd_cb_on_close) wsd_Driver_on_close,
            (wsd_cb_on_frame) wsd_Driver_on_ping,
            (wsd_cb_on_frame) wsd_Driver_on_pong,
            (wsd_cb_on_frame) wsd_Driver_on_frame);

    if (observer == NULL) {
        wsd_Extensions_destroy(extensions);
        return Qnil;
    }

    parser = wsd_Parser_create(extensions, observer, require_masking == Qtrue ? 1 : 0);
    if (parser == NULL) {
        wsd_Extensions_destroy(extensions);
        wsd_Observer_destroy(observer);
        return Qnil;
    }

    ruby_parser = Data_Wrap_Struct(rb_cObject, NULL, wsd_Parser_destroy, parser);
    rb_iv_set(self, "@parser", ruby_parser);

    return Qnil;
}

VALUE wsd_WebSocketParser_parse(VALUE self, VALUE chunk)
{
    uint64_t length = RSTRING_LEN(chunk);
    char *data = RSTRING_PTR(chunk);

    wsd_Parser *parser;
    Data_Get_Struct(rb_iv_get(self, "@parser"), wsd_Parser, parser);
    if (parser == NULL) return Qnil;

    wsd_Parser_parse(parser, length, (uint8_t *)data);

    return Qnil;
}

int wsd_Driver_valid_frame_rsv(VALUE driver, wsd_Frame *frame)
{
    VALUE rsv1   = frame->rsv1 ? Qtrue : Qfalse;
    VALUE rsv2   = frame->rsv2 ? Qtrue : Qfalse;
    VALUE rsv3   = frame->rsv3 ? Qtrue : Qfalse;
    VALUE opcode = INT2FIX(frame->opcode);

    int argc      = 4;
    VALUE argv[4] = { rsv1, rsv2, rsv3, opcode };

    VALUE result = wsd_safe_rb_funcall2(driver, rb_intern("valid_frame_rsv?"), argc, argv);

    return result == Qtrue;
}

void wsd_Driver_on_error(VALUE driver, int code, char *reason)
{
    VALUE rcode   = INT2FIX(code);
    VALUE rmsg    = rb_str_new2(reason);

    int argc      = 2;
    VALUE argv[2] = { rcode, rmsg };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_error"), argc, argv);
}

void wsd_Driver_on_message(VALUE driver, wsd_Message *message)
{
    VALUE opcode = INT2FIX(message->opcode);
    VALUE rsv1   = message->rsv1 ? Qtrue : Qfalse;
    VALUE rsv2   = message->rsv2 ? Qtrue : Qfalse;
    VALUE rsv3   = message->rsv3 ? Qtrue : Qfalse;

    int argc = 5;
    VALUE argv[5] = { opcode, rsv1, rsv2, rsv3 };

    uint8_t *data = NULL;
    uint64_t copied = 0;

    data = calloc(message->length, sizeof(uint8_t));
    if (data == NULL) return; // TODO signal error back to the parser

    copied = wsd_Message_copy(message, data);
    argv[argc - 1] = rb_str_new((char *)data, copied);

    free(data);

    wsd_safe_rb_funcall2(driver, rb_intern("handle_message"), argc, argv);
}

void wsd_Driver_on_close(VALUE driver, int code, uint64_t length, uint8_t *reason)
{
    VALUE rcode = INT2FIX(code);
    VALUE rmsg  = (reason == NULL) ? rb_str_new2("") : rb_str_new((char *)reason, length);

    int argc = 2;
    VALUE argv[2] = { rcode, rmsg };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_close"), argc, argv);
}

void wsd_Driver_on_ping(VALUE driver, wsd_Frame *frame)
{
    int argc = 1;
    VALUE string = rb_str_new((char *)frame->payload, frame->length);
    VALUE argv[1] = { string };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_ping"), argc, argv);
}

void wsd_Driver_on_pong(VALUE driver, wsd_Frame *frame)
{
    int argc = 1;
    VALUE string = rb_str_new((char *)frame->payload, frame->length);
    VALUE argv[1] = { string };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_pong"), argc, argv);
}

void wsd_Driver_on_frame(VALUE driver, wsd_Frame *frame)
{
    char *msg = NULL;

    printf("------------------------------------------------------------------------\n");
    printf(" final: %d, rsv: [%d,%d,%d], opcode: %d, masked: %d, length: %" PRIu64 "\n",
            frame->final, frame->rsv1, frame->rsv2, frame->rsv3,
            frame->opcode, frame->masked, frame->length);
    printf("------------------------------------------------------------------------\n");

    msg = calloc(frame->length + 1, sizeof(char));
    memcpy(msg, frame->payload, frame->length);
    printf("[PAYLOAD] %s\n\n", msg);
    free(msg);
}

VALUE wsd_WebSocketUnparser_initialize(VALUE self, VALUE driver, VALUE masking)
{
    wsd_Unparser *unparser = NULL;
    VALUE ruby_unparser;

    unparser = wsd_Unparser_create(masking == Qtrue ? 1 : 0);
    if (unparser == NULL) return Qnil;

    ruby_unparser = Data_Wrap_Struct(rb_cObject, NULL, wsd_Unparser_destroy, unparser);
    rb_iv_set(self, "@unparser", ruby_unparser);

    return Qnil;
}

VALUE wsd_WebSocketUnparser_frame(VALUE self, VALUE head, VALUE masking_key, VALUE payload)
{
    uint64_t length = RSTRING_LEN(payload);
    char *data = RSTRING_PTR(payload);

    wsd_Frame *frame = NULL;
    uint64_t buflen = 0;
    uint8_t *buf = NULL;
    VALUE string;

    wsd_Unparser *unparser;
    Data_Get_Struct(rb_iv_get(self, "@unparser"), wsd_Unparser, unparser);
    if (unparser == NULL) return Qnil;

    frame = wsd_Frame_create();
    if (frame == NULL) return Qnil;

    frame->payload = calloc(length, sizeof(uint8_t));
    if (frame->payload == NULL) {
        wsd_Frame_destroy(frame);
        return Qnil;
    }

    frame->final  = (rb_ary_entry(head, 0) == Qtrue);
    frame->rsv1   = (rb_ary_entry(head, 1) == Qtrue);
    frame->rsv2   = (rb_ary_entry(head, 2) == Qtrue);
    frame->rsv3   = (rb_ary_entry(head, 3) == Qtrue);
    frame->opcode = NUM2INT(rb_ary_entry(head, 4));
    frame->length = length;

    memcpy(frame->masking_key, RSTRING_PTR(masking_key), 4);
    memcpy(frame->payload, data, length);

    buflen = wsd_Unparser_frame(unparser, frame, &buf);
    wsd_Frame_destroy(frame);

    string = rb_str_new((char *)buf, buflen);
    free(buf);

    return string;
}
