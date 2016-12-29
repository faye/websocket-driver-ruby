#ifndef _wsd_rb_util_h
#define _wsd_rb_util_h

#include <ruby.h>

typedef struct wsd_RubyCall wsd_RubyCall;

int     wsd_safe_rb_funcall2(VALUE self, ID method, int argc, VALUE *argv);
VALUE   wsd_rb_call_method(VALUE call);

#endif
