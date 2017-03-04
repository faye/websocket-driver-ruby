#include "rb_util.h"

struct wsd_RubyCall {
    VALUE self;
    ID method;
    int argc;
    VALUE argv[8];
};

VALUE wsd_safe_rb_funcall2(VALUE self, ID method, int argc, VALUE *argv)
{
    int i  = 0;
    int rc = 0;
    VALUE result;

    wsd_RubyCall *call = calloc(1, sizeof(wsd_RubyCall));
    if (call == NULL) return 1;

    call->self   = self;
    call->method = method;
    call->argc   = argc;

    for (i = 0; i < argc; i++) {
        call->argv[i] = argv[i];
    }

    result = rb_protect(wsd_rb_call_method, (VALUE)call, &rc);
    free(call);

    return result;
}

VALUE wsd_rb_call_method(VALUE call)
{
    wsd_RubyCall *c = (wsd_RubyCall *)call;
    return rb_funcall2(c->self, c->method, c->argc, c->argv);
}
