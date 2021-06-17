SECTION "Common Functions", ROM0
;----------------------------------------------------------------------------
; Input:
;  DE - Pointer to String
;  HL - Pointer to Destination
;----------------------------------------------------------------------------
Strcpy::
    ld a, [de]
    inc de
    ld [hli], a
    and a
    ret z
    jr Strcpy

;----------------------------------------------------------------------------
; Input:
;  BC - Amount of bytes to copy
;  DE - Pointer to Source
;  HL - Pointer to Destination
;----------------------------------------------------------------------------
Memcpy::
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, Memcpy
    ret

;------------------------------------------------------------------------
; Input:
;  A - Value to be converted
;
; Output:
;  DE - ASCII-encoded hex characters
;------------------------------------------------------------------------
ConvertToASCII::
    push af
    call ConvertNibbleToASCII
    ld e, a
    pop af
    swap a
    call ConvertNibbleToASCII
    ld d, a
    ret

;------------------------------------------------------------------------
; Input:
;  A - Value to be converted
;------------------------------------------------------------------------
ConvertNibbleToASCII::
    and $0F
    cp 10
    jr nc, .letterCharacter
    add "0"
    ret
.letterCharacter
    add ("A"-10)
    ret

;----------------------------------------------------------------------------
; Input:
;  HL - Pointer to Palette (8 consecutive bytes)
;  C  - $69 for BCPD, $6B for OCPD
;----------------------------------------------------------------------------
LoadPalette::
    ld b, 8
.loadPaletteLoop
    ld a, [hli]
    ldh [$ff00+c], a
    dec b
    jr nz, .loadPaletteLoop
    ret