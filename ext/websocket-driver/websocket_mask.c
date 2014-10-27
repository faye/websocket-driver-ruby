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
  int n, i, p, m;
  int mask_array[4];
  VALUE unmasked;

  if (mask == Qnil || RARRAY_LEN(mask) == 0) {
    return payload;
  }

  n = RARRAY_LEN(payload);
  unmasked = rb_ary_new2(n);

  for (i = 0; i < 4; i++) {
    mask_array[i] = NUM2INT(rb_ary_entry(mask, i));
  }

  for (i = 0; i < n; i++) {
    p = NUM2INT(rb_ary_entry(payload, i));
    m = mask_array[i % 4];
    rb_ary_store(unmasked, i, INT2NUM(p ^ m));
  }
  return unmasked;
}
