package com.jcoglan.websocket;

public interface Extensions {
    boolean validFrameRsv(boolean rsv1, boolean rsv2, boolean rsv3, int opcode);
}
