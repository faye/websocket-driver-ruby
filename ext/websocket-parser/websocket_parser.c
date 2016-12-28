#include "parser.h"
#include "rb_util.h"

void    Init_websocket_parser();

VALUE   wsd_WebSocketParser_initialize(VALUE self, VALUE driver, VALUE require_masking);
VALUE   wsd_WebSocketParser_parse(VALUE self, VALUE chunk);

void    wsd_Driver_on_error(VALUE driver, int code, char *message);
void    wsd_Driver_on_message(VALUE driver, wsd_Message *message);
void    wsd_Driver_on_ping(VALUE driver, wsd_Frame *frame);
void    wsd_Driver_on_pong(VALUE driver, wsd_Frame *frame);
void    wsd_Driver_on_frame(VALUE driver, wsd_Frame *frame);

static VALUE wsd_RWebSocketParser = Qnil;

void Init_websocket_parser()
{
    wsd_RWebSocketParser = rb_define_class("WebSocketParser", rb_cObject);
    rb_define_method(wsd_RWebSocketParser, "initialize", wsd_WebSocketParser_initialize, 2);
    rb_define_method(wsd_RWebSocketParser, "parse", wsd_WebSocketParser_parse, 1);
}

VALUE wsd_WebSocketParser_initialize(VALUE self, VALUE driver, VALUE require_masking)
{
    wsd_Observer *observer = NULL;
    wsd_Parser *parser = NULL;
    VALUE ruby_parser;

    observer = wsd_Observer_create(
            (void *) driver,
            (wsd_cb_on_error) wsd_Driver_on_error,
            (wsd_cb_on_message) wsd_Driver_on_message,
            (wsd_cb_on_frame) wsd_Driver_on_ping,
            (wsd_cb_on_frame) wsd_Driver_on_pong,
            (wsd_cb_on_frame) wsd_Driver_on_frame);

    if (observer == NULL) return Qnil;

    parser = wsd_Parser_create(observer, require_masking == Qtrue ? 1 : 0);
    if (parser == NULL) return Qnil;

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

void wsd_Driver_on_error(VALUE driver, int code, char *message)
{
    VALUE rcode   = INT2FIX(code);
    VALUE rmsg    = rb_str_new2(message);
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
