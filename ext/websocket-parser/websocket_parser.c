#include <ruby.h>

/*-------------------------------------------------------------------*/
/* Queue */

typedef struct wsd_QueueNode {
    void *value;
    struct wsd_QueueNode *next;
} wsd_QueueNode;

wsd_QueueNode *wsd_QueueNode_create(void *value);
void wsd_QueueNode_destroy(wsd_QueueNode *node);

wsd_QueueNode *wsd_QueueNode_create(void *value)
{
    wsd_QueueNode *node = calloc(1, sizeof(wsd_QueueNode));
    node->value = value;
    return node;
}

void wsd_QueueNode_destroy(wsd_QueueNode *node)
{
    if (node == NULL) return;

    free(node);
}


typedef struct wsd_Queue {
    uint32_t count;
    wsd_QueueNode *head;
    wsd_QueueNode *tail;
} wsd_Queue;

wsd_Queue *wsd_Queue_create();
void wsd_Queue_destroy(wsd_Queue *queue);
int wsd_Queue_push(wsd_Queue *queue, void *value);
void *wsd_Queue_shift(wsd_Queue *queue);

#define wsd_QueueNode_next(N) (N == NULL) ? NULL : N->next

#define wsd_Queue_each(Q, N) \
    wsd_QueueNode *_node = NULL; \
    wsd_QueueNode *_next = NULL; \
    wsd_QueueNode *N = NULL; \
    for (N = _node = Q->head, _next = wsd_QueueNode_next(_node); \
         _node != NULL; \
         N = _node = _next, _next = wsd_QueueNode_next(_node))

wsd_Queue *wsd_Queue_create()
{
    wsd_Queue *queue = calloc(1, sizeof(wsd_Queue));
    queue->count = 0;
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
    if (queue->count == 0) queue->tail = NULL;

    wsd_QueueNode_destroy(head);
    queue->count--;
    return value;
}

/*-------------------------------------------------------------------*/
/* ReadBuffer */

typedef struct wsd_Chunk {
    uint64_t length;
    uint8_t *data;
} wsd_Chunk;

wsd_Chunk *wsd_Chunk_create(uint64_t length, uint8_t *data);
void wsd_Chunk_destroy(wsd_Chunk *chunk);

wsd_Chunk *wsd_Chunk_create(uint64_t length, uint8_t *data)
{
    wsd_Chunk *chunk = calloc(1, sizeof(wsd_Chunk));
    if (chunk == NULL) return NULL;

    chunk->length = length;
    chunk->data = calloc(length, sizeof(char));

    if (chunk->data == NULL) {
        free(chunk);
        return NULL;
    }

    memcpy(chunk->data, data, length);

    return chunk;
}

void wsd_Chunk_destroy(wsd_Chunk *chunk)
{
    if (chunk == NULL) return;

    free(chunk->data);
    free(chunk);
}


typedef struct wsd_ReadBuffer {
    wsd_Queue *queue;
    uint64_t capacity;
    uint64_t cursor;
} wsd_ReadBuffer;

wsd_ReadBuffer *wsd_ReadBuffer_create();
void wsd_ReadBuffer_destroy(wsd_ReadBuffer *buffer);
uint64_t wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *data);
uint64_t wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *target);

wsd_ReadBuffer *wsd_ReadBuffer_create()
{
    wsd_ReadBuffer *buffer = calloc(1, sizeof(wsd_ReadBuffer));
    if (buffer == NULL) return NULL;

    buffer->queue = wsd_Queue_create();
    if (buffer->queue == NULL) {
        free(buffer);
        return NULL;
    }

    buffer->capacity = 0;
    buffer->cursor = 0;

    return buffer;
}

void wsd_ReadBuffer_destroy(wsd_ReadBuffer *buffer)
{
    if (buffer == NULL) return;

    wsd_Queue_each(buffer->queue, node) {
        wsd_Chunk_destroy(node->value);
    }
    wsd_Queue_destroy(buffer->queue);
    free(buffer);
}

uint64_t wsd_ReadBuffer_push(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *data)
{
    wsd_Chunk *chunk = wsd_Chunk_create(length, data);
    if (chunk == NULL) return 0;

    wsd_Queue_push(buffer->queue, chunk);

    buffer->capacity += length;
    return length;
}

