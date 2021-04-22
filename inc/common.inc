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