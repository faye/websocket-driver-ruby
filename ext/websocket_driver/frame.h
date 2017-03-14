#ifndef _wsd_frame_h
#define _wsd_frame_h

#include "chunk.h"
#include "util.h"

typedef struct wsd_Frame {
    int final;
    int rsv1;
    int rsv2;
    int rsv3;
    int opcode;
    int masked;
    wsd_Chunk *masking_key;
    int length_bytes;
    uint64_t length;
    wsd_Chunk *payload;
} wsd_Frame;

wsd_Frame * wsd_Frame_create();
void        wsd_Frame_destroy(wsd_Frame *frame);
void        wsd_Frame_mask(wsd_Frame *frame);
size_t      wsd_Frame_copy(wsd_Frame *frame, wsd_Chunk *target, size_t offset);

#endif
