#include "read_buffer.h"

struct wsd_ReadBuffer {
    wsd_Queue *queue;
    size_t capacity;
    size_t cursor;
};

wsd_ReadBuffer *wsd_ReadBuffer_create()
{
    wsd_ReadBuffer *buffer = calloc(1, sizeof(wsd_ReadBuffer));
    if (buffer == NULL) return NULL;

    buffer->queue = wsd_Queue_create();
    if (buffer->queue == NULL) {
        free(buffer);
        return NULL;
    }

    buffer->capacity = 0;
    buffer->cursor   = 0;

    return buffer;
}

void wsd_ReadBuffer_destroy(wsd_ReadBuffer *buffer)
{
    if (buffer == NULL) return;

    wsd_Queue_each(buffer->queue, (wsd_Queue_cb)wsd_Chunk_destroy);

    wsd_clear_pointer(wsd_Queue_destroy, buffer->queue);

    free(buffer);
}

int wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, wsd_Chunk *chunk)
{
    size_t length = wsd_Chunk_length(chunk);

    if (length > WSD_MAX_READBUFFER_CAPACITY - buffer->capacity) return 0;

    if (wsd_Queue_push(buffer->queue, chunk) != 1) return 0;

    buffer->capacity += length;
    return 1;
}

int wsd_ReadBuffer_has_capacity(wsd_ReadBuffer *buffer, size_t length)
{
    return buffer->capacity >= length;
}

size_t wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, size_t length, wsd_Chunk *target)
{
    size_t offset     = 0;
    size_t available  = 0;
    size_t required   = 0;
    size_t take_bytes = 0;

    if (buffer->capacity < length) return 0;

    while (offset < length) {
        wsd_Chunk *chunk = wsd_Queue_peek(buffer->queue);

        available  = wsd_Chunk_length(chunk) - buffer->cursor;
        required   = length - offset;
        take_bytes = (available < required) ? available : required;

        if (!wsd_Chunk_copy(chunk, buffer->cursor, target, offset, take_bytes)) {
            return offset;
        }

        offset += take_bytes;
        buffer->capacity -= take_bytes;

        if (take_bytes == available) {
            buffer->cursor = 0;
            wsd_Chunk_destroy(chunk);
            wsd_Queue_shift(buffer->queue);
        } else {
            buffer->cursor += take_bytes;
        }
    }

    return offset;
}
