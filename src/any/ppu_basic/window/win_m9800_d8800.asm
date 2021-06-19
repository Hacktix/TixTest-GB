; ===== Makefile Headers =====
; MBC 0x00
; RAM 0x00

INCLUDE "hardware.inc"

SECTION "Header", ROM0[0]
    ds $100 - @

SECTION "Test", ROM0[$100]
EntryPoint::
    jr Main

ds $150 - @

;----------------------------------------------------------------------------
; This Test ROM simply loads a few basic tiles and arranges them to display
; a smiley face. Palette initialization doesn't matter, the only thing being
; tested is the use of the correct tile data and tilemap memory regions.
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
    ld a, $FF
    ldh [rBCPD], a
    ldh [rBCPD], a
    xor a
    ldh [rBCPD], a
    ldh [rBCPD], a
    ldh [rBCPD], a
    ldh [rBCPD], a
    ldh [rBCPD], a
    ldh [rBCPD], a
    
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
    ; Load Tile Data into VRAM
    ld hl, TileData

    ; Load VRAM address into DE, check if end of data
.loadTileDataLoop
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    cp $FF
    jr z, .endLoadTileData

    ; Load tile data into VRAM
    ld a, [hli]
    ld b, $10
.tileLoadLoop
    ld [de], a
    inc de
    dec b
    jr nz, .tileLoadLoop
    jr .loadTileDataLoop
.endLoadTileData

    ;====================================================
    ; Load Tilemaps
    
    ; Good Tilemap for Window
    ld hl, TilemapGood
    ld de, $9800
    call LoadTilemap
    
    ; Bad Tilemap for Background
    ld hl, TilemapBad
    ld de, $9C00
    call LoadTilemap

    ;====================================================
    ; Initialize Window Registers
    ld a, 88
    ldh [rWY], a
    ld a, 7
    ldh [rWX], a

    ;====================================================
    ; Initialize LCDC and loop infinitely
    ld a, LCDCF_ON | LCDCF_BG8800 | LCDCF_BG9C00 | LCDCF_BGON | LCDCF_WIN9800 | LCDCF_WINON
    ldh [rLCDC], a
    jr @

;----------------------------------------------------------------------------
; Routine used to load tilemaps into VRAM. (See Tilemaps Section for format)
; Inputs:
;  * HL - Pointer to Tilemap Data
;  * DE - Pointer to VRAM
;----------------------------------------------------------------------------
LoadTilemap::
    ; Load Count into B, return if end of data
    ld a, [hli]
    ld b, a
    bit 7, a
    ret nz

    ; Load Tile ID into A and insert B times
    ld a, [hli]
.tilemapLoadLoop
    ld [de], a
    inc de
    dec b
    jr nz, .tilemapLoadLoop
    jr LoadTilemap

;----------------------------------------------------------------------------
; The following section contains tile data in the following format:
;  * [2 byte] VRAM Address
;  * [1 byte] Graphics Data, repeated for all 16 bytes in the tile data
;----------------------------------------------------------------------------
SECTION "Tile Data", ROM0
TileData::
    dw $8010
    db $FF
    dw $8020
    db $FF
    dw $9010
    db $FF
    dw $9030
    db $FF
    dw $FFFF

;----------------------------------------------------------------------------
; The following section contains tilemaps in the following format:
;  * [1 byte] Amount of tiles in succession
;             Bit 7 Set = End of Tilemap
;  * [1 byte] Tile ID to be inserted X times
;----------------------------------------------------------------------------
SECTION "Tilemap Data", ROM0
TilemapBad::
    db $40, $00
    db $08, $00, $04, $01, $14, $00
    db $06, $00, $02, $01, $04, $00, $02, $01, $12, $00
    db $05, $00, $01, $01, $08, $00, $01, $01, $11, $00
    db $04, $00, $01, $01, $03, $00, $01, $01, $02, $00, $01, $01, $03, $00, $01, $01, $10, $00
    db $04, $00, $01, $01, $03, $00, $01, $01, $02, $00, $01, $01, $03, $00, $01, $01, $10, $00
    db $03, $00, $01, $01, $0C, $00, $01, $01, $0F, $00
    db $03, $00, $01, $01, $0C, $00, $01, $01, $0F, $00
    db $03, $00, $01, $01, $0C, $00, $01, $01, $0F, $00
    db $03, $00, $01, $01, $0C, $00, $01, $01, $0F, $00
    db $04, $00, $01, $01, $02, $00, $06, $01, $02, $00, $01, $01, $10, $00
    db $04, $00, $01, $01, $01, $00, $01, $01, $06, $00, $01, $01, $01, $00, $01, $01, $10, $00
    db $05, $00, $01, $01, $08, $00, $01, $01, $11, $00
    db $06, $00, $02, $01, $04, $00, $02, $01, $12, $00
    db $08, $00, $04, $01, $14, $00
    db $80 ; End of Tilemap
    
TilemapGood::
    db $04, $00, $01, $01, $01, $00, $01, $01, $06, $02, $01, $01, $01, $00, $01, $01, $10, $00
    db $04, $00, $01, $01, $02, $00, $06, $03, $02, $00, $01, $01, $10, $00
    db $05, $00, $01, $01, $08, $00, $01, $01, $11, $00
    db $06, $00, $02, $01, $04, $00, $02, $01, $12, $00
    db $08, $00, $04, $01, $14, $00
    db $80 ; End of Tilemap