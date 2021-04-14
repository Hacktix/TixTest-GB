RGBASM = rgbasm
RGBLINK = rgblink

SOURCES = $(shell cd ./src; find . -name "*.asm")
EXT=*.o *.gb

ASFLAGS = -h
LDFLAGS = -t -w -x

build/%.gb: build/%.o
	$(RGBLINK) $(LDFLAGS) -o $@ $^

build/%.o: %.asm
	mkdir -p $(dir $@)
	$(RGBASM) $(ASFLAGS) -o $@ $<

all: $(addprefix build/, $(addprefix src/, $(addsuffix .gb, $(basename $(SOURCES)))))

.PHONY: clean
clean:
	rm -rf build