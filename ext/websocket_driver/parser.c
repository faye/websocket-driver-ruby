#define _GNU_SOURCE

#include "parser.h"

struct wsd_Parser {
    int require_masking;

    wsd_ReadBuffer *buffer;
    wsd_Extensions *extensions;
    wsd_Observer *observer;

    int stage;
    wsd_Frame *frame;
    wsd_Message *message;

    int error_code;
    char *error_reason;
};

wsd_Parser *wsd_Parser_create(wsd_Extensions *extensions, wsd_Observer *observer, int require_masking)
{
    wsd_Parser *parser = calloc(1, sizeof(wsd_Parser));
    if (parser == NULL) return NULL;

    parser->buffer = wsd_ReadBuffer_create();
    if (parser->buffer == NULL) {
        free(parser);
        return NULL;
    }

    parser->require_masking = require_masking;
    parser->extensions = extensions;
    parser->observer = observer;

    parser->stage = 1;
    parser->frame = NULL;
    parser->message = NULL;

    parser->error_code = 0;
    parser->error_reason = NULL;

    return parser;
}

void wsd_Parser_destroy(wsd_Parser *parser)
{
    if (parser == NULL) return;

    wsd_clear_pointer(wsd_ReadBuffer_destroy, parser->buffer);
    wsd_clear_pointer(wsd_Frame_destroy, parser->frame);
    wsd_clear_pointer(wsd_Message_destroy, parser->message);
    wsd_clear_pointer(wsd_Extensions_destroy, parser->extensions);
    wsd_clear_pointer(wsd_Observer_destroy, parser->observer);
    wsd_clear_pointer(free, parser->error_reason);

    free(parser);
}

int wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data)
{
    uint64_t pushed = 0;
    uint8_t *chunk = NULL;
    uint64_t n = 0;
    uint64_t readlen = 0;

    pushed = wsd_ReadBuffer_push(parser->buffer, length, data);
    if (pushed != length) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to push chunk[%" PRIu64 "] to read buffer", length);
    }

    chunk = calloc(8, sizeof(uint8_t));
    if (chunk == NULL) {
        wsd_Parser_error(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate memory for frame header");
    }

    while (readlen == n) {
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
                n = 1;
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

    if (!wsd_Extensions_valid_frame_rsv(parser->extensions, frame)) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR,
                "One or more reserved bits are on: reserved1 = %d, reserved2 = %d, reserved3 = %d",
                frame->rsv1, frame->rsv2, frame->rsv3);
        return;
    }

    if (!wsd_Parser_valid_opcode(frame->opcode)) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Unrecognized frame opcode: %d", frame->opcode);
        return;
    }

    if (wsd_Parser_control_opcode(frame->opcode) && !frame->final) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Received fragmented control frame: opcode = %d", frame->opcode);
        return;
    }

    if (parser->message == NULL && frame->opcode == WSD_OPCODE_CONTINUTATION) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Received unexpected continuation frame");
        return;
    }

    if (parser->message != NULL && wsd_Parser_opening_opcode(frame->opcode)) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Received new data frame but previous continuous frame is unfinished");
        return;
    }

    if (parser->require_masking && !frame->masked) {
        wsd_Parser_error(parser, WSD_UNACCEPTABLE, "Received unmasked frame but masking is required");
        return;
    }

    if (frame->length <= 125) {
        if (!wsd_Parser_check_length(parser)) return;
        parser->stage = frame->masked ? 3 : 4;
    } else {
        parser->stage = 2;
        frame->length_bytes = (frame->length == 126) ? 2 : 8;
    }
}

int wsd_Parser_valid_opcode(int opcode)
{
    return wsd_Parser_control_opcode(opcode) ||
           wsd_Parser_message_opcode(opcode);
}

int wsd_Parser_control_opcode(int opcode)
{
    return opcode == WSD_OPCODE_CLOSE ||
           opcode == WSD_OPCODE_PING ||
           opcode == WSD_OPCODE_PONG;
}

