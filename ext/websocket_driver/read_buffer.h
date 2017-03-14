#ifndef _wsd_read_buffer_h
#define _wsd_read_buffer_h

#include "chunk.h"
#include "queue.h"
#include "util.h"

#define WSD_MAX_READBUFFER_CAPACITY 0xfffffff

typedef struct wsd_ReadBuffer wsd_ReadBuffer;

wsd_ReadBuffer *    wsd_ReadBuffer_create();
void                wsd_ReadBuffer_destroy(wsd_ReadBuffer *buffer);
int                 wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, wsd_Chunk *chunk);
int                 wsd_ReadBuffer_has_capacity(wsd_ReadBuffer *buffer, size_t length);
size_t              wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, size_t length, wsd_Chunk *target);

#endif
