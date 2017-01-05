CFLAGS	:= -g -O2 -Wall -Wextra -I../websocket_driver -fstack-protector-all

sources := queue.c read_buffer.c frame.c message.c observer.c parser.c
objects := $(sources:%.c=tmp/%.o)

tests  	 := $(wildcard *.c)
test_bin := $(tests:%.c=%)

.PHONY: clean test

test: check_mem
	valgrind --leak-check=full ./$^

check_mem: check_mem.c $(objects)
	$(CC) $(CFLAGS) -o $@ $^

tmp/%.o: ../websocket_driver/%.c
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf tmp $(test_bin) *.dSYM
