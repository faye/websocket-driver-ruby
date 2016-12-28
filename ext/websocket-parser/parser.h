#ifndef _wsd_parser_h
#define _wsd_parser_h

#include <inttypes.h>
#include <stdio.h>
#include "message.h"
#include "observer.h"
#include "read_buffer.h"
#include "util.h"

#define WSD_FIN     0x80
#define WSD_RSV1    0x40
#define WSD_RSV2    0x20
#define WSD_RSV3    0x10
#define WSD_OPCODE  0x0f
#define WSD_MASK    0x80
#define WSD_LENGTH  0x7f

#define WSD_OPCODE_CONTINUTATION    0
#define WSD_OPCODE_TEXT             1
#define WSD_OPCODE_BINARY           2
#define WSD_OPCODE_CLOSE            8
#define WSD_OPCODE_PING             9
#define WSD_OPCODE_PONG             10

#define WSD_NORMAL_CLOSURE          1000
#define WSD_GOING_AWAY              1001
#define WSD_PROTOCOL_ERROR          1002
#define WSD_UNACCEPTABLE            1003
#define WSD_ENCODING_ERROR          1007
#define WSD_POLICY_VIOLATION        1008
#define WSD_TOO_LARGE               1009
#define WSD_EXTENSION_ERROR         1010
#define WSD_UNEXPECTED_CONDITION    1011

typedef struct wsd_Parser wsd_Parser;

wsd_Parser *    wsd_Parser_create(wsd_Observer *observer);
void            wsd_Parser_destroy(wsd_Parser *parser);
int             wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data);
void            wsd_Parser_parse_head(wsd_Parser *parser, uint8_t *chunk);
int             wsd_Parser_valid_opcode(wsd_Parser *parser);
void            wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk);
uint64_t        wsd_Parser_parse_payload(wsd_Parser *parser);
void            wsd_Parser_emit_frame(wsd_Parser *parser);
void            wsd_Parser_emit_message(wsd_Parser *parser);

#define wsd_Parser_error(P, C, M, ...) \
    if (P->error_code == 0) { \
        P->stage = 0; \
        P->error_code = C; \
        asprintf(&P->error_message, M, ##__VA_ARGS__); \
        wsd_Observer_on_error(P->observer, P->error_code, P->error_message); \
    }

#endif
