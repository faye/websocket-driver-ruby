#include "read_buffer.h"


struct wsd_Chunk {
    uint64_t length;
    uint8_t *data;
};

wsd_Chunk *wsd_Chunk_create(uint64_t length, uint8_t *data)
{
    wsd_Chunk *chunk = calloc(1, sizeof(wsd_Chunk));
    if (chunk == NULL) return NULL;

    chunk->data = calloc(length, sizeof(uint8_t));
    if (chunk->data == NULL) {
        free(chunk);
        return NULL;
    }

    chunk->length = length;
    memcpy(chunk->data, data, length);

    return chunk;
}

void wsd_Chunk_destroy(wsd_Chunk *chunk)
{
    if (chunk == NULL) return;

    wsd_clear_pointer(free, chunk->data);

    free(chunk);
}


struct wsd_ReadBuffer {
    wsd_Queue *queue;
    uint64_t capacity;
    uint64_t cursor;
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

    { wsd_Queue_each(buffer->queue, node) {
        wsd_Chunk_destroy(node->value);
    } }

    wsd_clear_pointer(wsd_Queue_destroy, buffer->queue);

    free(buffer);
}

uint64_t wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *data)
{
    wsd_Chunk *chunk = wsd_Chunk_create(length, data);
    if (chunk == NULL) return 0;

    if (wsd_Queue_push(buffer->queue, chunk) != 1) {
        wsd_Chunk_destroy(chunk);
        return 0;
    }

    buffer->capacity += length;
    return length;
}

int wsd_ReadBuffer_has_capacity(wsd_ReadBuffer *buffer, uint64_t length)
{
    return buffer->capacity >= length;
}

uint64_t wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *target)
{
    uint64_t offset = 0;

    if (buffer->capacity < length) return 0;

    while (offset < length) {
        wsd_Chunk *chunk = wsd_Queue_peek(buffer->queue);

        uint64_t available  = chunk->length - buffer->cursor;
        uint64_t required   = length - offset;
        uint64_t take_bytes = (available < required) ? available : required;

        memcpy(target + offset, chunk->data + buffer->cursor, take_bytes);
        offset += take_bytes;

        if (take_bytes == available) {
            buffer->cursor = 0;
            wsd_Chunk_destroy(chunk);
            wsd_Queue_shift(buffer->queue);
        } else {
            buffer->cursor += take_bytes;
        }
    }

    buffer->capacity -= length;
    return length;
}
