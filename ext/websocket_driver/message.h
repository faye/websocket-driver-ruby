#ifndef _wsd_message_h
#define _wsd_message_h

#include "frame.h"
#include "queue.h"

#define WSD_MAX_MESSAGE_LENGTH 0x3ffffff

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
int             wsd_Message_would_overflow(wsd_Message *message, wsd_Frame *frame);
int             wsd_Message_push_frame(wsd_Message *message, wsd_Frame *frame);
size_t          wsd_Message_copy(wsd_Message *message, wsd_Chunk *target);

#endif
