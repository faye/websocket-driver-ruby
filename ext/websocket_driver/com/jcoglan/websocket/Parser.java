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
        MAX_RESERVED_ERROR    = 4999;

    private boolean requireMasking;

    private StreamReader reader;
    private Extensions extensions;
    private Observer observer;

    private int stage;
    private Frame frame;
    private Message message;

    private int errorCode;
    private String errorReason;

    public Parser(Extensions extensions, Observer observer, boolean requireMasking) {
        reader = new StreamReader();

        this.requireMasking = requireMasking;
        this.extensions = extensions;
        this.observer = observer;

        stage = 1;
        frame = null;
        message = null;

        errorCode = 0;
        errorReason = null;
    }

    public void parse(byte[] data) {
        reader.push(data);
        byte[] chunk = new byte[0];

        while (chunk != null) {
            switch (stage) {
                case 1:
                    chunk = reader.read(2);
                    if (chunk != null) parseHead(chunk);
                    break;
                case 2:
                    chunk = reader.read(frame.lengthBytes);
                    if (chunk != null) parseExtendedLength(chunk);
                    break;
                case 3:
                    chunk = reader.read(4);
                    if (chunk != null) {
                        stage = 4;
                        frame.maskingKey = chunk;
                    }
                    break;
                case 4:
                    chunk = reader.read((int)frame.length);
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

        if (!extensions.validFrameRsv(frame.rsv1, frame.rsv2, frame.rsv3, frame.opcode)) {
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
            if (!checkFrameLength()) return;
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
            frame.length = Buffer.readUInt16(chunk, 0);
        } else if (frame.length == 127) {
            frame.length = Buffer.readUInt64(chunk, 0);
        }

        if (controlOpcode(frame.opcode) && frame.length > 125) {
            parseError(PROTOCOL_ERROR, String.format("Received control frame having too long payload: %d", frame.length));
            return;
        }

        if (!checkFrameLength()) return;

        stage = frame.masked ? 3 : 4;
    }

    private boolean checkFrameLength() {
        if (Message.wouldOverflow(message, frame)) {
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
                    reason = new byte[0];
                } else if (frame.length >= 2) {
                    code   = (int)Buffer.readUInt16(frame.payload, 0);
                    reason = Arrays.copyOfRange(frame.payload, 2, (int)frame.length);
                }

                if (!validCloseCode(code)) {
                    code = PROTOCOL_ERROR;
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
}
