; NPC injection. When a map loads the game copies its object events into
; wMapObjects, 16 bytes each, and talking to one runs the script whose pointer
; sits in that record. This writes a whole record of its own: an empty slot
; becomes a new NPC, a used slot becomes a different one. The script is copied
; in parts into a buffer in the game's wram so it can read it, and a short
; spawn script is queued to put the object on the map. One buffer, so one NPC
; per map. Tables per module, looked up by UCFindMap: uc_inject rows (map_id,
; size, slot, the record bytes, the script parts, the spawn script), a 0 group
; ends the table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "core/module_constants.asm"
INCLUDE "frameworks/inject_constants.asm"

DEF hMapEntryMethod EQU $FF9F ; non-zero from a warp being taken until the new map is ready

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
    push hl ; Our place in the row
    ld hl, MAPOBJECT_SCRIPT_POINTER
    add hl, de ; hl = the record's script pointer
    call UCPeekB1 ; Low byte of the pointer the game holds
    pop hl
    cp LOW(UC_NPC_SCRIPT) ; Already ours?
    ret z ; Done for this map load
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
