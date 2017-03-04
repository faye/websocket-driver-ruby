#ifndef _wsd_extensions_h
#define _wsd_extensions_h

#include "frame.h"

typedef struct wsd_Extensions wsd_Extensions;

typedef int (*wsd_cb_valid_frame_rsv)(void *receiver, wsd_Frame *frame);

wsd_Extensions *    wsd_Extensions_create(void *receiver, wsd_cb_valid_frame_rsv valid_frame_rsv);
wsd_Extensions *    wsd_Extensions_create_default();
void                wsd_Extensions_destroy(wsd_Extensions *extensions);
int                 wsd_Extensions_valid_frame_rsv(wsd_Extensions *extensions, wsd_Frame *frame);
int                 wsd_default_valid_frame_rsv(void *self, wsd_Frame *frame);

#endif
