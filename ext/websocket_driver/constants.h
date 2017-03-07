#ifndef _wsd_constants_h
#define _wsd_constants_h

#define WSD_FIN                     0x80
#define WSD_RSV1                    0x40
#define WSD_RSV2                    0x20
#define WSD_RSV3                    0x10
#define WSD_OPCODE                  0x0f
#define WSD_MASK                    0x80
#define WSD_LENGTH                  0x7f

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

#define WSD_DEFAULT_ERROR_CODE      1000
#define WSD_MIN_RESERVED_ERROR      3000
#define WSD_MAX_RESERVED_ERROR      4999

#endif