uint64_t wsd_ReadBuffer_read(wsd_ReadBuffer *buffer, uint64_t length, uint8_t *target)
{
    if (buffer->capacity < length) return 0;

    uint64_t offset = 0;

    while (offset < length) {
        wsd_Chunk *chunk = buffer->queue->head->value;

        uint64_t available  = chunk->length - buffer->cursor;
        uint64_t required   = length - offset;
        uint64_t take_bytes = (available < required) ? available : required;

        memcpy(target + offset, chunk->data + buffer->cursor, take_bytes);
        offset += take_bytes;

        if (take_bytes == available) {
            buffer->cursor = 0;
            wsd_Chunk_destroy(chunk);
            wsd_Queue_shift(buffer->queue);
        } else {
            buffer->cursor += take_bytes;
        }
    }

    buffer->capacity -= length;
    return length;
}

/*-------------------------------------------------------------------*/
/* Frame and Message */

typedef struct wsd_Frame {
    int final;
    int rsv1;
    int rsv2;
    int rsv3;
    int opcode;
    int masked;
    uint8_t masking_key[4];
    int length_bytes;
    uint64_t length;
    uint8_t *payload;
} wsd_Frame;

wsd_Frame *wsd_Frame_create();
void wsd_Frame_destroy(wsd_Frame *frame);
void wsd_Frame_mask(wsd_Frame *frame);

wsd_Frame *wsd_Frame_create()
{
    wsd_Frame *frame = calloc(1, sizeof(wsd_Frame));
    return frame;
}

void wsd_Frame_destroy(wsd_Frame *frame)
{
    if (frame == NULL) return;

    if (frame->payload != NULL) free(frame->payload);
    free(frame);
}

void wsd_Frame_mask(wsd_Frame *frame)
{
    if (!frame->masked) return;

    uint64_t i = 0;

    for (i = 0; i < frame->length; i++) {
        frame->payload[i] ^= frame->masking_key[i % 4];
    }
}


typedef struct wsd_Message {

} wsd_Message;

wsd_Message *wsd_Message_create();
void wsd_Message_destroy(wsd_Message *frame);

/*-------------------------------------------------------------------*/
/* Parser */

#define WSD_FIN    0x80
#define WSD_RSV1   0x40
#define WSD_RSV2   0x20
#define WSD_RSV3   0x10
#define WSD_OPCODE 0x0f
#define WSD_MASK   0x80
#define WSD_LENGTH 0x7f

typedef struct wsd_Parser {
    int stage;
    int masking;
    int require_masking;
    wsd_ReadBuffer *buffer;
    wsd_Frame *frame;
    wsd_Message *message;
} wsd_Parser;

wsd_Parser *wsd_Parser_create();
void wsd_Parser_destroy(wsd_Parser *parser);
int wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data);
void wsd_Parser_parse_head(wsd_Parser *parser, uint8_t *chunk);
void wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk);
void wsd_Parser_emit_frame(wsd_Parser *parser);

wsd_Parser *wsd_Parser_create()
{
    wsd_Parser *parser = calloc(1, sizeof(wsd_Parser));
    if (parser == NULL) return NULL;

    parser->buffer = wsd_ReadBuffer_create();
    if (parser->buffer == NULL) {
        free(parser);
        return NULL;
    }

    parser->stage = 1;
    parser->masking = 1;
    parser->require_masking = 1;

    return parser;
}

void wsd_Parser_destroy(wsd_Parser *parser)
{
    if (parser == NULL) return;

    wsd_ReadBuffer_destroy(parser->buffer);
    wsd_Frame_destroy(parser->frame);
    // wsd_Message_destroy(parser->message);
    free(parser);
}

int wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data)
{
    wsd_ReadBuffer_push(parser->buffer, length, data);
    uint8_t *chunk = calloc(8, sizeof(char));
    uint64_t rc = 1;

    while (rc) {
        switch (parser->stage) {
            case 1:
                rc = wsd_ReadBuffer_read(parser->buffer, 2, chunk);
                if (rc) wsd_Parser_parse_head(parser, chunk);
                break;

            case 2:
                rc = wsd_ReadBuffer_read(parser->buffer, parser->frame->length_bytes, chunk);
                if (rc) wsd_Parser_parse_extended_length(parser, chunk);
                break;

            case 3:
                rc = wsd_ReadBuffer_read(parser->buffer, 4, parser->frame->masking_key);
                if (rc) parser->stage = 4;
                break;

            case 4:
                parser->frame->payload = calloc(parser->frame->length, sizeof(char));
                rc = wsd_ReadBuffer_read(parser->buffer, parser->frame->length, parser->frame->payload);
                if (rc) wsd_Parser_emit_frame(parser);
                break;

            default:
                rc = 0;
                break;
        }
    }

    free(chunk);
    return 0;
}

