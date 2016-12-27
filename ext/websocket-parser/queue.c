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

    for (node = queue->head, next = wsd_Queue_next(node);
         node != NULL;
         node = node->next, next = wsd_Queue_next(node)) {
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

void wsd_Queue_scan(wsd_Queue *queue, uint64_t *offset, uint8_t *target, wsd_Queue_scan_cb callback)
{
    wsd_QueueNode *node = NULL;

    for (node = queue->head; node != NULL; node = node->next) {
        callback(node->value, offset, target);
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
