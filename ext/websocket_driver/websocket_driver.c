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
void    wsd_Driver_on_close(VALUE driver, int code, wsd_Chunk *reason);
void    wsd_Driver_on_ping(VALUE driver, wsd_Chunk *payload);
void    wsd_Driver_on_pong(VALUE driver, wsd_Chunk *payload);


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
            (wsd_cb_on_chunk) wsd_Driver_on_ping,
            (wsd_cb_on_chunk) wsd_Driver_on_pong);

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
    size_t length = RSTRING_LEN(chunk);
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

    wsd_Chunk *chunk = wsd_Chunk_alloc(message->length);
    if (chunk == NULL) return; // TODO signal error back to the parser

    wsd_Message_copy(message, chunk);
    argv[argc - 1] = (VALUE)wsd_Chunk_to_string(chunk, (wsd_cb_to_string)rb_str_new);

    wsd_Chunk_destroy(chunk);

    wsd_safe_rb_funcall2(driver, rb_intern("handle_message"), argc, argv);
}

void wsd_Driver_on_close(VALUE driver, int code, wsd_Chunk *reason)
{
    VALUE rcode = INT2FIX(code);
    VALUE rmsg  = (reason == NULL) ? rb_str_new2("") : (VALUE)wsd_Chunk_to_string(reason, (wsd_cb_to_string)rb_str_new);

    int argc = 2;
    VALUE argv[2] = { rcode, rmsg };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_close"), argc, argv);
}

void wsd_Driver_on_ping(VALUE driver, wsd_Chunk *payload)
{
    int argc = 1;
    VALUE string = (VALUE)wsd_Chunk_to_string(payload, (wsd_cb_to_string)rb_str_new);
    VALUE argv[1] = { string };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_ping"), argc, argv);
}

void wsd_Driver_on_pong(VALUE driver, wsd_Chunk *payload)
{
    int argc = 1;
    VALUE string = (VALUE)wsd_Chunk_to_string(payload, (wsd_cb_to_string)rb_str_new);
    VALUE argv[1] = { string };

    wsd_safe_rb_funcall2(driver, rb_intern("handle_pong"), argc, argv);
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
    size_t length = RSTRING_LEN(payload);
    char *data = RSTRING_PTR(payload);

    wsd_Chunk *chunk = NULL;
    wsd_Frame *frame = NULL;
    VALUE string;

    wsd_Unparser *unparser;
    Data_Get_Struct(rb_iv_get(self, "@unparser"), wsd_Unparser, unparser);
    if (unparser == NULL) return Qnil;

    frame = wsd_Frame_create();
    if (frame == NULL) return Qnil;

    frame->final  = (rb_ary_entry(head, 0) == Qtrue);
    frame->rsv1   = (rb_ary_entry(head, 1) == Qtrue);
    frame->rsv2   = (rb_ary_entry(head, 2) == Qtrue);
    frame->rsv3   = (rb_ary_entry(head, 3) == Qtrue);
    frame->opcode = NUM2INT(rb_ary_entry(head, 4));
    frame->length = length;

    wsd_Chunk_fill(frame->masking_key, 4, (uint8_t *)RSTRING_PTR(masking_key));

    frame->payload = wsd_Chunk_create(length, (uint8_t *)data);
    if (frame->payload == NULL) {
        wsd_Frame_destroy(frame);
        return Qnil;
    }

    chunk = wsd_Unparser_frame(unparser, frame);
    if (chunk == NULL) {
        wsd_Frame_destroy(frame);
        return Qnil;
    }

    string = (VALUE)wsd_Chunk_to_string(chunk, (wsd_cb_to_string)rb_str_new);

    wsd_Chunk_destroy(chunk);
    wsd_Frame_destroy(frame);

    return string;
}
