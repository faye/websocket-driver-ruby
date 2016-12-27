#ifndef _wsd_observer_h
#define _wsd_observer_h

#include "message.h"

typedef struct wsd_Observer wsd_Observer;

typedef void (*wsd_cb_on_frame)(void *receiver, wsd_Frame *frame);
typedef void (*wsd_cb_on_message)(void *receiver, wsd_Message *message);

wsd_Observer *  wsd_Observer_create(void *receiver,
                                    wsd_cb_on_message on_message,
                                    wsd_cb_on_frame on_frame);

void            wsd_Observer_destroy(wsd_Observer *observer);
void            wsd_Observer_on_message(wsd_Observer *observer, wsd_Message *message);
void            wsd_Observer_on_frame(wsd_Observer *observer, wsd_Frame *frame);

#endif
