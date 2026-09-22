; Restore Cut Content module: the three Kanto birds roam. They use the game's
; roamer slots while UCRoam holds the Kanto set in them. A bird has no location
; of its own: on a fresh map change onto a route one of them may roll to be there.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "constants/landmark_constants.asm"

DEF Random               EQU $2F8C ; a = random byte
DEF wEnvironment         EQU $D19A ; bank 1, ROUTE / TOWN / CAVE ...
DEF wTempEnemyMonSpecies EQU $D204 ; bank 1, the last enemy's species, survives the battle
DEF wRoamMon1            EQU $DFCF ; bank 1, 3 x 7 bytes: species, level, group, map, hp, dvs
DEF UC_ROAM_STRUCT       EQU 7
DEF UC_BIRD_LEVEL        EQU 50
DEF UC_BIRD_MASK         EQU $1F ; 1 in 32 to be on the route just entered
DEF UC_ROAM_NOWHERE      EQU $FF ; group and map of a roamer that is nowhere

SECTION "uc kanto roamers", ROM0[$08E4]
LOAD "uc kanto roamers wram", WRAMX[$D8E4], BANK[4] ; window 3, after UCRoam

UCKantoRoamers::
    db "UC"
    jp .frame
    jp .step

.frame
    ret

.step
    ld a, [UCRoamRegion] ; Load the current region into register a
    and a ; If region is 0 (Johto)
    ret z ; return early
    ld hl, wRoamMon1 + 1 ; Level byte of the first slot
    ld de, .birds ; Load the Kanto birds into de
.release
    call UCPeekB1 ; Get the level of the current slot
    and a ; Check if the current roamer has been released (non-zero)
    jr nz, .keep ; If the current roamer has already been released, skip releasing it
    ld a, UC_BIRD_LEVEL
    call UCPokeB1 ; level
    dec hl
    ld a, [de]
    call UCPokeB1 ; species
    inc hl
.keep
    inc de ; Move to the next bird in the list
    ld bc, UC_ROAM_STRUCT ; Load the size of the roamer structure into BC for pointer arithmetic
    add hl, bc ; Move HL to the next roamer's data structure in WRAM
    ld a, e ; Load the low byte of the current bird's address
    cp LOW(.birds + 3) ; Compare with the low byte of the address after the last bird
    jr nz, .release ; If not at the end of the bird list, release the next bird
; flee: the last enemy was a bird that is still out, so it got away
    ld hl, wTempEnemyMonSpecies
    call UCPeekB1
    ld c, a ; c = last enemy species
    ld hl, wRoamMon1
    ld b, 3
.flee
    call UCPeekB1 ; species, 0 = caught or never out
    and a
    jr z, .fleenext
    cp c
    jr nz, .fleenext
    call .nowhere
    push hl
    ld hl, wTempEnemyMonSpecies
    xor a
    call UCPokeB1 ; once per battle
    pop hl
.fleenext
    ld de, UC_ROAM_STRUCT
    add hl, de
    dec b
    jr nz, .flee
; place: on a fresh map change onto a route one bird may be here, the rest go nowhere
    ld a, [UCRoamMapChanged]
    and a
    ret z ; same map
    ld b, 1 ; 1 = no bird may be placed
    dec a
    jr nz, .placeall ; back to the map just left
    ld hl, wEnvironment
    call UCPeekB1
    cp ROUTE
    jr nz, .placeall
    ld b, 0 ; a route: one may roll
.placeall
    ld hl, wRoamMon1
    ld c, 3
.place
    call UCPeekB1
    and a
    jr z, .placenext ; empty slot
    ld a, b
    and a
    jr nz, .away
    call Random
    and UC_BIRD_MASK
    jr nz, .away
    inc b ; one bird per route
    inc hl
    inc hl
    ld a, [UCRoamMap]
    call UCPokeB1 ; group
    inc hl
    ld a, [UCRoamMap + 1]
    call UCPokeB1 ; map
    dec hl
    dec hl
    dec hl
    jr .placenext
.away
    call .nowhere
.placenext
    ld de, UC_ROAM_STRUCT
    add hl, de
    dec c
    jr nz, .place
    ret

; hl = a slot's species byte: send it nowhere. keeps hl
.nowhere
    push hl
    inc hl
    inc hl
    ld a, UC_ROAM_NOWHERE
    call UCPokeB1 ; group
    inc hl
    ld a, UC_ROAM_NOWHERE
    call UCPokeB1 ; map
    pop hl
    ret

.birds
    db ARTICUNO, ZAPDOS, MOLTRES

UCKantoRoamersEnd::

ENDL
