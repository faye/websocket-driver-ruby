#define _GNU_SOURCE

#include "parser.h"

struct wsd_Parser {
    int require_masking;

    wsd_StreamReader *reader;
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

    parser->reader = wsd_StreamReader_create();
    if (parser->reader == NULL) {
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

    WSD_CLEAR_POINTER(wsd_StreamReader_destroy, parser->reader);
    WSD_CLEAR_POINTER(wsd_Frame_destroy, parser->frame);
    WSD_CLEAR_POINTER(wsd_Message_destroy, parser->message);
    WSD_CLEAR_POINTER(wsd_Extensions_destroy, parser->extensions);
    WSD_CLEAR_POINTER(wsd_Observer_destroy, parser->observer);
    WSD_CLEAR_POINTER(free, parser->error_reason);

    free(parser);
}

int wsd_Parser_parse(wsd_Parser *parser, size_t length, uint8_t *data)
{
    wsd_Chunk *chunk = NULL;
    size_t n = 0;
    size_t readlen = 0;

    chunk = wsd_Chunk_create(length, data);
    if (chunk == NULL) {
        WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate chunk");
        return parser->error_code;
    }

    if (!wsd_StreamReader_push(parser->reader, chunk)) {
        wsd_Chunk_destroy(chunk);
        WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to push chunk[%zu] to read buffer", length);
        return parser->error_code;
    }

    chunk = wsd_Chunk_alloc(8);
    if (chunk == NULL) {
        WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate memory for frame header");
        return parser->error_code;
    }

    while (readlen == n) {
        switch (parser->stage) {
            case 1:
                n = 2;
                readlen = wsd_StreamReader_read(parser->reader, n, chunk);
                if (readlen == n) wsd_Parser_parse_head(parser, chunk);
                break;
            case 2:
                n = parser->frame->length_bytes;
                readlen = wsd_StreamReader_read(parser->reader, n, chunk);
                if (readlen == n) wsd_Parser_parse_extended_length(parser, chunk);
                break;
            case 3:
                n = 4;
                readlen = wsd_StreamReader_read(parser->reader, n, parser->frame->masking_key);
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

    wsd_Chunk_destroy(chunk);
    return parser->error_code;
}

void wsd_Parser_parse_head(wsd_Parser *parser, wsd_Chunk *chunk)
{
    wsd_Frame *frame = wsd_Frame_create();
    if (frame == NULL) {
        WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate frame");
        return;
    }

    uint8_t b1 = wsd_Chunk_get(chunk, 0);
    uint8_t b2 = wsd_Chunk_get(chunk, 1);

    frame->final  = (b1 & WSD_FIN)  == WSD_FIN;
    frame->rsv1   = (b1 & WSD_RSV1) == WSD_RSV1;
    frame->rsv2   = (b1 & WSD_RSV2) == WSD_RSV2;
    frame->rsv3   = (b1 & WSD_RSV3) == WSD_RSV3;
    frame->opcode = (b1 & WSD_OPCODE);
    frame->masked = (b2 & WSD_MASK) == WSD_MASK;
    frame->length = (b2 & WSD_LENGTH);

    parser->frame = frame;

    if (!wsd_Extensions_valid_frame_rsv(parser->extensions, frame)) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR,
                "One or more reserved bits are on: reserved1 = %d, reserved2 = %d, reserved3 = %d",
                frame->rsv1, frame->rsv2, frame->rsv3);
        return;
    }

    if (!wsd_Parser_valid_opcode(frame->opcode)) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR, "Unrecognized frame opcode: %d", frame->opcode);
        return;
    }

    if (wsd_Parser_control_opcode(frame->opcode) && !frame->final) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR, "Received fragmented control frame: opcode = %d", frame->opcode);
        return;
    }

    if (parser->message == NULL && frame->opcode == WSD_OPCODE_CONTINUTATION) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR, "Received unexpected continuation frame");
        return;
    }

    if (parser->message != NULL && wsd_Parser_opening_opcode(frame->opcode)) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR, "Received new data frame but previous continuous frame is unfinished");
        return;
    }

    if (parser->require_masking && !frame->masked) {
        WSD_PARSER_ERROR(parser, WSD_UNACCEPTABLE, "Received unmasked frame but masking is required");
        return;
    }

    if (frame->length <= 125) {
        if (!wsd_Parser_check_frame_length(parser)) return;
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

void wsd_Parser_parse_extended_length(wsd_Parser *parser, wsd_Chunk *chunk)
{
    wsd_Frame *frame = parser->frame;

    if (frame->length == 126) {
        frame->length = wsd_Chunk_read_uint16(chunk, 0);
    } else if (frame->length == 127) {
        frame->length = wsd_Chunk_read_uint64(chunk, 0);
    }

    if (wsd_Parser_control_opcode(frame->opcode) && frame->length > 125) {
        WSD_PARSER_ERROR(parser, WSD_PROTOCOL_ERROR, "Received control frame having too long payload: %" PRIu64, frame->length);
        return;
    }

    if (!wsd_Parser_check_frame_length(parser)) return;

    parser->stage = frame->masked ? 3 : 4;
}

int wsd_Parser_check_frame_length(wsd_Parser *parser)
{
    if (wsd_Message_would_overflow(parser->message, parser->frame)) {
        WSD_PARSER_ERROR(parser, WSD_TOO_LARGE, "WebSocket frame length too large");
        return 0;
    } else {
        return 1;
    }
}

size_t  wsd_Parser_parse_payload(wsd_Parser *parser)
{
    wsd_StreamReader *reader = parser->reader;
    wsd_Frame *frame = parser->frame;
    size_t n = (size_t)frame->length;

    if (!wsd_StreamReader_has_capacity(reader, n)) return 0;

    frame->payload = wsd_Chunk_alloc(n);
    if (frame->payload == NULL) {
        WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate frame payload[%zu]", n);
        return 0;
    }

    n = wsd_StreamReader_read(reader, n, frame->payload);
    wsd_Frame_mask(frame);

    return n;
}

void wsd_Parser_emit_frame(wsd_Parser *parser)
{
    wsd_Frame *frame = parser->frame;

    int code = 0;
    wsd_Chunk *reason = NULL;

    parser->stage = 1;

    switch (frame->opcode) {
        case WSD_OPCODE_CONTINUTATION:
            if (!wsd_Message_push_frame(parser->message, frame)) {
                WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to add frame to message");
                return;
            }
            break;

        case WSD_OPCODE_TEXT:
        case WSD_OPCODE_BINARY:
            parser->message = wsd_Message_create(frame);
            if (parser->message == NULL) {
                WSD_PARSER_ERROR(parser, WSD_UNEXPECTED_CONDITION, "Failed to allocate message");
                return;
            }
            break;

        case WSD_OPCODE_CLOSE:
            if (frame->length == 0) {
                code   = WSD_DEFAULT_ERROR_CODE;
                reason = NULL;
            } else if (frame->length >= 2) {
                code   = wsd_Chunk_read_uint16(frame->payload, 0);
                reason = wsd_Chunk_slice(frame->payload, 2, 0);
            }

            if (!wsd_Parser_valid_close_code(code)) {
                code = WSD_PROTOCOL_ERROR;
            }
            wsd_Observer_on_close(parser->observer, code, reason);
            wsd_Chunk_destroy(reason);
            break;

        case WSD_OPCODE_PING:
            wsd_Observer_on_ping(parser->observer, frame->payload);
            break;

        case WSD_OPCODE_PONG:
            wsd_Observer_on_pong(parser->observer, frame->payload);
            break;
    }

    if (frame->opcode <= WSD_OPCODE_BINARY) {
        parser->frame = NULL;
        if (frame->final) wsd_Parser_emit_message(parser);
    } else {
        WSD_CLEAR_POINTER(wsd_Frame_destroy, parser->frame);
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

    WSD_CLEAR_POINTER(wsd_Message_destroy, parser->message);
}
