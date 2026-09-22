; Version Exclusives module: the encounter table that injects the five
; families missing from Crystal. Read by features/encounters.asm, which
; owns the format: map_id once, then its entries (method bits, species,
; chance out of 256) ended by a 0, then the next map. A 0 group ends the table

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "encounter_constants.asm"

SECTION "uc exclusives table", ROM0[$09D0]
LOAD "uc exclusives table wram", WRAMX[$D9D0], BANK[4] ; window 6

UCExclusivesTable::
    map_id ROUTE_42
    db UC_GRASS, MANKEY, 5 ; 2.0%
    db UC_GRASS, MAREEP, 5 ; 2.0%
    db 0

    map_id ROUTE_37
    db UC_GRASS, VULPIX, 5 ; 2.0%
    db 0

    map_id ROUTE_43
    db UC_GRASS, GIRAFARIG, 5 ; 2.0%
    db 0

    map_id ROUTE_44
    db UC_SUPER_ROD, REMORAID, 5 ; 2.0%
    db 0 ; End of ROUTE_44 entries

    db 0 ; End of table

UCExclusivesTableEnd::

ENDL
