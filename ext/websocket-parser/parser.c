#define _GNU_SOURCE

#include "parser.h"

struct wsd_Parser {
    int require_masking;

    wsd_ReadBuffer *buffer;
    wsd_Observer *observer;

    int stage;
    wsd_Frame *frame;
    wsd_Message *message;

    int error_code;
    char *error_message;
};

wsd_Parser *wsd_Parser_create(wsd_Observer *observer)
{
    wsd_Parser *parser = calloc(1, sizeof(wsd_Parser));
    if (parser == NULL) return NULL;

    parser->buffer = wsd_ReadBuffer_create();
    if (parser->buffer == NULL) {
        free(parser);
        return NULL;
    }

    parser->require_masking = 1;
    parser->observer = observer;

    parser->stage = 1;
    parser->frame = NULL;
    parser->message = NULL;

    parser->error_code = 0;
    parser->error_message = NULL;

    return parser;
}

void wsd_Parser_destroy(wsd_Parser *parser)
{
    if (parser == NULL) return;

    wsd_clear_pointer(wsd_ReadBuffer_destroy, parser->buffer);
    wsd_clear_pointer(wsd_Frame_destroy, parser->frame);
    wsd_clear_pointer(wsd_Message_destroy, parser->message);
    wsd_clear_pointer(wsd_Observer_destroy, parser->observer);
    wsd_clear_pointer(free, parser->error_message);

    free(parser);
}

int wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data)
{
    uint64_t pushed = 0;
    uint8_t *chunk = NULL;
    uint64_t n = 0;
    uint64_t readlen = 1;

    pushed = wsd_ReadBuffer_push(parser->buffer, length, data);
    if (pushed != length) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to push chunk[%" PRIu64 "] to read buffer", length);
    }

    chunk = calloc(8, sizeof(uint8_t));
    if (chunk == NULL) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate memory for frame header");
    }

    while (readlen > 0) {
        switch (parser->stage) {
            case 1:
                n = 2;
                readlen = wsd_ReadBuffer_read(parser->buffer, n, chunk);
                if (readlen == n) wsd_Parser_parse_head(parser, chunk);
                break;
            case 2:
                n = parser->frame->length_bytes;
                readlen = wsd_ReadBuffer_read(parser->buffer, n, chunk);
                if (readlen == n) wsd_Parser_parse_extended_length(parser, chunk);
                break;
            case 3:
                n = 4;
                readlen = wsd_ReadBuffer_read(parser->buffer, n, parser->frame->masking_key);
                if (readlen == n) parser->stage = 4;
                break;
            case 4:
                n = parser->frame->length;
                readlen = wsd_Parser_parse_payload(parser);
                if (readlen == n) wsd_Parser_emit_frame(parser);
                break;
            default:
                readlen = 0;
                break;
        }
    }

    free(chunk);
    return parser->error_code;
}

void wsd_Parser_parse_head(wsd_Parser *parser, uint8_t *chunk)
{
    wsd_Frame *frame = wsd_Frame_create();
    if (frame == NULL) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate frame");
        return;
    }

    frame->final  = (chunk[0] & WSD_FIN)  == WSD_FIN;
    frame->rsv1   = (chunk[0] & WSD_RSV1) == WSD_RSV1;
    frame->rsv2   = (chunk[0] & WSD_RSV2) == WSD_RSV2;
    frame->rsv3   = (chunk[0] & WSD_RSV3) == WSD_RSV3;
    frame->opcode = (chunk[0] & WSD_OPCODE);
    frame->masked = (chunk[1] & WSD_MASK) == WSD_MASK;
    frame->length = (chunk[1] & WSD_LENGTH);

    parser->frame = frame;

    // TODO check RSV bits by calling back the ruby driver (requires extensions)

    if (!wsd_Parser_valid_opcode(parser)) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Unrecognized frame opcode: %d", frame->opcode);
        return;
    }

    if (frame->length <= 125) {
        parser->stage = frame->masked ? 3 : 4;
    } else {
        parser->stage = 2;
        frame->length_bytes = (frame->length == 126) ? 2 : 8;
    }

    parser->frame = frame;
}

int wsd_Parser_valid_opcode(wsd_Parser *parser)
{
    int opcode = parser->frame->opcode;

    return opcode == WSD_OPCODE_CONTINUTATION ||
           opcode == WSD_OPCODE_TEXT ||
           opcode == WSD_OPCODE_BINARY ||
           opcode == WSD_OPCODE_CLOSE ||
           opcode == WSD_OPCODE_PING ||
           opcode == WSD_OPCODE_PONG;
}

void wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk)
{
    wsd_Frame *frame = parser->frame;

    if (frame->length == 126) {
        frame->length = (uint64_t)chunk[0] << 8 |
                        (uint64_t)chunk[1];

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

uint64_t wsd_Parser_parse_payload(wsd_Parser *parser)
{
    wsd_ReadBuffer *buffer = parser->buffer;
    wsd_Frame *frame = parser->frame;
    uint64_t n = frame->length;

    if (!wsd_ReadBuffer_has_capacity(buffer, n)) return 0;

    frame->payload = calloc(n, sizeof(uint8_t));
    if (frame->payload == NULL) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate frame payload[%" PRIu64 "]", n);
        return 0;
    }

    n = wsd_ReadBuffer_read(buffer, n, frame->payload);
    wsd_Frame_mask(frame);

    return n;
}

void wsd_Parser_emit_frame(wsd_Parser *parser)
{
    wsd_Frame *frame = parser->frame;

    parser->stage = 1;

    switch (frame->opcode) {
        case WSD_OPCODE_CONTINUTATION:
            if (parser->message == NULL) {
                wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Received unexpected continuation frame");
                return;
            }
            if (!wsd_Message_push_frame(parser->message, frame)) {
                wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to add frame to message");
                return;
            }
            break;

        case WSD_OPCODE_TEXT:
        case WSD_OPCODE_BINARY:
            parser->message = wsd_Message_create(frame);
            if (parser->message == NULL) {
                wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate message");
                return;
            }
            break;

        case WSD_OPCODE_CLOSE:
        case WSD_OPCODE_PING:
        case WSD_OPCODE_PONG:
            // TODO
            break;
    }

    if (frame->opcode <= WSD_OPCODE_BINARY) {
        parser->frame = NULL;
        if (frame->final) wsd_Parser_emit_message(parser);
    } else {
        wsd_clear_pointer(wsd_Frame_destroy, parser->frame);
    }
}

void wsd_Parser_emit_message(wsd_Parser *parser)
{
    wsd_Observer_on_message(parser->observer, parser->message);

    wsd_clear_pointer(wsd_Message_destroy, parser->message);
}
