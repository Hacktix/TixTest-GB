; ===== Makefile Headers =====
; MBC 0x00
; RAM 0x00

INCLUDE "hardware.inc"
INCLUDE "common.inc"
INCLUDE "oamdma.inc"

CD_CLOUDSCROLL  EQU 7
CD_HEATWAVE     EQU 15
CD_WATER1       EQU 15
CD_WATER2       EQU 7
CD_WATER3       EQU 3
CD_SUNLINE      EQU 7

LY_CLOUDSCROLL  EQU 7
LY_HEATWAVE     EQU 32
LY_HEATWAVE_END EQU 47
LY_WATER1       EQU 63
LY_WATER2       EQU 71
LY_WATER3       EQU 79
LY_GRASS        EQU 89

SECTION "Header", ROM0[0]
    ds $40 - @

VBlank::
    jp HandleVBlank
    ds $48 - @

STAT::
    jp HandleSTAT
    ds $100 - @

SECTION "Demo", ROM0[$100]
EntryPoint::
    jr Main

ds $150 - @

;----------------------------------------------------------------------------
; This ROM is an improved version of the scribbltests Fairylake ROM with
; reduced execution time of the STAT interrupt handler and a better
; development environment.
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
    ; Initialize important Variables

    ; Stack Pointer
    ld sp, $DFFF

    ; Palettes
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a
    ld a, %00000011
    ldh [rOBP1], a

    ; HRAM Variables
    xor a
    ld hl, _varInitZero
    ld b, _endVarInitZero - _varInitZero
.varInitZero
    ld [hli], a
    dec b
    jr nz, .varInitZero

    ; Initialize hSunlineAddVal to $FF
    dec a
    ldh [hSunlineAddVal], a

    ; PPU Registers
    ld a, LY_CLOUDSCROLL
    ldh [rLYC], a
    ld a, STATF_LYC
    ldh [rSTAT], a
    
    ;====================================================
    ; Initialize OAM DMA
    call InitOAMDMA
    
    ;====================================================
    ; Clear VRAM & OAM before anything

    ; Clear VRAM
    ld hl, $8000
    ld de, $2000
.vramClearLoop
    xor a
    ld [hli], a
    dec de
    ld a, d
    or e
    jr nz, .vramClearLoop

    ; Clear Shadow OAM & DMA to OAM
    ld hl, wShadowOAM
    ld b, 40*4
    xor a
.oamClearLoop
    ld [hli], a
    dec b
    jr nz, .oamClearLoop
    ld a, HIGH(wShadowOAM)
    call hOAMDMA

    ;====================================================
    ; Load background data into VRAM
    ld hl, $9000
    ld de, BGTiles
    ld bc, EndBGTiles - BGTiles
    call Memcpy

    ld hl, $9800
    ld de, BGMap
    ld bc, EndBGMap - BGMap
    call Memcpy
    
    ;====================================================
    ; Load sprite data into VRAM
    ld hl, $8000
    ld de, SpriteTiles
    ld bc, EndSpriteTiles - SpriteTiles
    call Memcpy
    
    ;====================================================
    ; Initialize Shadow OAM and DMA into OAM
    ld hl, wShadowOAM
    ld de, InitOAM
    ld bc, EndInitOAM - InitOAM
    call Memcpy
    ld a, HIGH(wShadowOAM)
    call hOAMDMA

    ;====================================================
    ; Initialize Interrupts
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK | IEF_LCDC
    ldh [rIE], a
    ei

    ;====================================================
    ; Initialize LCDC and restart PPU
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG8800 | LCDCF_BG9800 | LCDCF_OBJON
    ldh [rLCDC], a

    ;====================================================
    ; Loop indefinitely, waiting for interrupts
    ; & servicing them
.mainLoop
    halt 
    nop 
    jr .mainLoop


;----------------------------------------------------------------------------
; The following routine will be called to handle STAT interrupts. It loads
; an index from the hSTATRoutine variable and fetches the address of the
; routine at the corresponding index of the STAT jump table.
;----------------------------------------------------------------------------
HandleSTAT::
    ;====================================================
    ; Set DE = STATJumpTable + 2*hSTATRoutine
    ld de, STATJumpTable
    ldh a, [hSTATRoutine]
    add a
    add e
    ld e, a
    adc d
    sub e
    ld d, a

    ;====================================================
    ; Load function pointer into HL and jump
    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
    jp hl

STATJumpTable:
    dw HandleCloudScroll
    dw HandleHeatwave
    dw HandleWater1
    dw HandleWater2
    dw HandleWater3
    dw HandleGrass

