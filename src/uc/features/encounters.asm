; Encounter override. Once the game has picked a wild encounter, this feature
; gets a chance to swap the species for one from its own table.
; The game copies the species into wTempEnemyMonSpecies before the battle
; transition and only reads it back after, so the frame hook has ~60 frames
; to change it. The original level is kept.
; Entries match on the map and on how the encounter happened -- grass, cave,
; surf, one of the rods, headbutt -- then roll their own chance out of 256.
; Entries are checked in order and share one roll, so several on the same map
; take adjacent bands instead of competing for the same numbers.
; A table is a list of maps: map_id, then 3-byte entries (method, species,
; chance) ended by a 0 method, then the next map. A 0 group ends the table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "constants/text_constants.asm"
INCLUDE "constants/battle_constants.asm"
INCLUDE "constants/ram_constants.asm"
INCLUDE "zone_constants.asm"
INCLUDE "module_constants.asm"
INCLUDE "encounter_constants.asm"

DEF hMapAnims             EQU $FFDE ; 0 from the start of the battle intro until after the battle
DEF hRandomAdd            EQU $FFE1 ; Updated every frame by the game
DEF wEnvironment          EQU $D19A ; bank 1, CAVE and DUNGEON roll encounters anywhere
DEF wFishingRodUsed       EQU $D1EB ; bank 1, 0 = old, 1 = good, 2 = super
DEF wTempEnemyMonSpecies  EQU $D204 ; bank 1, what LoadEnemyMon reads
DEF wBattleMode           EQU $D22D ; bank 1, 0 until LoadEnemyMon runs
DEF wTempWildMonSpecies   EQU $D22E ; bank 1, the species the game rolled
DEF wOtherTrainerClass    EQU $D22F ; bank 1, 0 for wild battles
DEF wBattleType           EQU $D230 ; bank 1, 0 = BATTLETYPE_NORMAL
DEF wPlayerState          EQU $D95D ; bank 1, PLAYER_SURF while on the water
DEF wMapGroup             EQU $DCB5 ; bank 1
DEF wMapNumber            EQU $DCB6 ; bank 1


SECTION "uc encounters", ROM0[$0420]
LOAD "uc encounters wram", WRAMX[$D420], BANK[4]

UCEncounters::
    db "UC"
    jp .frame
    jp .step

.handled: db 0 ; Set once we've rolled for this battle
.roll: db 0 ; Random number rolled for this battle

.frame
    ldh a, [hMapAnims]
    and a ; If map animations are off
    jr z, .intro ; we may be in a battle intro
    xor a ; Otherwise we're in the overworld
    ld [.handled], a ; so re-arm for the next battle
    ret

.intro
    ld a, [.handled]
    and a ; If already rolled
    ret nz ; return
    ld hl, wBattleMode
    call UCPeekB1
    and a ; If the battle has started
    ret nz ; return, too late
    ld hl, wOtherTrainerClass
    call UCPeekB1
    and a ; If it's a trainer battle
    ret nz ; return
    ld hl, wTempWildMonSpecies
    call UCPeekB1
    and a ; If no wild species is staged
    ret z ; return
    ld a, 1
    ld [.handled], a ; One roll per battle, whatever happens below

    ; Work out how this encounter happened
    ld hl, wBattleType
    call UCPeekB1 ; Get battle type
    cp BATTLETYPE_FISH ; If fishing
    jr z, .fishing ; the rod says which method
    cp BATTLETYPE_TREE ; If headbutt
    jr z, .headbutt
    and a ; If it isn't an ordinary encounter (roamer, Celebi, contest)
    ret nz ; leave it alone
    ld hl, wPlayerState
    call UCPeekB1 ; Get player state
    and PLAYER_SURF | PLAYER_SURF_PIKA ; If on the water
    jr nz, .surfing
    ld hl, wEnvironment
    call UCPeekB1 ; Get map environment
    cp CAVE
    jr z, .incave
    cp DUNGEON
    jr z, .incave ; If neither, we're in grass
    ld c, UC_GRASS
    jr .classified

