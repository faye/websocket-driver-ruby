#include "observer.h"

struct wsd_Observer {
    void *receiver;
    wsd_cb_on_error on_error;
    wsd_cb_on_message on_message;
    wsd_cb_on_close on_close;
    wsd_cb_on_frame on_ping;
    wsd_cb_on_frame on_pong;
    wsd_cb_on_frame on_frame;
};

wsd_Observer * wsd_Observer_create(void *receiver,
                                   wsd_cb_on_error on_error,
                                   wsd_cb_on_message on_message,
                                   wsd_cb_on_close on_close,
                                   wsd_cb_on_frame on_ping,
                                   wsd_cb_on_frame on_pong,
                                   wsd_cb_on_frame on_frame)
{
    wsd_Observer *observer = calloc(1, sizeof(wsd_Observer));
    if (observer == NULL) return NULL;

    observer->receiver   = receiver;
    observer->on_error   = on_error;
    observer->on_message = on_message;
    observer->on_close   = on_close;
    observer->on_ping    = on_ping;
    observer->on_pong    = on_pong;
    observer->on_frame   = on_frame;

    return observer;
}

void wsd_Observer_destroy(wsd_Observer *observer)
{
    if (observer == NULL) return;

    observer->receiver   = NULL;
    observer->on_error   = NULL;
    observer->on_message = NULL;
    observer->on_close   = NULL;
    observer->on_ping    = NULL;
    observer->on_pong    = NULL;
    observer->on_frame   = NULL;

    free(observer);
}

void wsd_Observer_on_error(wsd_Observer *observer, int code, char *message)
{
    wsd_cb_on_error cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_error;
    if (cb) cb(observer->receiver, code, message);
}

void wsd_Observer_on_message(wsd_Observer *observer, wsd_Message *message)
{
    wsd_cb_on_message cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_message;
    if (cb) cb(observer->receiver, message);
}

void wsd_Observer_on_close(wsd_Observer *observer, int code, uint64_t length, uint8_t *reason)
{
    wsd_cb_on_close cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_close;
    if (cb) cb(observer->receiver, code, length, reason);
}

void wsd_Observer_on_ping(wsd_Observer *observer, wsd_Frame *frame)
{
    wsd_cb_on_frame cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_ping;
    if (cb) cb(observer->receiver, frame);
}

void wsd_Observer_on_pong(wsd_Observer *observer, wsd_Frame *frame)
{
    wsd_cb_on_frame cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_pong;
    if (cb) cb(observer->receiver, frame);
}

void wsd_Observer_on_frame(wsd_Observer *observer, wsd_Frame *frame)
{
    wsd_cb_on_frame cb = NULL;

    if (observer == NULL) return;

    cb = observer->on_frame;
    if (cb) cb(observer->receiver, frame);
}
