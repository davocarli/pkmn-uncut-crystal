; Kanto Improvements module: its encounter table. Read by
; features/encounters.asm, which owns the format: map_id, then method bits,
; species, chance out of 256. The Viridian Forest zone is a map of its own.
; The forest chances add up to 256, so every encounter there comes from this
; table. Levels are Route 2's, 3 to 7.
; TODO: placeholder species, the Red/Blue forest

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "zone_constants.asm"
INCLUDE "encounter_constants.asm"

SECTION "uc kanto encounters", ROM0[$06E0]
LOAD "uc kanto encounters wram", WRAMX[$D6E0], BANK[4]

UCKantoEncounters::
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, CATERPIE, 77 ; 30%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, WEEDLE, 77 ; 30%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, METAPOD, 51 ; 20%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, KAKUNA, 26 ; 10%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, PIKACHU, 13 ; 5%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, PIDGEY, 10 ; 4%
    db ZONE_GROUP, ZONE_VIRIDIAN_FOREST
    db UC_CAVE, PIDGEOTTO, 2 ; 1%
    db 0 ; End of table

UCKantoEncountersEnd::

ENDL
