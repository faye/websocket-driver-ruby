#ifndef _wsd_parser_h
#define _wsd_parser_h

#include <inttypes.h>
#include <stdio.h>
#include "constants.h"
#include "message.h"
#include "observer.h"
#include "read_buffer.h"
#include "util.h"

typedef struct wsd_Parser wsd_Parser;

wsd_Parser *    wsd_Parser_create(wsd_Observer *observer, int require_masking);
void            wsd_Parser_destroy(wsd_Parser *parser);
int             wsd_Parser_parse(wsd_Parser *parser, uint64_t length, uint8_t *data);
void            wsd_Parser_parse_head(wsd_Parser *parser, uint8_t *chunk);
int             wsd_Parser_valid_opcode(int opcode);
int             wsd_Parser_control_opcode(int opcode);
int             wsd_Parser_message_opcode(int opcode);
int             wsd_Parser_opening_opcode(int opcode);
void            wsd_Parser_parse_extended_length(wsd_Parser *parser, uint8_t *chunk);
int             wsd_Parser_check_length(wsd_Parser *parser);
uint64_t        wsd_Parser_parse_payload(wsd_Parser *parser);
void            wsd_Parser_emit_frame(wsd_Parser *parser);
int             wsd_Parser_valid_close_code(int code);
void            wsd_Parser_emit_message(wsd_Parser *parser);

#define wsd_Parser_error(P, C, M, ...) \
    if (P->error_code == 0) { \
        P->stage = 0; \
        P->error_code = C; \
        asprintf(&P->error_reason, M, ##__VA_ARGS__); \
        wsd_Observer_on_error(P->observer, P->error_code, P->error_reason); \
    }

#endif
