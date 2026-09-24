; Block override. The game keeps the current map as a grid of block ids in
; wram0 (wOverworldMapBlocks), copied from the rom on every map load and read
; back whenever the screen scrolls. This feature writes its own ids over
; chosen cells, so anything the map's tileset can already draw -- a door, a
; mat, a path -- can be put anywhere on it. Checked every frame: a cell that
; no longer holds our block means the game has just copied the grid again and
; drawn the screen from it, so after writing we draw it once more.
; Fresh maps sit at the top of the bg map with no scroll, still white from the
; fade: there we rebuild the tilemap with the game's own routine and push all
; of it to the bg map with the lcd off for a fraction of a frame. We are
; inside vblank here, or wait for the next one, the only safe place to
; switch the lcd off, and the screen is white anyway. No timing to get
; wrong, unlike writes with it on.
; Anywhere else (walking across a connection) we queue a refreshmap script,
; what a map script runs after changeblock, once map entry is over.
; A table is a list of maps: map_id, a size byte, then 3-byte entries (address
; high, low, block id) ended by a 0, then the next map. A 0 group ends the
; table. block_constants.asm has macros that work the address and size out;
; UCFindMap does the lookup, so one entry per map

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "module_constants.asm"

DEF hMapEntryMethod EQU $FF9F ; non-zero from a warp being taken until the new map is ready
DEF hSCX            EQU $FFCF
DEF hSCY            EQU $FFD0
DEF hMapAnims       EQU $FFDE ; 0 outside the overworld
DEF wBGMapAnchor    EQU $D152 ; bank 1, top left of the screen in the bg map
DEF LoadOverworldTilemapAndAttrmapPals EQU $2173 ; tilemap + attrmap from the grid, saves and restores the rom bank
DEF GetMovementPermissions EQU $2914 ; what the player can step onto, from the grid; refreshmap calls it too
DEF wTilemap        EQU $C4A0 ; wram0, 20x18 tile ids of the screen
DEF wAttrmap        EQU $CDD9 ; wram0, their attributes
DEF vBGMap0         EQU $9800 ; the bg map, 32 wide

SECTION "uc blocks", ROM0[$0B14]
LOAD "uc blocks wram", WRAMX[$DB14], BANK[4] ; window 7, first thing in it

UCBlocks::
    db "UC" ; frame code follows

.frame
    ld hl, .tables
    call UCFindMap ; c with hl = this map's cells, if it is listed
    jr nc, .done
.entries
    ld a, [hli] ; Address high byte
    and a ; If 0
    jr z, .done ; end of the map's cells
    ld b, a
    ld c, [hl] ; Address low byte
    inc hl
    ld a, [bc] ; What the grid holds
    cp [hl] ; Our block already?
    jr z, .next
    ld a, [hl]
    ld [bc], a ; Into the map grid
    ld a, 1
    ld [.pending], a ; The screen was drawn without it
.next
    inc hl ; Past the block
    jr .entries

.done
    ld a, [.pending]
    and a ; If nothing is owed
    ret z
    ; A fresh map is still fading in, at the top of the bg map with no scroll
    ldh a, [hMapAnims]
    and a
    jr nz, .live
    ld hl, wBGMapAnchor
    call UCPeekB1
    and a ; low byte
    jr nz, .live
    inc hl
    call UCPeekB1
    cp HIGH($9800) ; high byte, vBGMap0
    jr nz, .live
    ldh a, [hSCX]
    ld b, a
    ldh a, [hSCY]
    or b
    jr nz, .live
.vblank
    ldh a, [rLY]
    cp LY_VBLANK ; Still in vblank? The lcd may only go off there
    jr nc, .rebuild
.wait
    ; A busy vblank (sprites still loading after a warp) leaves us past its end
    ; every frame of the fade: wait for the next one. The screen is white and
    ; the game is only counting frames, so a stalled frame costs nothing
    ldh a, [rLY]
    cp LY_VBLANK
    jr nz, .wait
.rebuild
    ; Build the tilemap again from the grid and refresh what's under the player
    ld hl, LoadOverworldTilemapAndAttrmapPals
    ld b, 1 ; wram bank the routines expect
    call UCFarCall
    ld hl, GetMovementPermissions
    ld b, 1
    call UCFarCall
    ; Push it all with the lcd off
    ldh a, [rLCDC]
    push af
    and ~LCDC_ENABLE
    ldh [rLCDC], a
    ldh a, [rVBK]
    push af ; Whatever the game was using
    xor a
    ldh [rVBK], a
    ld de, wTilemap
    call .push
    ld a, 1
    ldh [rVBK], a
    ld de, wAttrmap
    call .push
    pop af
    ldh [rVBK], a
    pop af
    ldh [rLCDC], a ; Lcd back on, the frame starts over
    xor a
    ld [.pending], a
    ret

; the 20x18 map at de to the top of the bg map
.push
    ld hl, vBGMap0
    ld b, 18
.row
    ld c, 20
.tile
    ld a, [de]
    inc de
    ld [hli], a
    dec c
    jr nz, .tile
    ld a, l
    add 32 - 20 ; The rest of the bg map row
    ld l, a
    jr nc, .samepage
    inc h
.samepage
    dec b
    jr nz, .row
    ret

.live
    ; Scrolled somewhere: the game's own script, once map entry is over
    ldh a, [hMapEntryMethod]
    and a
    ret nz ; Still entering
    ldh a, [hMapAnims]
    and a
    ret z ; Not on the map
    ld hl, .script
    ld c, 2 ; Script length
    call UCRunScript ; z and a = 0 once queued
    ret nz ; Another script is queued, try again next frame
    ld [.pending], a
    ret

; what a map script runs after changeblock
.script
    refreshmap
    end

.pending: db 0 ; 1 while a redraw is owed

; Block tables, one per module: module bit (0 = always on), table address.
; Each table is its own image, see features/*_blocks.asm
.tables
    db MOD_CUT
    dw UCCutBlocks
    db TABLE_END

UCBlocksEnd::

ENDL
