#include <ruby.h>
#include "parser.h"

void    Init_websocket_parser();

VALUE   wsd_WebSocketParser_initialize(VALUE self);
void    wsd_WebSocketParser_on_frame(VALUE self, wsd_Frame *frame);
VALUE   wsd_WebSocketParser_parse(VALUE self, VALUE chunk);

static VALUE wsd_RWebSocketParser = Qnil;

void Init_websocket_parser()
{
    wsd_RWebSocketParser = rb_define_class("WebSocketParser", rb_cObject);
    rb_define_method(wsd_RWebSocketParser, "initialize", wsd_WebSocketParser_initialize, 0);
    rb_define_method(wsd_RWebSocketParser, "parse", wsd_WebSocketParser_parse, 1);
}

void wsd_WebSocketParser_on_frame(VALUE self, wsd_Frame *frame)
{
    printf("------------------------------------------------------------------------\n");
    printf(" final: %d, rsv: [%d,%d,%d], opcode: %d, masked: %d, length: %llu\n",
            frame->final, frame->rsv1, frame->rsv2, frame->rsv3,
            frame->opcode, frame->masked, frame->length);
    printf("------------------------------------------------------------------------\n");

    char *msg = calloc(frame->length + 1, sizeof(char));
    memcpy(msg, frame->payload, frame->length);
    printf("[PAYLOAD] %s\n\n", msg);
    free(msg);
}

VALUE wsd_WebSocketParser_initialize(VALUE self)
{
    wsd_Parser *parser = wsd_Parser_create();
    if (parser == NULL) return Qnil;

    parser->observer = wsd_Observer_create(
            (void *) self,
            (wsd_cb_on_frame) wsd_WebSocketParser_on_frame);

    VALUE ruby_parser = Data_Wrap_Struct(rb_cObject, NULL, wsd_Parser_destroy, parser);
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
