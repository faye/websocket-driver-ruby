package com.jcoglan.websocket;

public class Frame {
    public boolean fin;
    public boolean rsv1;
    public boolean rsv2;
    public boolean rsv3;
    public int opcode;
    public boolean masked;
    public byte[] maskingKey;
    int lengthBytes;
    public long length;
    public byte[] payload;

    static void mask(Frame frame) {
        if (!frame.masked) return;

        for (int i = 0; i < frame.length; i++) {
            frame.payload[i] ^= frame.maskingKey[i % 4];
        }
    }
}
