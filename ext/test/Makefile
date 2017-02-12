CFLAGS	:= -I../websocket_driver -g -O2 -Wall -Wextra -fstack-protector-all

sources      := frame.c message.c observer.c parser.c queue.c read_buffer.c
source_paths := $(sources:%=../websocket_driver/%)
objects      := $(sources:%.c=tmp/%.o)
afl_objects  := $(sources:%.c=afl/tmp/%.o)

AFL_CC := ./afl/afl-2*/afl-gcc

tests  	 := $(wildcard *.c)
test_bin := $(tests:%.c=%)

.PHONY: clean fuzz test

clang_path := third_party/llvm-build/Release+Asserts
clang      := $(clang_path)/bin/clang
PATH       := $(clang_path)/bin:$(PATH)

$(clang):
	mkdir TMP_CLANG
	git clone https://chromium.googlesource.com/chromium/src/tools/clang TMP_CLANG/clang
	./TMP_CLANG/clang/scripts/update.py

libFuzzer.a: $(clang)
	git clone https://chromium.googlesource.com/chromium/llvm-project/llvm/lib/Fuzzer
	./Fuzzer/build.sh

fuzz_target: libFuzzer.a $(source_paths)
	$(clang)++ -fsanitize-coverage=trace-pc-guard \
	           -fsanitize=address \
	           -I ../websocket_driver \
	           $^ \
	           fuzz_target.cc \
	           -o fuzz_target

fuzz: afl afl/in afl_target
	./afl/afl-2*/afl-fuzz -i afl/in -o afl/out ./afl_target

afl:
	mkdir -p afl
	wget http://lcamtuf.coredump.cx/afl/releases/afl-latest.tgz -O afl/latest.tgz
	cd afl && tar -zxvf latest.tgz
	cd afl/afl-2* && make

afl/in:
	mkdir -p afl/in
	find autobahn -type f -size -1048576c -exec cp {} afl/in \;

afl_target: afl_target.c $(afl_objects)
	$(AFL_CC) $(CFLAGS) -o $@ $^

afl/tmp/%.o: ../websocket_driver/%.c afl
	@mkdir -p afl/tmp
	$(AFL_CC) $(CFLAGS) -o $@ -c $<

test: check_mem
	valgrind --leak-check=full ./$^

check_mem: check_mem.c $(objects)
	$(CC) $(CFLAGS) -o $@ $^

tmp/%.o: ../websocket_driver/%.c
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf tmp $(test_bin) *.dSYM afl/in afl/out afl/tmp