void wsd_Parser_parse_head(wsd_Parser *parser, uint8_t *chunk)
{
    wsd_Frame *frame = wsd_Frame_create();

    frame->final  = (chunk[0] & WSD_FIN)  == WSD_FIN;
    frame->rsv1   = (chunk[0] & WSD_RSV1) == WSD_RSV1;
    frame->rsv2   = (chunk[0] & WSD_RSV2) == WSD_RSV2;
    frame->rsv3   = (chunk[0] & WSD_RSV3) == WSD_RSV3;
    frame->opcode = (chunk[0] & WSD_OPCODE);
    frame->masked = (chunk[1] & WSD_MASK) == WSD_MASK;
    frame->length = (chunk[1] & WSD_LENGTH);

    if (frame->length <= 125) {
        parser->stage = frame->masked ? 3 : 4;
    } else {
        parser->stage = 2;
        frame->length_bytes = (frame->length == 126) ? 2 : 8;
    }

    parser->frame = frame;
}

void wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk)
{
    wsd_Frame *frame = parser->frame;

    if (frame->length == 126) {
        frame->length = (uint64_t)chunk[0] << 8 | (uint64_t)chunk[1];
    } else if (frame->length == 127) {
        frame->length = (uint64_t)chunk[0] << 56 |
                        (uint64_t)chunk[1] << 48 |
                        (uint64_t)chunk[2] << 40 |
                        (uint64_t)chunk[3] << 32 |
                        (uint64_t)chunk[4] << 24 |
                        (uint64_t)chunk[5] << 16 |
                        (uint64_t)chunk[6] <<  8 |
                        (uint64_t)chunk[7];
    }

    parser->stage = frame->masked ? 3 : 4;
}

void wsd_Parser_emit_frame(wsd_Parser *parser)
{
    parser->stage = 1;
    wsd_Frame *frame = parser->frame;

    wsd_Frame_mask(frame);

    printf("------------------------------------------------------------------------\n");
    printf("[FRAME] final: %d, opcode: %d, masked: %d, length: %llu\n", frame->final, frame->opcode, frame->masked, frame->length);

    char *message = calloc(frame->length + 1, sizeof(char));
    memcpy(message, frame->payload, frame->length);
    printf("[PAYLOAD] %s\n\n", message);
    free(message);
}

/*-------------------------------------------------------------------*/
/* Ruby bindings */

void Init_websocket_parser();
VALUE wsd_WebSocketParser_initialize(VALUE self);
VALUE wsd_WebSocketParser_parse(VALUE self, VALUE chunk);

static VALUE wsd_RWebSocketParser = Qnil;

void Init_websocket_parser()
{
    wsd_RWebSocketParser = rb_define_class("WebSocketParser", rb_cObject);
    rb_define_method(wsd_RWebSocketParser, "initialize", wsd_WebSocketParser_initialize, 0);
    rb_define_method(wsd_RWebSocketParser, "parse", wsd_WebSocketParser_parse, 1);
}

VALUE wsd_WebSocketParser_initialize(VALUE self)
{
    wsd_Parser *parser = wsd_Parser_create();
    VALUE ruby_parser = Data_Wrap_Struct(rb_cObject, NULL, wsd_Parser_destroy, parser);
    rb_iv_set(self, "@parser", ruby_parser);
    return Qnil;
}

VALUE wsd_WebSocketParser_parse(VALUE self, VALUE chunk)
{
    uint64_t length = RSTRING_LEN(chunk);
    char *data = RSTRING_PTR(chunk);

    wsd_Parser *parser;
    Data_Get_Struct(rb_iv_get(self, "@parser"), wsd_Parser, parser);

    wsd_Parser_parse(parser, length, (uint8_t *)data);

    return Qnil;
}