;----------------------------------------------------------------------------
; STAT Interrupt handler for the cloud section of the frame
; Takes care of incrementing SCX every 7 frames for the cloud-layer
;----------------------------------------------------------------------------
HandleCloudScroll::
    ;====================================================
    ; Check if (hCloudScrollCooldown+1) & 7 == 0
    ldh a, [hCloudScrollCooldown]
    inc a
    and CD_CLOUDSCROLL
    ldh [hCloudScrollCooldown], a
    jr nz, .skipCloudScroll
    
    ;====================================================
    ; Update SCX HRAM Variable
    ldh a, [hCloudSCX]
    inc a
    ldh [hCloudSCX], a
.skipCloudScroll
    
    ;====================================================
    ; Wait for OAM Scan Mode
.waitOAM
    ldh a, [rSTAT]
    and 3
    cp 2
    jr nz, .waitOAM

    ;====================================================
    ; Set SCX to HRAM Variable
    ldh a, [hCloudSCX]
    ldh [rSCX], a

    ;====================================================
    ; Update LYC and hSTATRoutine
    ld a, LY_HEATWAVE
    ldh [rLYC], a
    ld a, 1
    ldh [hSTATRoutine], a
    reti

;----------------------------------------------------------------------------
; STAT Interrupt handler for the heatwaves section of the frame
; Resets SCX from the Cloud Layer, handles "heatwave" effect
;----------------------------------------------------------------------------
HandleHeatwave::
    ;====================================================
    ; Initialize Heatwaves Effect
    ld hl, HeatwaveEffectTable
    ldh a, [hHeatlineSCY]
    add l
    ld l, a

    ;====================================================
    ; Reset SCX
    xor a
    ldh [rSCX], a
    
    ;====================================================
    ; Wait for HBlank Mode
.waitHBL
    ldh a, [rSTAT]
    and 3
    jr nz, .waitHBL
    
    ;====================================================
    ; Additional Delay
    ld a, 6
.delayLoop
    dec a
    jr nz, .delayLoop
    
    ;====================================================
    ; Do Heatwave Effect
REPT 15
    ld a, [hli]
    ldh [rSCY], a
ENDR

    ;====================================================
    ; Check if heatwave section is done, update LYC
    ldh a, [rLY]
    cp LY_HEATWAVE_END
    jr z, .heatwaveEnd
    inc a
    ldh [rLYC], a
    reti

.heatwaveEnd
    ;====================================================
    ; Update variables for this & next STAT handler

    ; Reset SCY
    xor a
    ldh [rSCY], a

    ; Update hHeatlineSCY
    ldh a, [hHeatlineCooldown]
    inc a
    and CD_HEATWAVE
    ldh [hHeatlineCooldown], a
    jr nz, .skipHeatlineInc
    ldh a, [hHeatlineSCY]
    inc a
    and 3
    ldh [hHeatlineSCY], a
.skipHeatlineInc

    ; Update LYC and hSTATRoutine
    ld a, LY_WATER1
    ldh [rLYC], a
    ld a, 2
    ldh [hSTATRoutine], a
    reti

;----------------------------------------------------------------------------
; STAT Interrupt handler for the first water section of the frame
; Initializes BGP for the rest of the water section and adjusts SCX
;----------------------------------------------------------------------------
HandleWater1::
    ;====================================================
    ; Update HRAM Variables

    ; Check if cooldown is done
    ldh a, [hWater1Cooldown]
    inc a
    and CD_WATER1
    ldh [hWater1Cooldown], a
    jr nz, .skipWaterUpdate

    ; Update HRAM Variable
    ldh a, [hWater1SCX]
    inc a
    ldh [hWater1SCX], a
.skipWaterUpdate

    ;====================================================
    ; Wait for HBlank Mode
.waitHBL
    ldh a, [rSTAT]
    and 3
    jr nz, .waitHBL

    ;====================================================
    ; Update PPU Registers
    ld a, %11100001
    ldh [rBGP], a
    ldh a, [hWater1SCX]
    ldh [rSCX], a

    ;====================================================
    ; Update LYC and hSTATRoutine
    ld a, LY_WATER2
    ldh [rLYC], a
    ld a, 3
    ldh [hSTATRoutine], a
    reti

;----------------------------------------------------------------------------
; STAT Interrupt handler for the second water section of the frame
; Adjusts SCX for the second water section
;----------------------------------------------------------------------------
HandleWater2::
    ;====================================================
    ; Update HRAM Variables

    ; Check if cooldown is done
    ldh a, [hWater2Cooldown]
    inc a
    and CD_WATER2
    ldh [hWater2Cooldown], a
    jr nz, .skipWaterUpdate

    ; Update HRAM Variable
    ldh a, [hWater2SCX]
    inc a
    ldh [hWater2SCX], a
.skipWaterUpdate

    ;====================================================
    ; Wait for HBlank Mode
.waitHBL
    ldh a, [rSTAT]
    and 3
    jr nz, .waitHBL

    ;====================================================
    ; Update PPU Registers
    ldh a, [hWater2SCX]
    ldh [rSCX], a

    ;====================================================
    ; Update LYC and hSTATRoutine
    ld a, LY_WATER3
    ldh [rLYC], a
    ld a, 4
    ldh [hSTATRoutine], a
    reti

