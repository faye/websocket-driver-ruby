#include "queue.h"

struct wsd_QueueNode {
    void *value;
    wsd_QueueNode *next;
};

wsd_QueueNode *wsd_QueueNode_create(void *value)
{
    wsd_QueueNode *node = calloc(1, sizeof(wsd_QueueNode));
    if (!node) return NULL;

    node->value = value;
    node->next  = NULL;

    return node;
}

void wsd_QueueNode_destroy(wsd_QueueNode *node)
{
    if (node == NULL) return;

    node->value = NULL;
    node->next  = NULL;

    free(node);
}


struct wsd_Queue {
    uint32_t count;
    wsd_QueueNode *head;
    wsd_QueueNode *tail;
};

wsd_Queue *wsd_Queue_create()
{
    wsd_Queue *queue = calloc(1, sizeof(wsd_Queue));
    if (queue == NULL) return NULL;

    queue->count = 0;
    queue->head  = NULL;
    queue->tail  = NULL;

    return queue;
}

#define wsd_Queue_next(N) (N == NULL) ? NULL : N->next

void wsd_Queue_destroy(wsd_Queue *queue)
{
    wsd_QueueNode *node = NULL;
    wsd_QueueNode *next = NULL;

    if (queue == NULL) return;

    for (node = queue->head; node != NULL; node = next) {
        next = node->next;
        wsd_QueueNode_destroy(node);
    }

    queue->head = NULL;
    queue->tail = NULL;

    free(queue);
}

void wsd_Queue_each(wsd_Queue *queue, wsd_Queue_cb callback)
{
    wsd_QueueNode *node = NULL;

    for (node = queue->head; node != NULL; node = node->next) {
        callback(node->value);
    }
}

int wsd_Queue_push(wsd_Queue *queue, void *value)
{
    wsd_QueueNode *node = wsd_QueueNode_create(value);
    if (node == NULL) return 0;

    if (queue->count == 0) {
        queue->head = node;
        queue->tail = node;
    } else {
        queue->tail->next = node;
        queue->tail = node;
    }
    queue->count++;
    return 1;
}

void *wsd_Queue_peek(wsd_Queue *queue)
{
    if (queue->count == 0) {
        return NULL;
    } else {
        return queue->head->value;
    }
}

void *wsd_Queue_shift(wsd_Queue *queue)
{
    wsd_QueueNode *head = NULL;
    void *value = NULL;

    if (queue->count == 0) return NULL;

    head  = queue->head;
    value = head->value;

    queue->head = head->next;
    if (queue->count == 1) queue->tail = NULL;

    wsd_QueueNode_destroy(head);
    queue->count--;
    return value;
}


wsd_QueueIter *wsd_QueueIter_create(wsd_Queue *queue)
{
    wsd_QueueIter *iter = calloc(1, sizeof(wsd_QueueIter));
    if (iter == NULL) return NULL;

    if (queue->count > 0) {
        iter->node  = queue->head;
        iter->value = iter->node->value;
    } else {
        iter->node  = NULL;
        iter->value = NULL;
    }

    return iter;
}

void wsd_QueueIter_destroy(wsd_QueueIter *iter)
{
    if (iter == NULL) return;

    free(iter);
}

void wsd_QueueIter_next(wsd_QueueIter *iter)
{
    iter->node  = iter->node->next;
    iter->value = iter->node ? iter->node->value : NULL;
}
