#include "frame.h"

wsd_Frame *wsd_Frame_create()
{
    wsd_Frame *frame = calloc(1, sizeof(wsd_Frame));
    if (frame == NULL) return NULL;

    frame->payload = NULL;

    return frame;
}

void wsd_Frame_destroy(wsd_Frame *frame)
{
    if (frame == NULL) return;

    if (frame->payload != NULL) free(frame->payload);
    free(frame);
}

void wsd_Frame_mask(wsd_Frame *frame)
{
    if (!frame->masked) return;

    uint64_t i = 0;

    for (i = 0; i < frame->length; i++) {
        frame->payload[i] ^= frame->masking_key[i % 4];
    }
}


void wsd_Message_destroy(wsd_Message *message)
{
    // TODO
}
