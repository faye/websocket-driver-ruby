#ifndef _wsd_unparser_h
#define _wsd_unparser_h

#include "constants.h"
#include "frame.h"

typedef struct wsd_Unparser wsd_Unparser;

wsd_Unparser *  wsd_Unparser_create(int masking);
void            wsd_Unparser_destroy(wsd_Unparser *unparser);
uint64_t        wsd_Unparser_frame(wsd_Unparser *unparser, wsd_Frame *frame, uint8_t **out);

#endif
