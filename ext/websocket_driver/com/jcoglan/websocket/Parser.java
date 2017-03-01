package com.jcoglan.websocket;

import java.util.Arrays;

public class Parser {
    private static final int
        FIN                   = 0x80,
        RSV1                  = 0x40,
        RSV2                  = 0x20,
        RSV3                  = 0x10,
        OPCODE                = 0x0f,
        MASK                  = 0x80,
        LENGTH                = 0x7f,

        OPCODE_CONTINUTATION  = 0,
        OPCODE_TEXT           = 1,
        OPCODE_BINARY         = 2,
        OPCODE_CLOSE          = 8,
        OPCODE_PING           = 9,
        OPCODE_PONG           = 10,

        NORMAL_CLOSURE        = 1000,
        GOING_AWAY            = 1001,
        PROTOCOL_ERROR        = 1002,
        UNACCEPTABLE          = 1003,
        ENCODING_ERROR        = 1007,
        POLICY_VIOLATION      = 1008,
        TOO_LARGE             = 1009,
        EXTENSION_ERROR       = 1010,
        UNEXPECTED_CONDITION  = 1011,

        DEFAULT_ERROR_CODE    = 1000,
        MIN_RESERVED_ERROR    = 3000,
        MAX_RESERVED_ERROR    = 4999,

        MAX_MESSAGE_LENGTH    = 0x3ffffff;

    private boolean requireMasking;

    private ReadBuffer buffer;
    private Observer observer;

    private int stage;
    private Frame frame;
    private Message message;

    private int errorCode;
    private String errorReason;

    public Parser(Observer observer, boolean requireMasking) {
        buffer = new ReadBuffer();

        this.requireMasking = requireMasking;
        this.observer = observer;

        stage = 1;
        frame = null;
        message = null;

        errorCode = 0;
        errorReason = null;
    }

    public void parse(byte[] data) {
        buffer.push(data);
        byte[] chunk = new byte[0];

        while (chunk != null) {
            switch (stage) {
                case 1:
                    chunk = buffer.read(2);
                    if (chunk != null) parseHead(chunk);
                    break;
                case 2:
                    chunk = buffer.read(frame.lengthBytes);
                    if (chunk != null) parseExtendedLength(chunk);
                    break;
                case 3:
                    chunk = buffer.read(4);
                    if (chunk != null) {
                        stage = 4;
                        frame.maskingKey = chunk;
                    }
                    break;
                case 4:
                    chunk = buffer.read((int)frame.length);
                    if (chunk != null) {
                        stage = 1;
                        emitFrame(chunk);
                    }
                    break;
                default:
                    chunk = null;
                    break;
            }
        }
    }

    private void parseError(int code, String reason) {
        if (errorCode != 0) return;

        stage       = 0;
        errorCode   = code;
        errorReason = reason;

        observer.onError(code, reason);
    }

    private void parseHead(byte[] chunk) {
        frame = new Frame();

        frame.fin    = (chunk[0] & FIN)  == FIN;
        frame.rsv1   = (chunk[0] & RSV1) == RSV1;
        frame.rsv2   = (chunk[0] & RSV2) == RSV2;
        frame.rsv3   = (chunk[0] & RSV3) == RSV3;
        frame.opcode = (chunk[0] & OPCODE);
        frame.masked = (chunk[1] & MASK) == MASK;
        frame.length = (chunk[1] & LENGTH);

        // TODO check RSV bits by calling back the ruby driver (requires extensions)
        if (frame.rsv1 || frame.rsv2 || frame.rsv3) {
            parseError(PROTOCOL_ERROR, 
                String.format("One or more reserved bits are on: reserved1 = %d, reserved2 = %d, reserved3 = %d",
                    frame.rsv1 ? 1 : 0,
                    frame.rsv2 ? 1 : 0,
                    frame.rsv3 ? 1 : 0));
            return;
        }

        if (!validOpcode(frame.opcode)) {
            parseError(PROTOCOL_ERROR, String.format("Unrecognized frame opcode: %d", frame.opcode));
            return;
        }

        if (controlOpcode(frame.opcode) && !frame.fin) {
            parseError(PROTOCOL_ERROR, String.format("Received fragmented control frame: opcode = %d", frame.opcode));
            return;
        }

        if (message == null && frame.opcode == OPCODE_CONTINUTATION) {
            parseError(PROTOCOL_ERROR, "Received unexpected continuation frame");
            return;
        }

        if (message != null && openingOpcode(frame.opcode)) {
            parseError(PROTOCOL_ERROR, "Received new data frame but previous continuous frame is unfinished");
            return;
        }

        if (requireMasking && !frame.masked) {
            parseError(UNACCEPTABLE, "Received unmasked frame but masking is required");
            return;
        }

        if (frame.length <= 125) {
            if (!checkLength()) return;
            stage = frame.masked ? 3 : 4;
        } else {
            stage = 2;
            frame.lengthBytes = (frame.length == 126) ? 2 : 8;
        }
    }

