; ===== Makefile Headers =====
; MBC 0x00
; RAM 0x00

INCLUDE "hardware.inc"
INCLUDE "font.inc"
INCLUDE "common.inc"

SCROLL_INIT_COOLDOWN EQU 20
SCROLL_ITER_COOLDOWN EQU 3

SECTION "Header", ROM0[0]
    ds $40 - @
VBlank:
    jp HandleVBlank

    ds $100 - @

SECTION "Test", ROM0[$100]
EntryPoint::
    jr Main

ds $150 - @

;----------------------------------------------------------------------------
; This Test ROM ROM is intended as an emulator debugging tool to assist with
; PPU timings. It allows for running a variable amount of machine cycles
; (referred to as NOPs) before storing the status of the STAT register.
;----------------------------------------------------------------------------
Main::
    ;====================================================
    ; Wait for VBlank & Stop PPU
    ld a, [rLY]
    cp SCRN_Y
    jr c, Main
    xor a
    ldh [rLCDC], a
    
    ;====================================================
    ; Initialize Palettes

    ; DMG Palettes
    ld a, %11100100
    ldh [rBGP], a

    ; CGB Palettes
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ld c, LOW(rBCPD)
    ld hl, defaultPalette
    call LoadPalette
    ld hl, errorPalette
    call LoadPalette
    ld hl, passPalette
    call LoadPalette
    
    ;====================================================
    ; Initialize important Variables
    ld sp, $DFFF
    xor a
    ld [wReadSTAT], a
    ld [wJoypadScrollCooldown], a
    ld [wJoypadCooldown], a
    inc a
    ld [wCountNOP], a

    ; Set LYC to FF so that the coincidence bit isn't set
    ld a, $FF
    ldh [rLYC], a
    
    ;====================================================
    ; Clear VRAM before anything
    ld hl, $8000
    ld de, $2000
.vramClearLoop
    xor a
    ld [hli], a
    dec de
    ld a, d
    or e
    jr nz, .vramClearLoop
    
    ;====================================================
    ; Load Font Data & Tilemap into VRAM

    ; Font Tiles
    call LoadFont

    ; "NOPs" String
    ld hl, $9821
    ld de, strNOPs
    call Strcpy
    
    ; "NOPs" String
    ld hl, $9861
    ld de, strRead
    call Strcpy

    ; "Exp." String
    ld hl, $98A1
    ld de, strExpected
    call Strcpy

    ; "Press Start" String
    ld hl, $9A01
    ld de, strPressStart
    call Strcpy
    
    ;====================================================
    ; Re-enable LCD & Interrupts
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    ei
    ld a, LCDCF_ON | LCDCF_BG8800 | LCDCF_BGON
    ldh [rLCDC], a
    
.mainLoop
    ;====================================================
    ; Main Loop - Fetch input state and HALT

    ; Fetch D-Pad bits
    ld c, LOW(rP1)
	ld a, $20
	ldh [c], a
	ldh a, [c]
	or $F0
	ld b, a
	swap b

    ; Fetch Button bits
	ld a, $10
	ldh [c], a
	ldh a, [c]
	or $F0
	xor b
	ld b, a

	; Release joypad
	ld a, $30
	ldh [c], a

    ; Update HRAM Variables
	ldh a, [hHeldKeys]
	cpl
	and b
	ldh [hPressedKeys], a
	ld a, b
	ldh [hHeldKeys], a

    ; Wait for VBlank
    halt
    jr .mainLoop


;----------------------------------------------------------------------------
; Called when the START Button is pressed. Starts a test run and prints
; the results to screen, then returns to the main loop.
;----------------------------------------------------------------------------
RunTest::
    ;====================================================
    ; Turn off LCD & Interrupts
    xor a
    ldh [rLCDC], a
    ldh [rIE], a
    di 

    ;====================================================
    ; Prepare C for STAT Read, check if 1 NOP selected
    ld c, LOW(rSTAT)
    ld a, [wCountNOP]
    dec a
    jr z, .singleNopTest

    ;====================================================
    ; Calculate jump address
    ld hl, ClockslideBase
    ld a, [wCountNOP]
    ld b, a
    ld a, $FF
    sub b
    add l
    ld l, a
    adc h
    sub l
    ld h, a

    ;====================================================
    ; Enable LCD and start test
    ld a, LCDCF_ON
    ldh [rLCDC], a
    jp hl

