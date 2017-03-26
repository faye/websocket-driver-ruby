package com.jcoglan.websocket;

class Buffer {
    static long readUInt16(byte[] chunk, int n) {
        return bitshift(chunk[n    ], 8)
             | bitshift(chunk[n + 1], 0);
    }

    static long readUInt64(byte[] chunk, int n) {
        return bitshift(chunk[n    ], 56)
             | bitshift(chunk[n + 1], 48)
             | bitshift(chunk[n + 2], 40)
             | bitshift(chunk[n + 3], 32)
             | bitshift(chunk[n + 4], 24)
             | bitshift(chunk[n + 5], 16)
             | bitshift(chunk[n + 6],  8)
             | bitshift(chunk[n + 7],  0);
    }

    static void writeUInt16(byte[] chunk, int n, long value) {
        chunk[n    ] = (byte)(value >>> 8 & 0xff);
        chunk[n + 1] = (byte)(value       & 0xff);
    }

    static void writeUInt64(byte[] chunk, int n, long value) {
        chunk[n    ] = (byte)(value >>> 56 & 0xff);
        chunk[n + 1] = (byte)(value >>> 48 & 0xff);
        chunk[n + 2] = (byte)(value >>> 40 & 0xff);
        chunk[n + 3] = (byte)(value >>> 32 & 0xff);
        chunk[n + 4] = (byte)(value >>> 24 & 0xff);
        chunk[n + 5] = (byte)(value >>> 16 & 0xff);
        chunk[n + 6] = (byte)(value >>>  8 & 0xff);
        chunk[n + 7] = (byte)(value        & 0xff);
    }

    private static int bitshift(byte b, int n) {
        int c = b;
        if (c < 0) c += 256;
        return c << n;
    }
}
