; Requires: encounters
; Version Exclusives module: the encounter table that injects the five
; families missing from Crystal. Read by frameworks/encounters.asm, which
; owns the format: map_id and method bits once, then its entries (species,
; chance out of 256) ended by a 0, then the next block. A 0 group ends the table

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "frameworks/encounter_constants.asm"

SECTION "uc exclusives table", ROM0[$09D0]
LOAD "uc exclusives table wram", WRAMX[$D9D0], BANK[4] ; window 6

UCExclusivesTable::
    map_id ROUTE_42
    db UC_GRASS
    db MANKEY, 5 ; 2.0%
    db MAREEP, 5 ; 2.0%
    db 0

    map_id ROUTE_37
    db UC_GRASS
    db VULPIX, 5 ; 2.0%
    db 0

    map_id ROUTE_43
    db UC_GRASS
    db GIRAFARIG, 5 ; 2.0%
    db 0

    map_id ROUTE_44
    db UC_SUPER_ROD
    db REMORAID, 5 ; 2.0%
    db 0 ; End of ROUTE_44 entries

    db 0 ; End of table

UCExclusivesTableEnd::

ENDL
