INCLUDE "hardware.inc"
INCLUDE "font.inc"
INCLUDE "common.inc"

SECTION "Header", ROM0[0]
    ds $38 - @

ConflictHandler::
    ; Reset SP, reset zero flag and jump back to test
    ld sp, $DFFE
    xor a
    rla
    jp Main.crashReset

    ds $100 - @

SECTION "Test", ROM0[$100]
EntryPoint::
    jr Main

ds $150 - @

;----------------------------------------------------------------------------
; WARNING: This whole thing is slightly experimental and chances are there's
;          something off with it.
;
; This ROM is intended to test bus conflict behavior on OAM DMA Transfers
; between different memory regions. PC stays in the ROM0 area while a
; transfer is started, and any bus conflicts *should* be detected and shown
; as an X in the result. If no conflicts are detected, an O should be shown.
;----------------------------------------------------------------------------
Main::
    ; Wait for VBlank
    ld a, [rLY]
    cp SCRN_Y
    jr c, Main

    ; Disable LCD
    xor a
    ldh [rLCDC], a

    ; Copy DoTest routine to WRAM
    ld hl, wDoTest
    ld de, DoTest
    ld bc, EndDoTest - DoTest
.copyRoutineLoop
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .copyRoutineLoop

    ; Initialize SP & HL
    ld sp, $E000
    ld hl, TestData

    ; Run Tests
.testLoop
    ; Check if at end of tests
    ld a, [hli]
    and a
    jr z, .testDone

    ; Preserve TestData Pointer & initialize tests
    push hl
    ld h, a
    ld l, $00
    call wDoTest

    ; RST $38 will jump back to here if conflict occurred
.crashReset
    ; Calculate HRAM Address to write Result to
    push af
    pop bc
    pop hl
    push hl
    dec hl
    ld a, l
    add LOW(_HRAM)
    sub LOW(TestData)
    ld l, a
    ld a, h
    sub HIGH(TestData)
    add HIGH(_HRAM)
    ld h, a

    ; Load result into HRAM and restart loop
    ld a, c
    ld [hl], a
    pop hl
    jr .testLoop
.testDone

    ; Initialize font & palettes
    call LoadFont
    ld hl, palResults
    ld c, LOW(rBCPD)
    call LoadPalette

    ; Print Results
    ld sp, resultStringMap
    ld bc, hResults
.resultPrintLoop
    ; Load Label Pointer and destination address, exit loop if null
    pop de
    pop hl
    ld a, d
    or e
    jr z, .resultsDone

    ; Print Label String
.printLabelLoop
    ld a, [de]
    inc de
    ld [hli], a
    and a
    jr nz, .printLabelLoop

    ; Print Result (C/N)
    dec hl
    ld a, [bc]
    inc bc
    and a
    jr nz, .printNoConflict
    ld a, "X"
    jr .doPrint
.printNoConflict
    ld a, "O"
.doPrint
    ld [hl], a
    jr .resultPrintLoop
.resultsDone

    ; Print ROM Title
    ld sp, $E000
    ld hl, $9821
    ld de, strTitle
    call Strcpy

    ; Re-enable LCD
    ld a, LCDCF_ON | LCDCF_BGON
    ldh [rLCDC], a

    ; Lock Up
    jr @

;----------------------------------------------------------------------------
; Loads OAM Data into the region at HL and starts an OAM DMA transfer
; from that region. Attempts to detect any occurring bus conflicts and
; sets the Zero flag to 0 if any are detected, to 1 otherwise.
;----------------------------------------------------------------------------
DoTest::
    ; Check if in MMIO, skip writes if so
    ld a, h
    inc a
    jr z, .skipLoadOAM

    ; Load OAM Data into source area
    ld b, $A0
    ld de, OAMData
.oamSrcLoadLoop
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .oamSrcLoadLoop
.skipLoadOAM

    ; Start OAM DMA
    ld b, 0
    ld a, h
    ldh [rDMA], a
    inc b
    
    ; Wait for finish (lots of NOPs to pad out bus-conflicted PC increases)
REPT 200
    nop 
ENDR

    ; It seems like the last value on the bus before a conflict (inc b in this case)
    ; keeps being executed? This checks if B is 1, if it is, probably no "hidden conflict".
    dec b
    jr z, .noConflictHidden

    ; Reset Zero flag and return
    xor a
    rla 
    ret

.noConflictHidden
    ; Set zero flag and return
    xor a
    ret
EndDoTest:

;----------------------------------------------------------------------------
; Addresses from which OAM DMA transfers should be executed.
;----------------------------------------------------------------------------
TestData:
    db HIGH(OAMData)
    db HIGH(_VRAM)
    db HIGH(_SRAM)
    db HIGH(_RAM)
    db $E0
    db HIGH(_OAMRAM)
    db HIGH(_IO)
    db $00
EndTestData:



SECTION "OAM Data", ROM0[$1000]
OAMData:
    ds $10A0 - @, $FF

SECTION "Palettes", ROM0
palResults: dw $FFFF, $0000, $0000, $0000

SECTION "Strings", ROM0
strTitle: db "WRAM Bus:", 0

resultStringMap:
    dw strROM,  $9861
    dw strVRAM, $98A1
    dw strSRAM, $98E1
    dw strWRAM, $9921
    dw strECHO, $9961
    dw strOAM,  $99A1
    dw strMMIO, $99E1
    dw $0000,   $0000

strROM:  db $1F, " ROM:  ", 0
strVRAM: db $1F, " VRAM: ", 0
strSRAM: db $1F, " SRAM: ", 0
strWRAM: db $1F, " WRAM: ", 0
strECHO: db $1F, " ECHO: ", 0
strOAM:  db $1F, " OAM:  ", 0
strMMIO: db $1F, " MMIO: ", 0

SECTION "WRAM", WRAM0
wDoTest: ds EndDoTest - DoTest

SECTION "HRAM", HRAM
hResults: ds EndTestData - TestData