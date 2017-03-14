#include "parser.h"
#include "unparser.h"

void autobahn_on_error(void *receiver, int code, char *reason)
{
    printf("[ERROR] code = %d, reason = %s\n", code, reason);
}

void autobahn_on_message(void *receiver, wsd_Message *message)
{
    wsd_Frame *frame = wsd_Frame_create();
    wsd_Chunk *chunk = NULL;
    wsd_Unparser *unparser = NULL;

    frame->final  = 1;
    frame->rsv1   = 0;
    frame->rsv2   = 0;
    frame->rsv3   = 0;
    frame->opcode = 1;
    frame->length = message->length;

    frame->payload = wsd_Chunk_alloc(frame->length);
    wsd_Message_copy(message, frame->payload);

    unparser = wsd_Unparser_create(1);
    chunk = wsd_Unparser_frame(unparser, frame);

    wsd_Chunk_destroy(chunk);
    wsd_Frame_destroy(frame);
    wsd_Unparser_destroy(unparser);
}

void autobahn_on_close(void *receiver, int code, wsd_Chunk *reason) {

}

void autobahn_on_ping(void *receiver, wsd_Chunk *payload) {

}

void autobahn_on_pong(void *receiver, wsd_Chunk *payload) {

}


int main()
{
    int i = 0;
    char filename[100];
    FILE *file = NULL;

    uint64_t chunk_size = 4096;
    uint8_t chunk[chunk_size];
    uint64_t read = 0;

    wsd_Extensions *extensions = NULL;
    wsd_Observer *observer = NULL;
    wsd_Parser *parser = NULL;

    for (i = 1; i <= 303; i++) {
        observer = wsd_Observer_create(0,
                autobahn_on_error,
                autobahn_on_message,
                autobahn_on_close,
                autobahn_on_ping,
                autobahn_on_pong);

        extensions = wsd_Extensions_create_default();
        parser = wsd_Parser_create(extensions, observer, 1);

        sprintf(filename, "autobahn/test-%d.log", i);
        file = fopen(filename, "r");

        do {
            read = fread(chunk, sizeof(uint8_t), chunk_size, file);
            wsd_Parser_parse(parser, read, chunk);
        } while (read == chunk_size);

        fclose(file);
        wsd_clear_pointer(wsd_Parser_destroy, parser);
    }

    printf("[OK]\n");
}
