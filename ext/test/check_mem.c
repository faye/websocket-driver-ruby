#include "parser.h"

void autobahn_on_error(void *receiver, int code, char *reason)
{
    printf("ERROR: code = %d, reason = %s\n", code, reason);
}

int main()
{
    int i = 0;
    char filename[100];
    FILE *file = NULL;

    uint64_t chunk_size = 512;
    uint8_t chunk[chunk_size];
    uint64_t read = 0;

    wsd_Observer *observer = NULL;
    wsd_Parser *parser = NULL;

    for (i = 1; i <= 303; i++) {
        observer = wsd_Observer_create(0, autobahn_on_error, 0, 0, 0, 0, 0);
        parser = wsd_Parser_create(observer, 1);

        sprintf(filename, "autobahn/test-%d.log", i);
        file = fopen(filename, "r");

        do {
            read = fread(chunk, sizeof(uint8_t), chunk_size, file);
            wsd_Parser_parse(parser, read, chunk);
        } while (read == chunk_size);

        fclose(file);
        wsd_clear_pointer(wsd_Parser_destroy, parser);
    }

    printf("OK\n");
}
