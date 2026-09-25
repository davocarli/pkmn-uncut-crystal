; Shelved 2026-09-25: the roaming Johto starter is replaced by NPC gifts to come.
; Outside the Makefile wildcard; slot 3 of the Johto roamer set is simply unused now.
; 251 Edition module: a Johto starter roams in slot 3. First the one weak
; against yours at level 5; once it is caught or beaten and the Elite Four are
; done, the one strong against yours at level 10. Slot 3's level is the state:
; 0 never released, 5 the weak one, 10 the strong one (the game keeps the level
; when it zeroes a caught roamer).

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "constants/landmark_constants.asm"

DEF wRoamMon3           EQU $DFDD ; bank 1: species, level, group, map, hp, dvs
DEF wStarterFlags       EQU $DA75 ; bank 1, wEventFlags + 3: bits 3/4/5 = got cyndaquil/totodile/chikorita from elm
DEF wEliteFourFlag      EQU $DA7A ; bank 1, wEventFlags + 8
DEF UC_ELITE_FOUR_BIT   EQU 4 ; EVENT_BEAT_ELITE_FOUR, set in the hall of fame
DEF UC_STARTER_WEAK     EQU 5 ; level of the first roamer
DEF UC_STARTER_STRONG   EQU 10 ; level of the second

SECTION "uc starter roamer", ROM0[$0A00]
LOAD "uc starter roamer wram", WRAMX[$DA00], BANK[4] ; window 4

UCStarterRoamer::
    db "UC" ; step code follows

.step
    ld a, [UCRoamRegion]
    and a
    ret nz ; kanto: slot 3 holds a bird
    ld hl, wRoamMon3 + 1
    call UCPeekB1 ; level = state
    and a
    jr z, .weak
    cp UC_STARTER_WEAK
    ret nz ; the strong one is out or done
    dec hl
    call UCPeekB1 ; species
    and a
    ret nz ; the weak one is still out
    ld hl, wEliteFourFlag
    call UCPeekB1
    bit UC_ELITE_FOUR_BIT, a
    ret z
    ld de, .strongmons
    ld c, UC_STARTER_STRONG
    jr .release
.weak
    ld de, .weakmons
    ld c, UC_STARTER_WEAK
.release
    ld hl, wStarterFlags
    call UCPeekB1
    rrca
    rrca
    rrca ; the three elm flags into bits 0-2, table order
    ld b, 3
.find
    rrca ; bit 0 into carry
    jr c, .found
    inc de
    dec b
    jr nz, .find
    ret ; no starter yet
.found
    ld a, [de]
    ld hl, wRoamMon3
    call UCPokeB1 ; species
    inc hl
    ld a, c
    call UCPokeB1 ; level
    inc hl
    ld a, GROUP_ROUTE_30
    call UCPokeB1
    inc hl
    ld a, MAP_ROUTE_30
    call UCPokeB1 ; starts on route 30, RoamMaps moves it from there
    inc hl
    xor a
    jp UCPokeB1 ; hp 0: the game rolls stats at the first battle

; by your starter: cyndaquil, totodile, chikorita
.weakmons
    db CHIKORITA, CYNDAQUIL, TOTODILE
.strongmons
    db TOTODILE, CHIKORITA, CYNDAQUIL

UCStarterRoamerEnd::

ENDL
