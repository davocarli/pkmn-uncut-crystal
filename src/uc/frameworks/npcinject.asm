; NPC injection. When a map loads the game copies its object events into
; wMapObjects, 16 bytes each, and talking to one runs the script whose pointer
; sits in that record. This writes a whole record of its own: an empty slot
; becomes a new NPC, a used slot becomes a different one. The script is copied
; in parts into a buffer in the game's wram so it can read it, and a short
; spawn script is queued to put the object on the map. A sprite the map does not
; carry is added to the end of the game's list of loaded sprites, wUsedSprites,
; where appear looks its tiles up; the spawn script copies the tiles. One buffer,
; so one NPC per map. Tables per module, looked up by UCFindMap: uc_inject rows
; (map_id, size, slot, the record bytes, the script parts, the spawn script), a
; 0 group ends the table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "core/module_constants.asm"
INCLUDE "frameworks/inject_constants.asm"

DEF hMapEntryMethod    EQU $FF9F ; non-zero from a warp being taken until the new map is ready
DEF wUsedSprites       EQU $D154 ; bank 1: pairs of sprite id and first vram tile, entry 0 the player, id 0 ends the list
DEF LoadSpriteGFX      EQU $4306 ; bank 5: writes each entry's sprite type over its tile byte
DEF ArrangeUsedSprites EQU $4355 ; bank 5: turns the types back into tiles, packed in list order
DEF SPRITES_BANK       EQU $05
DEF Bankswitch         EQU $10 ; rst: switch to rom bank a. No need to switch back in frame code: the
                               ; vblank handler restores its own backup right after the dma hook returns

SECTION "uc npcinject", ROM0[$0CA2]
LOAD "uc npcinject wram", WRAMX[$DCA2], BANK[4] ; window 8, first thing in it

UCNpcInject::
    db "UC" ; frame code follows

.frame
    ldh a, [hMapEntryMethod] ; A warp is still on its way
    and a
    ret nz ; The records are not the new map's yet
    ld hl, .tables ; Load address of the inject tables
    call UCFindMap ; c with hl = this map's row, if it is listed
    ret nc
    ; the slot, 16 bytes each and under 16, so swap is the multiply
    ld a, [hli]
    swap a
    add LOW(wMapObjects)
    ld e, a
    ld a, HIGH(wMapObjects)
    adc 0 ; the carry out of the low byte
    ld d, a ; de = the record
    ; done for this map load only if the record is ours: a map load leaves an unused
    ; slot's pointer as it was and zeroes the sprite, so the pointer alone is not enough
    push hl ; Our place in the row
    ld hl, MAPOBJECT_SCRIPT_POINTER
    add hl, de ; hl = the record's script pointer
    call UCPeekB1 ; Low byte of the pointer the game holds
    cp LOW(UC_NPC_SCRIPT) ; Ours?
    pop hl ; pop leaves the flags alone
    jr nz, .write ; A fresh load: the game's own pointer
    push hl
    ld hl, MAPOBJECT_SPRITE
    add hl, de
    call UCPeekB1 ; The sprite the game holds
    pop hl
    cp [hl] ; The row's sprite, still there from the last write?
    ret z
.write
    ld a, [hl]
    ld c, a ; The row's sprite, kept for the list below; nothing up to there uses c
    inc de ; Byte 0 is the object struct id, never ours to write
    ld b, UC_RECORD_LEN
.record
    ld a, [hli] ; Next byte of the row
    push hl ; The row cursor
    ld h, d
    ld l, e
    call UCPokeB1 ; Into the record
    pop hl
    inc de ; Along the record
    dec b
    jr nz, .record
    ; the sprite onto wUsedSprites unless the map carries it already, so appear finds its tiles
    push hl ; Our place in the row
    ld hl, wUsedSprites + 2 ; Entry 0 is the player
.find
    call UCPeekB1 ; The sprite of the next entry
    and a
    jr z, .add ; The end of the list: ours goes here
    cp c
    jr z, .listed ; Loaded with the map, nothing to do
    inc hl
    inc hl
    jr .find
.add
    ld a, c
    call UCPokeB1 ; The sprite, over the terminating zero
    ld a, SPRITES_BANK
    rst Bankswitch
    ld hl, LoadSpriteGFX
    ld b, 1
    call UCFarCall ; Each entry's type over its tile byte, with the game's wram bank mapped
    ld hl, ArrangeUsedSprites
    ld b, 1
    call UCFarCall ; Tiles again, in list order: the old entries as they were, ours after them
.listed
    pop hl
    ld a, LOW(UC_NPC_SCRIPT)
    ld [.dst], a
    ld a, HIGH(UC_NPC_SCRIPT)
    ld [.dst + 1], a ; The parts fill the buffer from the top
.parts
    ld a, [hli] ; Length of the next part, 0 ends the list
    and a
    jr z, .spawn
    ld b, a
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a ; de = the fragment, bank 4
    push hl ; Our place in the row
    ld a, [.dst]
    ld l, a
    ld a, [.dst + 1]
    ld h, a ; hl = where this part goes
.copy
    ld a, [de] ; Next byte of the fragment
    inc de
    call UCPokeB1 ; Into the buffer the game can read
    inc hl
    dec b
    jr nz, .copy
    ld a, l
    ld [.dst], a
    ld a, h
    ld [.dst + 1], a ; Where the next part goes
    pop hl
    jr .parts
.spawn
    ld a, [hli] ; Length of the spawn script, 0 = nothing to queue
    and a
    ret z
    ld c, a
    jp UCRunScript ; Queue it, its ret returns for us

.dst: dw 0 ; Where the next part goes, carried across the parts loop

; Module, then its table. 0 = always on
.tables
    db MOD_CUT
    dw UCCutInjects
    db TABLE_END

UCNpcInjectEnd::

ENDL
