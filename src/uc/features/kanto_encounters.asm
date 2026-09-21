; Kanto Improvements module: its encounter table. Read by
; features/encounters.asm, which owns the format: map_id once, then its
; entries (method bits, species, chance out of 256) ended by a 0, then the
; next map. The Viridian Forest zone is a map of its own; its chances add up
; to 256, so every encounter in the maze comes from here. The Route 2 block
; does the same for the grass outside the maze.

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
    db UC_CAVE, CATERPIE, 64 ; 25%
    db UC_CAVE, WEEDLE, 64 ; 25%
    db UC_CAVE, METAPOD, 26 ; 10%
    db UC_CAVE, KAKUNA, 26 ; 10%
    db UC_CAVE, PIDGEY, 64 ; 25%
    db UC_CAVE, LEDYBA, 4 ; 1.5%
    db UC_CAVE, SPINARAK, 4 ; 1.5%
    db UC_CAVE, LEDIAN, 2 ; 0.75%
    db UC_CAVE, ARIADOS, 2 ; 0.75%
    db 0

    map_id ROUTE_2
    db UC_GRASS, PIDGEY, 64 ; 25%
    db UC_GRASS, RATTATA, 64; 25%
    db UC_GRASS, NIDORAN_M, 48 ; 18.75%
    db UC_GRASS, NIDORAN_F, 48 ; 18.75%
    db UC_GRASS, PIKACHU, 16 ; 6.25%
    db UC_GRASS, HOOTHOOT, 12 ; 4.5%
    db UC_GRASS, NOCTOWL, 4 ; 1.5%
    db 0

    db 0 ; End of table

UCKantoEncountersEnd::

ENDL
