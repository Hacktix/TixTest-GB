SECTION "Font", ROM0

LoadFont::
    ld hl, $9000
    ld de, FontData
    ld bc, EndFontData - FontData
.loadFontLoop
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .loadFontLoop
    ret

FontData::
INCBIN "font.bin"
EndFontData::