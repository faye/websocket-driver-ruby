#include "observer.h"

struct wsd_Observer {
    void *receiver;
    wsd_cb_on_message on_message;
    wsd_cb_on_frame on_frame;
};

wsd_Observer * wsd_Observer_create(void *receiver,
                                   wsd_cb_on_message on_message,
                                   wsd_cb_on_frame on_frame)
{
    wsd_Observer *observer = calloc(1, sizeof(wsd_Observer));
    if (observer == NULL) return NULL;

    observer->receiver   = receiver;
    observer->on_message = on_message;
    observer->on_frame   = on_frame;

    return observer;
}

void wsd_Observer_destroy(wsd_Observer *observer)
{
    if (observer == NULL) return;

    observer->receiver = NULL;
    observer->on_frame = NULL;

    free(observer);
}

void wsd_Observer_on_message(wsd_Observer *observer, wsd_Message *message)
{
    wsd_cb_on_message cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_message;
    if (cb) cb(observer->receiver, message);
}

void wsd_Observer_on_frame(wsd_Observer *observer, wsd_Frame *frame)
{
    wsd_cb_on_frame cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_frame;
    if (cb) cb(observer->receiver, frame);
}