;----------------------------------------------------------------------------
; STAT Interrupt handler for the third water section of the frame
; Adjusts SCX for the third water section
;----------------------------------------------------------------------------
HandleWater3::
    ;====================================================
    ; Update HRAM Variables

    ; Check if cooldown is done
    ldh a, [hWater3Cooldown]
    inc a
    and CD_WATER3
    ldh [hWater3Cooldown], a
    jr nz, .skipWaterUpdate

    ; Update HRAM Variable
    ldh a, [hWater3SCX]
    inc a
    ldh [hWater3SCX], a
.skipWaterUpdate

    ;====================================================
    ; Wait for HBlank Mode
.waitHBL
    ldh a, [rSTAT]
    and 3
    jr nz, .waitHBL

    ;====================================================
    ; Update PPU Registers
    ldh a, [hWater3SCX]
    ldh [rSCX], a

    ;====================================================
    ; Update LYC and hSTATRoutine
    ld a, LY_GRASS
    ldh [rLYC], a
    ld a, 5
    ldh [hSTATRoutine], a
    reti

;----------------------------------------------------------------------------
; STAT Interrupt handler for the grass section of the frame
; Resets SCX to 0 and handles sprite logic
;----------------------------------------------------------------------------
HandleGrass::
    ;====================================================
    ; Wait for HBlank Mode
.waitHBL
    ldh a, [rSTAT]
    and 3
    jr nz, .waitHBL

    ;====================================================
    ; Update PPU Registers
    xor a
    ldh [rSCX], a

    ;====================================================
    ; Update Sunline Positions

    ; Check if cooldown is over
    ldh a, [hSunlineCooldown]
    inc a
    and CD_SUNLINE
    ldh [hSunlineCooldown], a
    jr nz, .skipSunlineUpdate

    ; Load value to add into B
    ldh a, [hSunlineAddVal]
    ld b, a

    ; Add value to Y-positions of sunline sprites
    ld c, 3
    ld hl, wShadowOAM
.sunlineOffsetLoop
    ld a, [hl]
    add b
    ld [hli], a
    inc hl
    inc hl
    inc hl
    dec c
    jr nz, .sunlineOffsetLoop

    ; Determine new value to add
    ld a, b
    dec a
    jr z, .sunlineAddFF
    ld a, 1
    jr .loadSunlineAdd
.sunlineAddFF
    dec a
.loadSunlineAdd
    ldh [hSunlineAddVal], a
.skipSunlineUpdate

    ;====================================================
    ; Update LYC and hSTATRoutine
    ld a, LY_CLOUDSCROLL
    ldh [rLYC], a
    xor a
    ldh [hSTATRoutine], a
    reti


    
;----------------------------------------------------------------------------
; The following routine will be called to handle VBlank Interrupts. It
; resets the state of all relevant variables to render the next frame.
;----------------------------------------------------------------------------
HandleVBlank::
    ;====================================================
    ; Reset BGP
    ld a, %11100100
    ldh [rBGP], a

    ;====================================================
    ; Run OAM DMA
    ld a, HIGH(wShadowOAM)
    call hOAMDMA

    reti



SECTION "HRAM", HRAM
_varInitZero::

; Index Variable for the STAT Jump Table
hSTATRoutine: db

; Cloud Layer Scrolling Variables
hCloudSCX: db
hCloudScrollCooldown: db

; Heatline Effect Variables
hHeatlineSCY: db
hHeatlineCooldown: db

; Water Layer Variables
hWater1SCX: db
hWater1Cooldown: db

hWater2SCX: db
hWater2Cooldown: db

hWater3SCX: db
hWater3Cooldown: db

; Sunline Variables
hSunlineAddVal: db
hSunlineCooldown: db

_endVarInitZero::



SECTION "GFX", ROM0

; Tile Data for Background Tiles
BGTiles::
    INCBIN "src/gb/demos/fairylake/gfx/bg.2bpp"
EndBGTiles::

; Tilemap for Background Tiles
BGMap::
    INCBIN "src/gb/demos/fairylake/gfx/bg.tilemap"
EndBGMap::

; Tile Data for Sprites
SpriteTiles::
    INCBIN "src/gb/demos/fairylake/gfx/sun.2bpp"
    INCBIN "src/gb/demos/fairylake/gfx/sunlines.2bpp"
EndSpriteTiles::

; Initial OAM State
InitOAM::
    ; Sunlines
    db $50, $54, $01, $90
    db $58, $54, $02, $90
    db $60, $54, $03, $90

    ; Sun Sprites
    db $48, $50, $00, $80
    db $48, $58, $00, $A0
EndInitOAM::



SECTION "Aligned Data", ROM0, ALIGN[8]
HeatwaveEffectTable::
    db 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1



SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM::
    ds 40*4