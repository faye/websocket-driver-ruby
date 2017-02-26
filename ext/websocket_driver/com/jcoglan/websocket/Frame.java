package com.jcoglan.websocket;

public class Frame {
    boolean fin;
    boolean rsv1;
    boolean rsv2;
    boolean rsv3;
    int opcode;
    boolean masked;
    byte[] maskingKey;
    int lengthBytes;
    int length;
    public byte[] payload;

    static void mask(Frame frame) {
        if (!frame.masked) return;

        for (int i = 0; i < frame.length; i++) {
            frame.payload[i] ^= frame.maskingKey[i % 4];
        }
    }
}
