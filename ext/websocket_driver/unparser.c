#include "unparser.h"

struct wsd_Unparser {
    int masking;
};

wsd_Unparser *wsd_Unparser_create(int masking)
{
    wsd_Unparser *unparser = calloc(1, sizeof(wsd_Unparser));
    if (unparser == NULL) return NULL;

    unparser->masking = masking;

    return unparser;
}

void wsd_Unparser_destroy(wsd_Unparser *unparser)
{
    if (unparser == NULL) return;

    free(unparser);
}

wsd_Chunk *wsd_Unparser_frame(wsd_Unparser *unparser, wsd_Frame *frame)
{
    size_t flen    = wsd_Chunk_length(frame->payload);
    size_t lenlen  = (flen <= 125) ? 0 : (flen <= 65535 ? 2 : 8);
    size_t masklen = unparser->masking ? 4 : 0;
    size_t buflen  = 2 + lenlen + masklen + flen;

    uint8_t mask = 0;

    wsd_Chunk *chunk = wsd_Chunk_alloc(buflen);
    if (chunk == NULL) return NULL;

    wsd_Chunk_set(chunk, 0, (frame->final ? WSD_FIN  : 0)
                          | (frame->rsv1  ? WSD_RSV1 : 0)
                          | (frame->rsv2  ? WSD_RSV2 : 0)
                          | (frame->rsv3  ? WSD_RSV3 : 0)
                          | frame->opcode);

    if (unparser->masking) {
        frame->masked = 1;
        wsd_Frame_mask(frame);
        mask = WSD_MASK;
    }

    if (lenlen == 0) {
        wsd_Chunk_set(chunk, 1, mask | flen);
    } else if (lenlen == 2) {
        wsd_Chunk_set(chunk, 1, mask | 126);
        wsd_Chunk_write_uint16(chunk, 2, flen);
    } else {
        wsd_Chunk_set(chunk, 1, mask | 127);
        wsd_Chunk_write_uint64(chunk, 2, flen);
    }

    wsd_Chunk_copy(frame->masking_key, 0, chunk, 2 + lenlen, masklen);
    wsd_Chunk_copy(frame->payload, 0, chunk, 2 + lenlen + masklen, flen);

    return chunk;
}
