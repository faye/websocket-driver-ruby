#ifndef _wsd_queue_h
#define _wsd_queue_h

#include <stdlib.h>

/*-------------------------------------------------------------------*/
/* Queue */

typedef struct wsd_QueueNode {
    void *value;
    struct wsd_QueueNode *next;
} wsd_QueueNode;

wsd_QueueNode * wsd_QueueNode_create(void *value);
void            wsd_QueueNode_destroy(wsd_QueueNode *node);

typedef struct wsd_Queue {
    uint32_t count;
    wsd_QueueNode *head;
    wsd_QueueNode *tail;
} wsd_Queue;

wsd_Queue * wsd_Queue_create();
void        wsd_Queue_destroy(wsd_Queue *queue);
int         wsd_Queue_push(wsd_Queue *queue, void *value);
void *      wsd_Queue_shift(wsd_Queue *queue);

#define wsd_QueueNode_next(N) (N == NULL) ? NULL : N->next

#define wsd_Queue_each(Q, N) \
    wsd_QueueNode *_node = NULL; \
    wsd_QueueNode *_next = NULL; \
    wsd_QueueNode *N = NULL; \
    for (N = _node = Q->head, _next = wsd_QueueNode_next(_node); \
         _node != NULL; \
         N = _node = _next, _next = wsd_QueueNode_next(_node))

#endif
