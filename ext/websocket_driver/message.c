#include "message.h"

wsd_Message *wsd_Message_create(wsd_Frame *frame)
{
    wsd_Message *message = calloc(1, sizeof(wsd_Message));
    if (message == NULL) return NULL;

    message->frames = wsd_Queue_create();
    if (message->frames == NULL) {
        free(message);
        return NULL;
    }

    message->length = 0;
    if (!wsd_Message_push_frame(message, frame)) {
        wsd_clear_pointer(wsd_Queue_destroy, message->frames);
        free(message);
        return NULL;
    }

    message->opcode = frame->opcode;
    message->rsv1   = frame->rsv1;
    message->rsv2   = frame->rsv2;
    message->rsv3   = frame->rsv3;

    return message;
}

void wsd_Message_destroy(wsd_Message *message)
{
    if (message == NULL) return;

    wsd_Queue_each(message->frames, (wsd_Queue_cb)wsd_Frame_destroy);

    wsd_clear_pointer(wsd_Queue_destroy, message->frames);

    free(message);
}

int wsd_Message_push_frame(wsd_Message *message, wsd_Frame *frame)
{
    if (!wsd_Queue_push(message->frames, frame)) return 0;

    message->length += frame->length;
    return 1;
}

uint64_t wsd_Message_copy(wsd_Message *message, uint8_t *target)
{
    uint64_t offset = 0;
    wsd_QueueIter *iter = wsd_QueueIter_create(message->frames);

    if (iter == NULL) return 0;

    for (; iter->value; wsd_QueueIter_next(iter)) {
        offset = wsd_Frame_copy(iter->value, target, offset);
    }

    wsd_QueueIter_destroy(iter);

    return offset;
}
