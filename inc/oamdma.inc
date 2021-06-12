SECTION "OAM DMA routine", ROMX
;----------------------------------------------------------------------------
; Copies the OAM DMA Routine to HRAM for initialization
;----------------------------------------------------------------------------
InitOAMDMA::
    ld hl, OAMDMA
    ld b, OAMDMA.end - OAMDMA
    ld c, LOW(hOAMDMA)
.copyOAMDMA
	ld a, [hli]
	ldh [c], a
	inc c
	dec b
	jr nz, .copyOAMDMA
    ret

;----------------------------------------------------------------------------
; Should be copied to HRAM, responsible for initializing an OAM DMA
; transfer and waiting until it is completed.
;
; Input:
;  * A - Value written to DMA register
;----------------------------------------------------------------------------
OAMDMA:
	ldh [rDMA], a
	ld a, 40
.wait
	dec a
	jr nz, .wait
	ret
.end

SECTION "OAM DMA", HRAM
hOAMDMA::
	ds OAMDMA.end - OAMDMA