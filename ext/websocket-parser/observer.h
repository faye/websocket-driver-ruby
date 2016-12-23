#ifndef _wsd_observer_h
#define _wsd_observer_h

#include "frame.h"

typedef void (*wsd_cb_on_frame)(void *receiver, wsd_Frame *frame);

typedef struct wsd_Observer {
    void *receiver;
    wsd_cb_on_frame on_frame;
} wsd_Observer;

wsd_Observer *  wsd_Observer_create(void *receiver, wsd_cb_on_frame on_frame);
void            wsd_Observer_destroy(wsd_Observer *observer);
void            wsd_Observer_on_frame(wsd_Observer *observer, wsd_Frame *frame);

#endif
