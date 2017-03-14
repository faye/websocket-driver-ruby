CFLAGS	:= -g -O2 -Wall -Wextra -I../websocket_driver -fstack-protector-all

sources := queue.c chunk.c stream_reader.c \
           frame.c message.c extensions.c observer.c \
           parser.c unparser.c

objects := $(sources:%.c=tmp/%.o)

tests  	 := $(wildcard *.c)
test_bin := $(tests:%.c=%)

.PHONY: clean test

test: check_mem
	time valgrind --leak-check=full ./$^

check_mem: check_mem.c $(objects)
	$(CC) $(CFLAGS) -o $@ $^

tmp/%.o: ../websocket_driver/%.c
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf tmp $(test_bin) *.dSYM
