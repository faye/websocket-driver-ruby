#include "frame.h"

wsd_Frame *wsd_Frame_create()
{
    wsd_Frame *frame = calloc(1, sizeof(wsd_Frame));
    if (frame == NULL) return NULL;

    frame->masking_key = wsd_Chunk_alloc(4);
    if (frame->masking_key == NULL) {
        free(frame);
        return NULL;
    }

    frame->payload = NULL;

    return frame;
}

void wsd_Frame_destroy(wsd_Frame *frame)
{
    if (frame == NULL) return;

    WSD_CLEAR_POINTER(wsd_Chunk_destroy, frame->masking_key);
    WSD_CLEAR_POINTER(wsd_Chunk_destroy, frame->payload);

    free(frame);
}

void wsd_Frame_mask(wsd_Frame *frame)
{
    if (!frame->masked) return;

    wsd_Chunk_mask(frame->payload, frame->masking_key);
}

size_t wsd_Frame_copy(wsd_Frame *frame, wsd_Chunk *target, size_t offset)
{
    size_t n = (size_t)frame->length;
    wsd_Chunk_copy(frame->payload, 0, target, offset, n);
    return offset + n;
}