.singleNopTest
    ;====================================================
    ; Enable LCD and immediately read from STAT
    ld a, LCDCF_ON
    ldh [rLCDC], a
    ld a, [$ff00+c]
    
    ;====================================================
    ; Store variables in memory and end test run
    ld [wReadSTAT], a
    jp ClockslideBase.postTestCleanup

;----------------------------------------------------------------------------
; 253 NOPs followed by code to store STAT in RAM
;  - 1 Cycle timeout by JP HL
;  - n Cycles timeout by NOPs
;  - 1 Cycle timeout by LD A, [$FF00+C]
;  => 253 NOP instructions for 255 NOPs
;----------------------------------------------------------------------------
ClockslideBase::
REPT $FD
    nop 
ENDR
    ;====================================================
    ; Store variables in memory and end test run
    ld a, [$ff00+c]
    ld [wReadSTAT], a

.postTestCleanup
    ;====================================================
    ; Wait for VBlank & Stop PPU
    ld a, [rLY]
    cp SCRN_Y
    jr c, .postTestCleanup
    xor a
    ldh [rLCDC], a

    ;====================================================
    ; Print read STAT value to screen
    ld a, [wReadSTAT]
    call ConvertToASCII
    ld hl, $9867
    ld a, d
    ld [hli], a
    ld a, e
    ld [hl], a

    ;====================================================
    ; Fetch & Print expected value

    ; Fetch Expected Value from Result Table
    ld a, [wCountNOP]
    ld hl, Expected
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, [hl]
    push af       ; Preserve expected value for comparison

    ; Print value
    call ConvertToASCII
    ld hl, $98A7
    ld a, d
    ld [hli], a
    ld a, e
    ld [hl], a

    ;====================================================
    ; Compare values and print PASS/FAIL

    ; Pre-emptively load PASS String & initialize VRAM Bank 1 with pass palette
    ld a, 1
    ldh [rVBK], a
    inc a
    ld hl, $98E7
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld de, strPass

    ; Fetch expected value from stack & compare to RAM value
    pop bc
    ld a, [wReadSTAT]
    cp b
    jr z, .noFail

    ; If values don't match, load FAIL string & fail palette
    ld de, strFail
    ld a, 1
    ld hl, $98E7
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
.noFail

    ; Reset to VRAM Bank 0
    xor a
    ldh [rVBK], a

    ; Print to screen
    ld hl, $98E7
    call Strcpy

    ;====================================================
    ; Turn on LCD & interrupts and return to main loop
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    ei
    ld a, LCDCF_ON | LCDCF_BG8800 | LCDCF_BGON
    ldh [rLCDC], a
    jp Main.mainLoop


;----------------------------------------------------------------------------
; Called whenever a VBlank interrupt occurs. Handles all variable-updating
; and is in charge of starting tests if the START button is pressed.
;----------------------------------------------------------------------------
HandleVBlank::
    ;====================================================
    ; Check if test should be started
    ldh a, [hPressedKeys]
    and $08
    jp nz, RunTest

    ;====================================================
    ; Handle fresh D-Pad up/down inputs

    ; Check if D-Pad Up was just pressed
    ldh a, [hPressedKeys]
    and $40
    jr z, .noUpPressed

    ; Increment wCountNOP by 1, set to 1 if result is 0
    ld hl, wCountNOP
    inc [hl]
    jr nz, .noZeroIncNOP
    inc [hl]
.noZeroIncNOP

    ; Update Scroll Cooldown & Continue
    ld a, SCROLL_INIT_COOLDOWN
    ld [wJoypadScrollCooldown], a
    xor a
    ld [wJoypadCooldown], a
    jr .noDownHeld

