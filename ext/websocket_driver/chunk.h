#ifndef _wsd_chunk_h
#define _wsd_chunk_h

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "util.h"

typedef struct wsd_Chunk wsd_Chunk;

typedef void *(*wsd_cb_to_string)(uint8_t *data, size_t length);

wsd_Chunk * wsd_Chunk_create(size_t length, uint8_t *data);
wsd_Chunk * wsd_Chunk_alloc(size_t length);
wsd_Chunk * wsd_Chunk_slice(wsd_Chunk *chunk, size_t n, size_t size);
wsd_Chunk * wsd_Chunk_make(size_t length, int is_slice);
void        wsd_Chunk_destroy(wsd_Chunk *chunk);
size_t      wsd_Chunk_length(wsd_Chunk *chunk);
void *      wsd_Chunk_to_string(wsd_Chunk *chunk, wsd_cb_to_string to_string);
size_t      wsd_Chunk_fill(wsd_Chunk *chunk, size_t n, uint8_t *src);
int         wsd_Chunk_bounds_check(wsd_Chunk *chunk, size_t start, size_t n);
size_t      wsd_Chunk_copy(wsd_Chunk *src, size_t src_start, wsd_Chunk *dst, size_t dst_start, size_t n);
uint8_t     wsd_Chunk_get(wsd_Chunk *chunk, size_t n);
int         wsd_Chunk_set(wsd_Chunk *chunk, size_t n, uint8_t value);
uint16_t    wsd_Chunk_read_uint16(wsd_Chunk *chunk, size_t n);
uint64_t    wsd_Chunk_read_uint64(wsd_Chunk *chunk, size_t n);
size_t      wsd_Chunk_write_uint16(wsd_Chunk *chunk, size_t n, uint16_t value);
size_t      wsd_Chunk_write_uint64(wsd_Chunk *chunk, size_t n, uint64_t value);
int         wsd_Chunk_has_space(wsd_Chunk *chunk, size_t n, size_t s);
size_t      wsd_Chunk_mask(wsd_Chunk *chunk, wsd_Chunk *mask);

#endif
