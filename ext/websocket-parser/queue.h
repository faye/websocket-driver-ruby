#ifndef _wsd_queue_h
#define _wsd_queue_h

#include <stdint.h>
#include <stdlib.h>


typedef struct wsd_QueueNode wsd_QueueNode;

wsd_QueueNode * wsd_QueueNode_create(void *value);
void            wsd_QueueNode_destroy(wsd_QueueNode *node);


typedef struct wsd_Queue wsd_Queue;

typedef void (*wsd_Queue_cb)(void *value);

wsd_Queue * wsd_Queue_create();
void        wsd_Queue_destroy(wsd_Queue *queue);
void        wsd_Queue_each(wsd_Queue *queue, wsd_Queue_cb callback);
int         wsd_Queue_push(wsd_Queue *queue, void *value);
void *      wsd_Queue_peek(wsd_Queue *queue);
void *      wsd_Queue_shift(wsd_Queue *queue);

#endif