.noUpPressed
    ; Check if D-Pad Down was just pressed
    ldh a, [hPressedKeys]
    and $80
    jr z, .noDownPressed

    ; Decrement wCountNOP by 1, set to $FF if result is 0
    ld hl, wCountNOP
    dec [hl]
    jr nz, .noZeroDecNOP
    dec [hl]
.noZeroDecNOP

    ; Update Scroll Cooldown & Continue
    ld a, SCROLL_INIT_COOLDOWN
    ld [wJoypadScrollCooldown], a
    xor a
    ld [wJoypadCooldown], a
    jr .noDownHeld

.noDownPressed
    ;====================================================
    ; Handle held D-Pad up/down inputs

    ; Check if D-Pad Up is held
    ldh a, [hHeldKeys]
    and $40
    jr z, .noUpHeld

    ; Check if scroll cooldown is over
    ld hl, wJoypadScrollCooldown
    dec [hl]
    jr nz, .noDownHeld

    ; Increment scroll cooldown & check value change cooldown
    inc [hl]
    ld a, [wJoypadCooldown]
    inc a
    ld [wJoypadCooldown], a
    cp SCROLL_ITER_COOLDOWN
    jr nz, .noDownHeld

    ; Reset value change cooldown & handle NOP count increment logic
    xor a
    ld [wJoypadCooldown], a
    ld hl, wCountNOP
    inc [hl]
    jr nz, .noUpHeld
    inc [hl]

.noUpHeld
    ; Check if D-Pad Down is held
    ldh a, [hHeldKeys]
    and $80
    jr z, .noDownHeld

    ; Check if scroll cooldown is over
    ld hl, wJoypadScrollCooldown
    dec [hl]
    jr nz, .noDownHeld

    ; Increment scroll cooldown & check value change cooldown
    inc [hl]
    ld a, [wJoypadCooldown]
    inc a
    ld [wJoypadCooldown], a
    cp SCROLL_ITER_COOLDOWN
    jr nz, .noDownHeld

    ; Reset value change cooldown & handle NOP count decrement logic
    xor a
    ld [wJoypadCooldown], a
    ld hl, wCountNOP
    dec [hl]
    jr nz, .noDownHeld
    dec [hl]

.noDownHeld
    ;====================================================
    ; Print new NOP Count to screen
    ld a, [wCountNOP]
    call ConvertToASCII
    ld hl, $9827
    ld a, d
    ld [hli], a
    ld a, e
    ld [hl], a

    reti



SECTION "Expected Results", ROM0
Expected::
; Scanline 0
db $FF       ; NOP 0 cannot be read => unknown

REPT 18      ; 18 M-cycles of mode 0 (First-scanline-after-LCD-on-quirk)
    db $80
ENDR
REPT 43      ; 43 M-cycles of drawing
    db $83
ENDR
REPT 51      ; 51 M-cycles of HBlank
    db $80
ENDR

; Scanline 1
REPT 20      ; 20 M-cycles of OAM-scan
    db $82
ENDR
REPT 43      ; 43 M-cycles of drawing
    db $83
ENDR
REPT 51      ; 51 M-cycles of HBlank
    db $80
ENDR

; Scanline 2
REPT 20      ; 20 M-cycles of OAM-scan
    db $82
ENDR
REPT 9       ; 43 M-cycles of drawing, but cannot test further than 9 M-cycles into scanline 2
    db $83
ENDR



SECTION "Strings", ROM0
strNOPs: db "NOPs: 01h", 0
strRead: db "Read: --h", 0
strExpected: db "Exp.: --h", 0
strPressStart: db "Press START to run", 0
strPass: db "PASS!", 0
strFail: db "FAIL!", 0



SECTION "CGB Palettes", ROM0
defaultPalette: dw $FFFF, $0000, $0000, $0000
errorPalette:   dw $FFFF, $001F, $001F, $001F
passPalette:    dw $FFFF, $03E0, $03E0, $03E0



SECTION "WRAM", WRAM0
wCountNOP: db
wReadSTAT: db
wJoypadScrollCooldown: db
wJoypadCooldown: db



SECTION "HRAM", HRAM
hHeldKeys:: db
hPressedKeys:: db