#include "extensions.h"

struct wsd_Extensions {
    void *receiver;
    wsd_cb_valid_frame_rsv valid_frame_rsv;
};

wsd_Extensions *wsd_Extensions_create(void *receiver, wsd_cb_valid_frame_rsv valid_frame_rsv)
{
    wsd_Extensions *extensions = calloc(1, sizeof(wsd_Extensions));
    if (extensions == NULL) return NULL;

    extensions->receiver        = receiver;
    extensions->valid_frame_rsv = valid_frame_rsv;

    return extensions;
}

wsd_Extensions *wsd_Extensions_create_default()
{
    return wsd_Extensions_create(NULL, wsd_default_valid_frame_rsv);
}

void wsd_Extensions_destroy(wsd_Extensions *extensions)
{
    if (extensions == NULL) return;

    extensions->valid_frame_rsv = NULL;

    free(extensions);
}

int wsd_Extensions_valid_frame_rsv(wsd_Extensions *extensions, wsd_Frame *frame)
{
    wsd_cb_valid_frame_rsv cb = extensions->valid_frame_rsv;
    return cb(extensions->receiver, frame);
}

int wsd_default_valid_frame_rsv(void *self, wsd_Frame *frame)
{
    return !frame->rsv1 && !frame->rsv2 && !frame->rsv3;
}
