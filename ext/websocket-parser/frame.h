#ifndef _wsd_frame_h
#define _wsd_frame_h

#include <stdint.h>
#include <stdlib.h>

typedef struct wsd_Frame {
    int final;
    int rsv1;
    int rsv2;
    int rsv3;
    int opcode;
    int masked;
    uint8_t masking_key[4];
    int length_bytes;
    uint64_t length;
    uint8_t *payload;
} wsd_Frame;

wsd_Frame * wsd_Frame_create();
void        wsd_Frame_destroy(wsd_Frame *frame);
void        wsd_Frame_mask(wsd_Frame *frame);


typedef struct wsd_Message {

} wsd_Message;

wsd_Message *   wsd_Message_create();
void            wsd_Message_destroy(wsd_Message *message);

#endif
