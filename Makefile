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
	$(eval SRCPATH := $(subst .gb,.asm, $(subst build,src,$@)))
	$(eval MBCTYPE := $(shell grep -Poi '; MBC 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(eval RAMSIZE := $(shell grep -Poi '; RAM 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(info MBC Type: 0x$(MBCTYPE))
	$(info RAM Size: 0x$(RAMSIZE))
	@$(RGBLINK) $(LDFLAGS) -o $@ $^
	@$(RGBFIX) $(FIXFLAGS) -r 0x$(RAMSIZE) -m 0x$(MBCTYPE) -c $@

build/./gbc/%.gb: build/gbc/%.o
	$(info Generating $(notdir $@c)... (GBC-Only))
	$(eval SRCPATH := $(subst .gb,.asm, $(subst build,src,$@)))
	$(eval MBCTYPE := $(shell grep -Poi '; MBC 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(eval RAMSIZE := $(shell grep -Poi '; RAM 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(info MBC Type: 0x$(MBCTYPE))
	$(info RAM Size: 0x$(RAMSIZE))
	@$(RGBLINK) $(LDFLAGS) -o $@c $^
	@$(RGBFIX) $(FIXFLAGS) -r 0x$(RAMSIZE) -m 0x$(MBCTYPE) -C $@c
	
build/./gb/%.gb: build/gb/%.o
	$(info Generating $(notdir $@)... (DMG-Only))
	$(eval SRCPATH := $(subst .gb,.asm, $(subst build,src,$@)))
	$(eval MBCTYPE := $(shell grep -Poi '; MBC 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(eval RAMSIZE := $(shell grep -Poi '; RAM 0x\K[0-9a-fA-F]{2}' $(SRCPATH)))
	$(info MBC Type: 0x$(MBCTYPE))
	$(info RAM Size: 0x$(RAMSIZE))
	@$(RGBLINK) $(LDFLAGS) -o $@ $^
	@$(RGBFIX) $(FIXFLAGS) -r 0x$(RAMSIZE) -m 0x$(MBCTYPE) $@

build/%.o: src/%.asm
	@mkdir -p $(dir $@)
	@$(RGBASM) $(ASFLAGS) -o $@ $<

all: $(addprefix build/, $(addsuffix .gb, $(basename $(SOURCES))))

.PHONY: clean
clean:
	rm -rf build