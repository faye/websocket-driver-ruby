#ifndef _wsd_read_buffer_h
#define _wsd_read_buffer_h

#include <string.h>
#include "queue.h"

typedef struct wsd_Chunk {
    uint64_t length;
    uint8_t *data;
} wsd_Chunk;

wsd_Chunk * wsd_Chunk_create(uint64_t length, uint8_t *data);
void        wsd_Chunk_destroy(wsd_Chunk *chunk);


typedef struct wsd_ReadBuffer {
    wsd_Queue *queue;
    uint64_t capacity;
    uint64_t cursor;
} wsd_ReadBuffer;

wsd_ReadBuffer *    wsd_ReadBuffer_create();
void                wsd_ReadBuffer_destroy(wsd_ReadBuffer *buffer);
uint64_t            wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *data);
uint64_t            wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *target);

#endif
