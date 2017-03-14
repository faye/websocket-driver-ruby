#ifndef _wsd_stream_reader_h
#define _wsd_stream_reader_h

#include "chunk.h"
#include "queue.h"
#include "util.h"

#define WSD_MAX_READBUFFER_CAPACITY 0xfffffff

typedef struct wsd_StreamReader wsd_StreamReader;

wsd_StreamReader *    wsd_StreamReader_create();
void                wsd_StreamReader_destroy(wsd_StreamReader *reader);
int                 wsd_StreamReader_push(wsd_StreamReader *reader, wsd_Chunk *chunk);
int                 wsd_StreamReader_has_capacity(wsd_StreamReader *reader, size_t length);
size_t              wsd_StreamReader_read(wsd_StreamReader *reader, size_t length, wsd_Chunk *target);

#endif
