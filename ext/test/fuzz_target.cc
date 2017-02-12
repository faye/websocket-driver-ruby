#include "parser.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    wsd_Parser *parser = wsd_Parser_create(NULL, 1);

    wsd_Parser_parse(parser, (uint64_t)size, (uint8_t *)data);

    wsd_Parser_destroy(parser);

    return 0;
}
