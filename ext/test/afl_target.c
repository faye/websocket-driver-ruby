#include <stdio.h>
#include "parser.h"

int main()
{
    uint64_t chunk_size = 512;
    uint8_t chunk[chunk_size];
    uint64_t read = 0;

    wsd_Parser *parser = wsd_Parser_create(NULL, 1);

    do {
        read = fread(chunk, sizeof(uint8_t), chunk_size, stdin);
        wsd_Parser_parse(parser, read, chunk);
    } while (read == chunk_size);

    wsd_Parser_destroy(parser);
}
