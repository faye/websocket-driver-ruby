package com.jcoglan.websocket;

public class Unparser {
    private static final byte
        FIN                   = -0x80,
        RSV1                  =  0x40,
        RSV2                  =  0x20,
        RSV3                  =  0x10,
        OPCODE                =  0x0f,
        MASK                  = -0x80,
        LENGTH                =  0x7f;

    private boolean masking;

    public Unparser(boolean masking) {
        this.masking = masking;
    }

    public byte[] frame(Frame frame) {
        int flen    = frame.length,
            lenlen  = (flen <= 125) ? 0 : (flen <= 65535) ? 2 : 8,
            masklen = masking ? 4 : 0,
            buflen  = 2 + lenlen + masklen + flen;

        byte[] buf  = new byte[buflen];
        int mask    = 0;

        buf[0] = (byte)( (frame.fin ? FIN : 0)
                       | (frame.rsv1 ? RSV1 : 0)
                       | (frame.rsv2 ? RSV2 : 0)
                       | (frame.rsv3 ? RSV3 : 0)
                       | frame.opcode );

        if (masking) {
            frame.masked = true;
            Frame.mask(frame);
            mask = MASK;
        }

        if (lenlen == 0) {
            buf[1] = (byte)(mask | flen);

        } else if (lenlen == 2) {
            buf[1] = (byte)(mask | 126);
            buf[2] = (byte)(flen >> 8 & 0xff);
            buf[3] = (byte)(flen      & 0xff);

        } else {
            buf[1] = (byte)(mask | 127);
            buf[2] = (byte)(flen >> 56 & 0xff);
            buf[3] = (byte)(flen >> 48 & 0xff);
            buf[4] = (byte)(flen >> 40 & 0xff);
            buf[5] = (byte)(flen >> 32 & 0xff);
            buf[6] = (byte)(flen >> 24 & 0xff);
            buf[7] = (byte)(flen >> 16 & 0xff);
            buf[8] = (byte)(flen >>  8 & 0xff);
            buf[9] = (byte)(flen       & 0xff);
        }

        System.arraycopy(frame.maskingKey, 0, buf, 2 + lenlen, masklen);
        System.arraycopy(frame.payload, 0, buf, 2 + lenlen + masklen, frame.length);

        return buf;
    }
}
