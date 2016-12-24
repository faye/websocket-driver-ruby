#include "observer.h"

wsd_Observer * wsd_Observer_create(void *receiver, wsd_cb_on_frame on_frame)
{
    wsd_Observer *observer = calloc(1, sizeof(wsd_Observer));
    if (observer == NULL) return NULL;

    observer->receiver = receiver;
    observer->on_frame = on_frame;

    return observer;
}

void wsd_Observer_destroy(wsd_Observer *observer)
{
    if (observer == NULL) return;

    observer->receiver = NULL;
    observer->on_frame = NULL;

    free(observer);
}

void wsd_Observer_on_frame(wsd_Observer *observer, wsd_Frame *frame)
{
    wsd_cb_on_frame cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_frame;
    if (cb) cb(observer->receiver, frame);
}
