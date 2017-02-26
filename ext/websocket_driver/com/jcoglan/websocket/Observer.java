package com.jcoglan.websocket;

public interface Observer {
    void onError(int code, String reason);
    void onMessage(Message message);
    void onClose(int code, byte[] reason);
    void onPing(Frame frame);
    void onPong(Frame frame);
}
