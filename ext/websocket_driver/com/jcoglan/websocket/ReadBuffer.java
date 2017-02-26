package com.jcoglan.websocket;

import java.util.LinkedList;
import java.util.Queue;

class ReadBuffer {
    private Queue<byte[]> queue;
    private int capacity;
    private int cursor;

    ReadBuffer() {
        queue    = new LinkedList<byte[]>();
        capacity = 0;
        cursor   = 0;
    }

    boolean push(byte[] chunk) {
        queue.add(chunk);
        capacity += chunk.length; // TODO check for int overflow
        return true;
    }

    byte[] read(int length) {
        if (capacity < length) return null;

        byte[] target = new byte[length];
        int offset = 0;

        while (offset < length) {
            byte[] chunk = queue.peek();

            int available = chunk.length - cursor;
            int required  = length - offset;
            int takeBytes = (available < required) ? available : required;

            System.arraycopy(chunk, cursor, target, offset, takeBytes);
            offset += takeBytes;

            if (takeBytes == available ) {
                cursor = 0;
                queue.remove();
            } else {
                cursor += takeBytes;
            }
        }

        capacity -= length;
        return target;
    }
}