    private boolean validOpcode(int opcode) {
        return controlOpcode(opcode) || messageOpcode(opcode);
    }

    private boolean controlOpcode(int opcode) {
        return opcode == OPCODE_CLOSE ||
               opcode == OPCODE_PING ||
               opcode == OPCODE_PONG;
    }

    private boolean messageOpcode(int opcode) {
        return openingOpcode(opcode) || opcode == OPCODE_CONTINUTATION;
    }

    private boolean openingOpcode(int opcode) {
        return opcode == OPCODE_TEXT ||
               opcode == OPCODE_BINARY;
    }

    private void parseExtendedLength(byte[] chunk) {
        if (frame.length == 126) {
            frame.length = bitshift(chunk[0], 8)
                         | bitshift(chunk[1], 0);

        } else if (frame.length == 127) {
            frame.length = bitshift(chunk[0], 56)
                         | bitshift(chunk[1], 48)
                         | bitshift(chunk[2], 40)
                         | bitshift(chunk[3], 32)
                         | bitshift(chunk[4], 24)
                         | bitshift(chunk[5], 16)
                         | bitshift(chunk[6], 8)
                         | bitshift(chunk[7], 0);
        }

        if (controlOpcode(frame.opcode) && frame.length < 125) {
            parseError(PROTOCOL_ERROR, String.format("Received control frame having too long payload: %d", frame.length));
            return;
        }

        if (!checkLength()) return;

        stage = frame.masked ? 3 : 4;
    }

    private boolean checkLength() {
        long length = (message == null) ? 0 : message.length;

        if (length + frame.length > MAX_MESSAGE_LENGTH) {
            parseError(TOO_LARGE, "WebSocket frame length too large");
            return false;
        } else {
            return true;
        }
    }

    private void emitFrame(byte[] chunk) {
        frame.payload = chunk;
        Frame.mask(frame);

        stage = 1;

        int code = 0;
        byte[] reason = new byte[0];

        switch (frame.opcode) {
            case OPCODE_CONTINUTATION:
                message.push(frame);
                break;

            case OPCODE_TEXT:
            case OPCODE_BINARY:
                message = new Message(frame);
                break;

            case OPCODE_CLOSE:
                if (frame.length == 0) {
                    code   = DEFAULT_ERROR_CODE;
                } else if (frame.length >= 2) {
                    code   = bitshift(frame.payload[0], 8) | bitshift(frame.payload[1], 0);
                    reason = Arrays.copyOfRange(frame.payload, 2, (int)frame.length);
                }

                if (!validCloseCode(code)) {
                    code = PROTOCOL_ERROR;
                    // TODO emit error on invalid code
                }
                observer.onClose(code, reason);
                break;

            case OPCODE_PING:
                observer.onPing(frame);
                break;

            case OPCODE_PONG:
                observer.onPong(frame);
                break;
        }

        if (frame.opcode <= OPCODE_BINARY && frame.fin) emitMessage();
        frame = null;
    }

    private boolean validCloseCode(int code) {
        return code == NORMAL_CLOSURE ||
               code == GOING_AWAY ||
               code == PROTOCOL_ERROR ||
               code == UNACCEPTABLE ||
               code == ENCODING_ERROR ||
               code == POLICY_VIOLATION ||
               code == TOO_LARGE ||
               code == EXTENSION_ERROR ||
               code == UNEXPECTED_CONDITION ||
               (code >= MIN_RESERVED_ERROR && code <= MAX_RESERVED_ERROR);
    }

    private void emitMessage() {
        observer.onMessage(message);
        message = null;
    }

    private int bitshift(byte b, int n) {
        int c = b;
        if (c < 0) c += 256;
        return c << n;
    }
}
