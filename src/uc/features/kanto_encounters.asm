; Kanto Improvements module: its encounter table. Read by
; features/encounters.asm, which owns the format: map_id and method bits
; once, then its entries (species, chance out of 256) ended by a 0, then the
; next block. The Viridian Forest zone is a map of its own; its chances add up
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
    db UC_CAVE
    db CATERPIE, 64 ; 25%
    db WEEDLE, 64 ; 25%
    db METAPOD, 26 ; 10%
    db KAKUNA, 26 ; 10%
    db PIDGEY, 64 ; 25%
    db LEDYBA, 4 ; 1.5%
    db SPINARAK, 4 ; 1.5%
    db LEDIAN, 2 ; 0.75%
    db ARIADOS, 2 ; 0.75%
    db 0

    map_id ROUTE_2
    db UC_GRASS
    db PIDGEY, 64 ; 25%
    db RATTATA, 64; 25%
    db NIDORAN_M, 48 ; 18.75%
    db NIDORAN_F, 48 ; 18.75%
    db PIKACHU, 16 ; 6.25%
    db HOOTHOOT, 12 ; 4.5%
    db NOCTOWL, 4 ; 1.5%
    db 0

    db 0 ; End of table

UCKantoEncountersEnd::

ENDL