.incave
    ld c, UC_CAVE
    jr .classified

.surfing
    ld c, UC_SURF
    jr .classified

.headbutt
    ld c, UC_HEADBUTT
    jr .classified

.fishing
    ld hl, wFishingRodUsed
    call UCPeekB1 ; Get the rod we cast, 0 = old, 1 = good, 2 = super
    ld c, UC_OLD_ROD
.rodloop
    and a ; If that's the rod we're holding
    jr z, .classified
    sla c ; Otherwise step up to the next rod's bit
    dec a
    jr .rodloop

.classified
    ld hl, wMapGroup
    call UCPeekB1
    ld d, a ; d = map group
    inc hl
    call UCPeekB1
    ld e, a ; e = map number
    ld a, [UCZoneCurrent]
    and a ; If we're in a zone
    jr z, .nozone
    ld e, a ; its id is the map number
    ld d, ZONE_GROUP ; and the group says it's a zone
.nozone
    ldh a, [hRandomAdd]
    ld [.roll], a ; Store the random number for this battle
    ld hl, .tables
.tableloop
    ld a, [hli] ; Module the table belongs to, 0 = always on
    cp TABLE_END ; If end of the list
    ret z ; no match anywhere
    and a
    jr z, .tableok
    push hl
    ld hl, UCModules
    and [hl] ; If the module is off
    pop hl
    jr z, .tableskip ; skip its table
.tableok
    ld a, [hli]
    push hl ; Remember where we are in the list
    ld h, [hl]
    ld l, a ; hl = the table
.loop
    ld a, [hli] ; Load data at addr hl then increment
    and a ; If a == 0
    jr z, .tabledone ; End of the table
    ld b, a ; Save a for comparison
    ld a, [hli] ; Load and increment pointer again
    cp e ; Compare with current map number
    jr nz, .skipmap ; Skip to the next map if map doesn't match
    ld a, b ; Load current map group
    cp d ; Compare current map group
    jr nz, .skipmap ; Skip if map group doesn't match
.entries
    ld a, [hli] ; Load the encounter method
    and a ; If the encounter method is 0, end of entries for this map
    jr z, .loop ; Continue loop to next map's entries
    and c ; Is current encounter method included
    jr z, .skipentry ; Skip if encounter method doesn't match
    ld a, [hli] ; Load species for this encounter
    ld b, a ; Store in b
    ld a, [.roll] ; Get rolled number
    cp [hl] ; Compare with the roll chance for the encounter
    jr c, .swap ; Swap the encounter for this species
    sub [hl] ; Subtract the roll chance from the number
    ld [.roll], a ; Store the updated roll number
    inc hl ; Move to the next entry to compare new roll number
    jr .entries ; Continue loop for next entry
.skipentry
    inc hl ; Increment to rol chance
    inc hl ; Increment to next entry
    jr .entries ; Go back to loop to check next entry

.skipmap
    ld a, [hli] ; Load next piece of data
    and a ; Check if current map entry is 0 (end of list)
    jr z, .loop ; Jump to loop if end of map entry list
    inc hl ; Increment
    inc hl ; Move to the next map entry
    jr .skipmap ; Loop until we hit 0 (end of map) and run .loop

.tabledone
    pop hl ; Back to the list
    inc hl
    jr .tableloop
.tableskip
    inc hl
    inc hl ; Past the address
    jr .tableloop

.swap
    pop hl ; Pop to remove list position from stack
    ld a, b
    ld hl, wTempWildMonSpecies
    call UCPokeB1
    ld a, b
    ld hl, wTempEnemyMonSpecies
    call UCPokeB1
    ret

.step
    ret

; Encounter tables, one per module: module bit (0 = always on), table address.
; Each table is its own image, see features/*_table.asm and *_encounters.asm
.tables
    db MOD_EXCLUSIVES
    dw UCExclusivesTable
    db MOD_KANTO
    dw UCKantoEncounters
    db TABLE_END

UCEncountersEnd::

ENDL
