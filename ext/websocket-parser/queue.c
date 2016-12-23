#include "queue.h"

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

    free(node);
}


wsd_Queue *wsd_Queue_create()
{
    wsd_Queue *queue = calloc(1, sizeof(wsd_Queue));
    if (queue == NULL) return NULL;

    queue->count = 0;
    queue->head  = NULL;
    queue->tail  = NULL;

    return queue;
}

void wsd_Queue_destroy(wsd_Queue *queue) {
    if (queue == NULL) return;

    wsd_Queue_each(queue, node) {
        wsd_QueueNode_destroy(node);
    }
    free(queue);
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

void *wsd_Queue_shift(wsd_Queue *queue)
{
    if (queue->count == 0) return NULL;

    wsd_QueueNode *head = queue->head;
    void *value = head->value;

    queue->head = head->next;
    if (queue->count == 1) queue->tail = NULL;

    wsd_QueueNode_destroy(head);
    queue->count--;
    return value;
}
