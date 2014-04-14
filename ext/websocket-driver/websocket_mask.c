#include <ruby.h>

VALUE WebSocket = Qnil;
VALUE WebSocketMask = Qnil;

void Init_websocket_mask();
VALUE method_websocket_mask(VALUE self, VALUE payload, VALUE mask);

void Init_websocket_mask() {
  WebSocket = rb_define_module("WebSocket");
  WebSocketMask = rb_define_module_under(WebSocket, "Mask");
  rb_define_singleton_method(WebSocketMask, "mask", method_websocket_mask, 2);
}

VALUE method_websocket_mask(VALUE self, VALUE payload, VALUE mask) {
  int n = RARRAY_LEN(payload), i, p, m;
  VALUE unmasked = rb_ary_new2(n);

  int mask_array[] = {
    NUM2INT(rb_ary_entry(mask, 0)),
    NUM2INT(rb_ary_entry(mask, 1)),
    NUM2INT(rb_ary_entry(mask, 2)),
    NUM2INT(rb_ary_entry(mask, 3))
  };

  for (i = 0; i < n; i++) {
    p = NUM2INT(rb_ary_entry(payload, i));
    m = mask_array[i % 4];
    rb_ary_store(unmasked, i, INT2NUM(p ^ m));
  }
  return unmasked;
}

