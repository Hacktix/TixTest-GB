RGBASM = rgbasm
RGBLINK = rgblink
RGBFIX = rgbfix

SOURCES = $(shell cd ./src; find . -name "*.asm")
EXT=*.o *.gb

NAME = TIXTEST-GB
ASFLAGS = -h -i inc
LDFLAGS = -t -w -x
FIXFLAGS = -v -p0 -t $(NAME)

build/./any/%.gb: build/any/%.o
	$(info Generating $(notdir $@)... (GBC-Compatible))
	@$(RGBLINK) $(LDFLAGS) -o $@ $^
	@$(RGBFIX) $(FIXFLAGS) -c $@

build/./gbc/%.gb: build/gbc/%.o
	$(info Generating $(notdir $@c)... (GBC-Only))
	@$(RGBLINK) $(LDFLAGS) -o $@c $^
	@$(RGBFIX) $(FIXFLAGS) -C $@c
	
build/./gb/%.gb: build/gb/%.o
	$(info Generating $(notdir $@)... (DMG-Only))
	@$(RGBLINK) $(LDFLAGS) -o $@ $^
	@$(RGBFIX) $(FIXFLAGS) $@

build/%.o: src/%.asm
	@mkdir -p $(dir $@)
	@$(RGBASM) $(ASFLAGS) -o $@ $<

all: $(addprefix build/, $(addsuffix .gb, $(basename $(SOURCES))))

.PHONY: clean
clean:
	rm -rf build