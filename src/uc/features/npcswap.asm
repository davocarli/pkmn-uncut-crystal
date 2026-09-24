; NPC script swap. When a map loads, the game copies its object events into
; wMapObjects, 16 bytes each, and talking to one runs the script whose pointer
; sits in that record. This points a chosen record at a script of ours, copied
; into the message buffer so the game can read it. One buffer, so one NPC per
; map. Tables per module, looked up by UCFindMap: uc_npc rows (map_id, size,
; the record's pointer address, the script and its length), a 0 group ends
; the table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "module_constants.asm"

DEF UC_MSG_SCRIPT  EQU $D280 ; bank 1, the runtime's script buffer (slot4.asm)

SECTION "uc npcswap", ROM0[$0CA2]
LOAD "uc npcswap wram", WRAMX[$DCA2], BANK[4] ; window 8, first thing in it

UCNpcSwap::
    db "UC" ; frame code follows

.frame
    ld hl, .tables ; Load address of the NPC tables
    call UCFindMap ; c with hl = this map's row, if it is listed
    ret nc
    ; found: address of the record's script pointer, then our script and its length
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld b, a ; bc = where the game keeps the pointer, bank 1
    push hl ; Keep our place in the record
    ld h, b
    ld l, c
    call UCPeekB1 ; Low byte of the pointer the game holds
    pop hl
    cp LOW(UC_MSG_SCRIPT) ; Already ours?
    ret z ; Already ours
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a ; de = our script, bank 4. The map matched, so d and e are free now
    ld a, [hl] ; Its length
    push bc ; The pointer address, needed after the copy
    ld b, a
    ld hl, UC_MSG_SCRIPT
.copy
    ld a, [de] ; Next byte of the script
    inc de
    call UCPokeB1 ; Into the buffer the game can read
    inc hl
    dec b
    jr nz, .copy
    pop hl ; hl = the pointer address
    ld a, LOW(UC_MSG_SCRIPT)
    call UCPokeB1 ; Point the record at the buffer, low byte
    inc hl
    ld a, HIGH(UC_MSG_SCRIPT)
    call UCPokeB1 ; then the high byte
    ret

; Module, then its table. 0 = always on
.tables
    db MOD_CUT
    dw UCCutNpcs
    db TABLE_END

UCNpcSwapEnd::

ENDL
