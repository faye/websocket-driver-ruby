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

uint64_t wsd_Unparser_frame(wsd_Unparser *unparser, wsd_Frame *frame, uint8_t **out)
{
    uint64_t flen    = frame->length;
    uint64_t lenlen  = (flen <= 125) ? 0 : (flen <= 65535 ? 2 : 8);
    uint64_t masklen = unparser->masking ? 4 : 0;
    uint64_t buflen  = 2 + lenlen + masklen + flen;

    uint8_t *buf = NULL;
    uint8_t mask = 0;

    buf = calloc(buflen, sizeof(uint8_t));
    if (buf == NULL) return 0;

    buf[0] = (frame->final ? WSD_FIN : 0)
           | (frame->rsv1 ? WSD_RSV1 : 0)
           | (frame->rsv2 ? WSD_RSV2 : 0)
           | (frame->rsv3 ? WSD_RSV3 : 0)
           | frame->opcode;

    if (unparser->masking) {
        frame->masked = 1;
        wsd_Frame_mask(frame);
        mask = WSD_MASK;
    }

    if (lenlen == 0) {
        buf[1] = mask | flen;

    } else if (lenlen == 2) {
        buf[1] = mask | 126;
        buf[2] = flen >> 8 & 0xff;
        buf[3] = flen      & 0xff;

    } else {
        buf[1] = mask | 127;
        buf[2] = flen >> 56 & 0xff;
        buf[3] = flen >> 48 & 0xff;
        buf[4] = flen >> 40 & 0xff;
        buf[5] = flen >> 32 & 0xff;
        buf[6] = flen >> 24 & 0xff;
        buf[7] = flen >> 16 & 0xff;
        buf[8] = flen >>  8 & 0xff;
        buf[9] = flen       & 0xff;
    }

    memcpy(buf + 2 + lenlen, frame->masking_key, masklen);
    memcpy(buf + 2 + lenlen + masklen, frame->payload, flen);

    *out = buf;
    return buflen;
}
