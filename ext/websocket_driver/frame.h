#ifndef _wsd_frame_h
#define _wsd_frame_h

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "util.h"

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
uint64_t    wsd_Frame_copy(wsd_Frame *frame, uint8_t *target, uint64_t offset);

#endif
