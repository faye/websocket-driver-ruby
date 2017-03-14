#include "stream_reader.h"

struct wsd_StreamReader {
    wsd_Queue *queue;
    size_t capacity;
    size_t cursor;
};

wsd_StreamReader *wsd_StreamReader_create()
{
    wsd_StreamReader *reader = calloc(1, sizeof(wsd_StreamReader));
    if (reader == NULL) return NULL;

    reader->queue = wsd_Queue_create();
    if (reader->queue == NULL) {
        free(reader);
        return NULL;
    }

    reader->capacity = 0;
    reader->cursor   = 0;

    return reader;
}

void wsd_StreamReader_destroy(wsd_StreamReader *reader)
{
    if (reader == NULL) return;

    wsd_Queue_each(reader->queue, (wsd_Queue_cb)wsd_Chunk_destroy);

    wsd_clear_pointer(wsd_Queue_destroy, reader->queue);

    free(reader);
}

int wsd_StreamReader_push(wsd_StreamReader *reader, wsd_Chunk *chunk)
{
    size_t length = wsd_Chunk_length(chunk);

    if (length > WSD_MAX_READBUFFER_CAPACITY - reader->capacity) return 0;

    if (wsd_Queue_push(reader->queue, chunk) != 1) return 0;

    reader->capacity += length;
    return 1;
}

int wsd_StreamReader_has_capacity(wsd_StreamReader *reader, size_t length)
{
    return reader->capacity >= length;
}

size_t wsd_StreamReader_read(wsd_StreamReader *reader, size_t length, wsd_Chunk *target)
{
    size_t offset     = 0;
    size_t available  = 0;
    size_t required   = 0;
    size_t take_bytes = 0;

    if (reader->capacity < length) return 0;

    while (offset < length) {
        wsd_Chunk *chunk = wsd_Queue_peek(reader->queue);

        available  = wsd_Chunk_length(chunk) - reader->cursor;
        required   = length - offset;
        take_bytes = (available < required) ? available : required;

        if (!wsd_Chunk_copy(chunk, reader->cursor, target, offset, take_bytes)) {
            return offset;
        }

        offset += take_bytes;
        reader->capacity -= take_bytes;

        if (take_bytes == available) {
            reader->cursor = 0;
            wsd_Chunk_destroy(chunk);
            wsd_Queue_shift(reader->queue);
        } else {
            reader->cursor += take_bytes;
        }
    }

    return offset;
}
