INCLUDE "hardware.inc"
INCLUDE "font.inc"
INCLUDE "common.inc"

BCPS_LABEL_ADDR_BASE EQU $9821
OCPS_LABEL_ADDR_BASE EQU $9861

SECTION "Header", ROM0[0]
    ds $100 - @

SECTION "Test", ROM0[$100]
EntryPoint::
    jr Main

ds $150 - @

;----------------------------------------------------------------------------
; This test ROM verifies the behavior of the BCPS and OCPS registers when
; automatic increments are enabled and the CPS register contains the highest
; possible value while the corresponding CPD register is written to.
;
; CPS registers should wrap around, resulting in the next write to the CPD
; register affecting palette 0.
;----------------------------------------------------------------------------
Main::
    ; Wait for VBlank
    ld a, [rLY]
    cp SCRN_Y
    jr c, Main

    ; Disable LCD
    xor a
    ldh [rLCDC], a

    ; Load Font Data into VRAM
    call LoadFont

    ; Initialize Palette Loading
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ldh [rOCPS], a

    ; Test BG Palettes
    ld hl, wReadBCPS
    ld c, LOW(rBCPD)
    call RunTest
    ld c, LOW(rOCPD)
    call RunTest       ; HL is at wReadOCPS at this point

    ; Write BCPS Label to Screen and preserve Pointer for Result String
    ld hl, BCPS_LABEL_ADDR_BASE
    ld de, strLabelBCPS
    call Strcpy
    dec hl
    push hl

    ; Check BCPS Results and display result
    ld hl, wReadBCPS
    call CheckResults
    jr z, .passBCPS
    ld de, strFail
    jr .printResultBCPS
.passBCPS
    ld de, strPass
.printResultBCPS
    pop hl
    call Strcpy

    ; Write OCPS Label to Screen and preserve Pointer for Result String
    ld hl, OCPS_LABEL_ADDR_BASE
    ld de, strLabelOCPS
    call Strcpy
    dec hl
    push hl

    ; Check OCPS Results and display result
    ld hl, wReadOCPS
    call CheckResults
    jr z, .passOCPS
    ld de, strFail
    jr .printResultOCPS
.passOCPS
    ld de, strPass
.printResultOCPS
    pop hl
    call Strcpy

    ; Reset BG Palette 0 to Display Results
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ld hl, palResults
    ld c, LOW(rBCPD)
    call LoadPalette

    ; Re-enable LCD
    ld a, LCDCF_ON | LCDCF_BGON
    ldh [rLCDC], a

    ; Lock Up
    jr @


;----------------------------------------------------------------------------
; Reads the state of the selected CPS register and stores it in memory, then
; writes to the CPD register to increment the CPS register.
;----------------------------------------------------------------------------
RunTest::
    ; Write to XCPD and read from XCPS 2*4*9 times
    ; 2 Writes per Color
    ; 4 Colors per Palette
    ; 9 Palettes (To cause XCPS Overflow)
    ld b, 2*4*9
.testLoop
    ; Read from XCPS and reset C to XCPD
    dec c
    ldh a, [$ff00+c]
    inc c

    ; Write to XCPD and Memory
    ldh [$ff00+c], a
    ld [hli], a

    ; Check if enough writes have occurred
    dec b
    jr nz, .testLoop
    ret


;----------------------------------------------------------------------------
; Checks 0x48 bytes in memory starting at HL for a series of incrementing
; values with the upper 2 bits always set to 1, as XCPS registers only
; contain 6-bit values.
;----------------------------------------------------------------------------
CheckResults::
    ; $C0 - Initial Value for XCPS registers
    ; $48 - Size of memory region to check
    ld bc, $C048
.checkLoop
    ; Load Value from HL, compare to B
    ld a, [hli]
    cp b
    jr nz, .failedCheck

    ; Increment B, keep bits 6 & 7 high
    ld a, b
    inc a
    or $C0
    ld b, a

    ; Check if end of values is reached
    dec c
    jr nz, .checkLoop

.passedCheck
    xor a       ; Set Zero Flag
    ret

.failedCheck
    rla         ; Reset Zero Flag
    ret



SECTION "Strings", ROM0
strLabelBCPS: db "BG Palette:  ", 0
strLabelOCPS: db "OBJ Palette: ", 0
strPass: db "OK!", 0
strFail: db "Fail!", 0



SECTION "Palettes", ROM0
palResults: dw $FFFF, $0000, $0000, $0000



SECTION "WRAM", WRAM0
wReadBCPS: ds 2*4*9
wReadOCPS: ds 2*4*9