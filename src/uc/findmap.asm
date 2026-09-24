; Shared map lookup. A framework keeps its data as a list of module-tagged
; tables (db module, dw table, ended by TABLE_END); each table is a run of
; map entries: map_id, a size byte, then the body, ended by a 0 group. This
; finds the current map's entry, first match wins, so one entry per map.
; hl = the list. c with hl = the body if found, nc otherwise. Clobbers bc, de

INCLUDE "constants/hardware.inc"
INCLUDE "module_constants.asm"

DEF wMapGroup EQU $DCB5 ; bank 1, the map number follows it

SECTION "uc findmap", ROM0[$0AAD]
LOAD "uc findmap wram", WRAMX[$DAAD], BANK[4] ; window 4, after the safari zone

UCFindMap::
    push hl
    ld hl, wMapGroup
    call UCPeekB1
    ld d, a ; d = map group
    inc hl
    call UCPeekB1
    ld e, a ; e = map number
    pop hl
.list
    ld a, [hli] ; Module the table belongs to, 0 = always on
    cp TABLE_END
    ret z ; nc, cp leaves carry clear on a match
    and a
    jr z, .table
    push hl
    ld hl, UCModules
    and [hl] ; Zero if the module is off
    pop hl
    jr z, .skiptable
.table
    ld a, [hli]
    push hl ; The list position, for after this table
    ld h, [hl]
    ld l, a ; hl = the table
.maps
    ld a, [hli] ; Map group, 0 ends the table
    and a
    jr z, .tabledone
    cp d
    ld a, [hli] ; Map number, ld leaves the flags alone
    jr nz, .skipmap
    cp e
    jr nz, .skipmap
    pop de ; The list position, not needed: first match wins
    inc hl ; Past the size byte
    scf
    ret
.skipmap
    ld c, [hl] ; Size of the body
    ld b, 0
    inc hl
    add hl, bc
    jr .maps
.tabledone
    pop hl
    inc hl ; Past the table address
    jr .list
.skiptable
    inc hl
    inc hl ; Past the table address
    jr .list

UCFindMapEnd::

ENDL
