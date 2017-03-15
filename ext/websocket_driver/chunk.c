#include "chunk.h"

struct wsd_Chunk {
    size_t length;
    int is_slice;
    uint8_t *data;
};

wsd_Chunk *wsd_Chunk_create(size_t length, uint8_t *data)
{
    wsd_Chunk *chunk = wsd_Chunk_alloc(length);
    if (chunk == NULL) return NULL;

    memcpy(chunk->data, data, length);

    return chunk;
}

wsd_Chunk *wsd_Chunk_alloc(size_t length)
{
    wsd_Chunk *chunk = wsd_Chunk_make(length, 0);
    if (chunk == NULL) return NULL;

    chunk->data = calloc(length, sizeof(uint8_t));
    if (chunk->data == NULL) {
        free(chunk);
        return NULL;
    }

    return chunk;
}

wsd_Chunk *wsd_Chunk_slice(wsd_Chunk *chunk, size_t n, size_t size)
{
    size_t max_size = 0;
    wsd_Chunk *slice = NULL;

    if (n > chunk->length) return NULL;

    max_size = chunk->length - n;
    if (size == 0) size = max_size;
    if (size > max_size) return NULL;

    slice = wsd_Chunk_make(size, 1);
    if (slice == NULL) return NULL;

    slice->length = size;
    slice->data = chunk->data + n;

    return slice;
}

wsd_Chunk *wsd_Chunk_make(size_t length, int is_slice)
{
    wsd_Chunk *chunk = calloc(1, sizeof(wsd_Chunk));
    if (chunk == NULL) return NULL;

    chunk->length = length;
    chunk->is_slice = is_slice;
    chunk->data = NULL;

    return chunk;
}

void wsd_Chunk_destroy(wsd_Chunk *chunk)
{
    if (chunk == NULL) return;

    if (!chunk->is_slice) free(chunk->data);
    chunk->data = NULL;

    chunk->length = 0;
    chunk->is_slice = 0;

    free(chunk);
}

size_t wsd_Chunk_length(wsd_Chunk *chunk)
{
    return chunk->length;
}

void *wsd_Chunk_to_string(wsd_Chunk *chunk, wsd_cb_to_string to_string)
{
    return to_string(chunk->data, chunk->length);
}

size_t wsd_Chunk_fill(wsd_Chunk *chunk, size_t n, uint8_t *src)
{
    if (n > chunk->length) return 0;

    memcpy(chunk->data, src, n);
    return n;
}

int wsd_Chunk_bounds_check(wsd_Chunk *chunk, size_t start, size_t n)
{
    if (chunk == NULL) return 0;

    size_t length = chunk->length;

    return start <= length && n <= length - start;
}

size_t wsd_Chunk_copy(wsd_Chunk *src, size_t src_start, wsd_Chunk *dst, size_t dst_start, size_t n)
{
    if (!wsd_Chunk_bounds_check(src, src_start, n)) return 0;
    if (!wsd_Chunk_bounds_check(dst, dst_start, n)) return 0;

    memcpy(dst->data + dst_start, src->data + src_start, n);

    return n;
}

uint8_t wsd_Chunk_get(wsd_Chunk *chunk, size_t n)
{
    if (n >= chunk->length) return 0;

    return chunk->data[n];
}

int wsd_Chunk_set(wsd_Chunk *chunk, size_t n, uint8_t value)
{
    if (n >= chunk->length) return 0;

    chunk->data[n] = value;
    return 1;
}

uint16_t wsd_Chunk_read_uint16(wsd_Chunk *chunk, size_t n)
{
    if (!wsd_Chunk_bounds_check(chunk, n, 2)) return 0;

    uint8_t *data = chunk->data;

    return (uint16_t)data[n    ] << 8
         | (uint16_t)data[n + 1];
}

uint64_t wsd_Chunk_read_uint64(wsd_Chunk *chunk, size_t n)
{
    if (!wsd_Chunk_bounds_check(chunk, n, 8)) return 0;

    uint8_t *data = chunk->data;

    return (uint64_t)data[n    ] << 56
         | (uint64_t)data[n + 1] << 48
         | (uint64_t)data[n + 2] << 40
         | (uint64_t)data[n + 3] << 32
         | (uint64_t)data[n + 4] << 24
         | (uint64_t)data[n + 5] << 16
         | (uint64_t)data[n + 6] <<  8
         | (uint64_t)data[n + 7];
}

size_t wsd_Chunk_write_uint16(wsd_Chunk *chunk, size_t n, uint16_t value)
{
    if (!wsd_Chunk_bounds_check(chunk, n, 2)) return 0;

    uint8_t *data = chunk->data;

    data[n    ] = value >> 8 & 0xff;
    data[n + 1] = value      & 0xff;

    return 2;
}

size_t wsd_Chunk_write_uint64(wsd_Chunk *chunk, size_t n, uint64_t value)
{
    if (!wsd_Chunk_bounds_check(chunk, n, 8)) return 0;

    uint8_t *data = chunk->data;

    data[n    ] = value >> 56 & 0xff;
    data[n + 1] = value >> 48 & 0xff;
    data[n + 2] = value >> 40 & 0xff;
    data[n + 3] = value >> 32 & 0xff;
    data[n + 4] = value >> 24 & 0xff;
    data[n + 5] = value >> 16 & 0xff;
    data[n + 6] = value >>  8 & 0xff;
    data[n + 7] = value       & 0xff;

    return 8;
}

size_t wsd_Chunk_mask(wsd_Chunk *chunk, wsd_Chunk *mask)
{
    size_t i = 0;
    uint8_t *data = chunk->data;
    uint8_t *masking_key = mask->data;

    for (i = 0; i < chunk->length; i++) {
        data[i] ^= masking_key[i % mask->length];
    }

    return chunk->length;
}
