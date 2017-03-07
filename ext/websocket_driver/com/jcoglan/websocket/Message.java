package com.jcoglan.websocket;

import java.util.ArrayList;
import java.util.List;

public class Message {
    static int MAX_LENGTH = 0x3ffffff;

    public int opcode;
    public boolean rsv1;
    public boolean rsv2;
    public boolean rsv3;
    int length;
    List<Frame> frames;

    static boolean wouldOverflow(Message message, Frame frame) {
        int mlen  = (message == null) ? 0 : message.length;
        long flen = frame.length;

        return flen < 0 || flen > MAX_LENGTH - mlen;
    }

    Message() {
        length = 0;
        frames = new ArrayList<Frame>();
    }

    Message(Frame frame) {
        this();
        push(frame);

        opcode = frame.opcode;
        rsv1   = frame.rsv1;
        rsv2   = frame.rsv2;
        rsv3   = frame.rsv3;
    }

    void push(Frame frame) {
        length += frame.length;
        frames.add(frame);
    }

    public byte[] copy() {
        byte[] target = new byte[length];
        int offset = 0;

        for (Frame frame : frames) {
            System.arraycopy(frame.payload, 0, target, offset, (int)frame.length);
            offset += frame.length;
        }

        return target;
    }
}
