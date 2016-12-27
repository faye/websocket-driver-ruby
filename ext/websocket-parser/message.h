#ifndef _wsd_message_h
#define _wsd_message_h

#include "frame.h"
#include "queue.h"

typedef struct wsd_Message {
    int opcode;
    int rsv1;
    int rsv2;
    int rsv3;
    uint64_t length;
    wsd_Queue *frames;
} wsd_Message;

wsd_Message *   wsd_Message_create(wsd_Frame *frame);
void            wsd_Message_destroy(wsd_Message *message);
int             wsd_Message_push_frame(wsd_Message *message, wsd_Frame *frame);
uint64_t        wsd_Message_copy(wsd_Message *message, uint8_t *target);

#endif
