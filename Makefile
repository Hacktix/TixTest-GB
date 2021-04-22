RGBASM = rgbasm
RGBLINK = rgblink
RGBFIX = rgbfix

SOURCES = $(shell cd ./src; find . -name "*.asm")
EXT=*.o *.gb

NAME = TIXTEST-GB
ASFLAGS = -h -i inc
LDFLAGS = -t -w -x
FIXFLAGS = -v -p0 -t $(NAME)

build/%.gb: build/%.o
	$(RGBLINK) $(LDFLAGS) -o $@ $^
	$(RGBFIX) $(FIXFLAGS) -c $@

build/%.o: %.asm
	mkdir -p $(dir $@)
	$(RGBASM) $(ASFLAGS) -o $@ $<

all: $(addprefix build/, $(addprefix src/, $(addsuffix .gb, $(basename $(SOURCES)))))

.PHONY: clean
clean:
	rm -rf build