int wsd_Parser_message_opcode(int opcode)
{
    return wsd_Parser_opening_opcode(opcode) ||
           opcode == WSD_OPCODE_CONTINUTATION;
}

int wsd_Parser_opening_opcode(int opcode)
{
    return opcode == WSD_OPCODE_TEXT ||
           opcode == WSD_OPCODE_BINARY;
}

void wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk)
{
    wsd_Frame *frame = parser->frame;

    if (frame->length == 126) {
        frame->length = (uint64_t)chunk[0] << 8
                      | (uint64_t)chunk[1];

    } else if (frame->length == 127) {
        frame->length = (uint64_t)chunk[0] << 56
                      | (uint64_t)chunk[1] << 48
                      | (uint64_t)chunk[2] << 40
                      | (uint64_t)chunk[3] << 32
                      | (uint64_t)chunk[4] << 24
                      | (uint64_t)chunk[5] << 16
                      | (uint64_t)chunk[6] <<  8
                      | (uint64_t)chunk[7];
    }

    if (wsd_Parser_control_opcode(frame->opcode) && frame->length > 125) {
        wsd_Parser_error(parser, WSD_PROTOCOL_ERROR, "Received control frame having too long payload: %" PRIu64, frame->length);
        return;
    }

    if (!wsd_Parser_check_length(parser)) return;

    parser->stage = frame->masked ? 3 : 4;
}

int wsd_Parser_check_length(wsd_Parser *parser)
{
    uint64_t length = parser->message ? parser->message->length : 0;

    if (length + parser->frame->length > WSD_MAX_MESSAGE_LENGTH) {
        wsd_Parser_error(parser, WSD_TOO_LARGE, "WebSocket frame length too large");
        return 0;
    } else {
        return 1;
    }
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

    int code        = 0;
    uint64_t length = 0;
    uint8_t *reason = NULL;

    parser->stage = 1;

    switch (frame->opcode) {
        case WSD_OPCODE_CONTINUTATION:
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
            if (frame->length == 0) {
                code   = WSD_DEFAULT_ERROR_CODE;
                length = 0;
                reason = NULL;
            } else if (frame->length >= 2) {
                code   = frame->payload[0] << 8 | frame->payload[1];
                length = frame->length - 2;
                reason = frame->payload + 2;
            }

            if (!wsd_Parser_valid_close_code(code)) {
                code = WSD_PROTOCOL_ERROR;
                // TODO emit error on invalid code
            }
            wsd_Observer_on_close(parser->observer, code, length, reason);
            break;

        case WSD_OPCODE_PING:
            wsd_Observer_on_ping(parser->observer, frame);
            break;

        case WSD_OPCODE_PONG:
            wsd_Observer_on_pong(parser->observer, frame);
            break;
    }

    if (frame->opcode <= WSD_OPCODE_BINARY) {
        parser->frame = NULL;
        if (frame->final) wsd_Parser_emit_message(parser);
    } else {
        wsd_clear_pointer(wsd_Frame_destroy, parser->frame);
    }
}

int wsd_Parser_valid_close_code(int code)
{
    return code == WSD_NORMAL_CLOSURE ||
           code == WSD_GOING_AWAY ||
           code == WSD_PROTOCOL_ERROR ||
           code == WSD_UNACCEPTABLE ||
           code == WSD_ENCODING_ERROR ||
           code == WSD_POLICY_VIOLATION ||
           code == WSD_TOO_LARGE ||
           code == WSD_EXTENSION_ERROR ||
           code == WSD_UNEXPECTED_CONDITION ||
           (code >= WSD_MIN_RESERVED_ERROR && code <= WSD_MAX_RESERVED_ERROR);
}

void wsd_Parser_emit_message(wsd_Parser *parser)
{
    wsd_Observer_on_message(parser->observer, parser->message);

    wsd_clear_pointer(wsd_Message_destroy, parser->message);
}
