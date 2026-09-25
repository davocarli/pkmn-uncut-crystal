; Requires: encounters. Its maps are only reached through the cut module's map hijack.
; 251 Edition module: its encounter table. Same format as the other encounter
; tables (frameworks/encounters.asm owns it): map_id and method bits once, then
; entries (species, chance out of 256) ended by a 0, then the next block.
; Listed after the cut table, so the walk arrives here with the roll already
; reduced by that block's 236: these three take the 20 it leaves.

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "frameworks/encounter_constants.asm"

SECTION "uc 251 encounters", ROM0[$0FE0]
LOAD "uc 251 encounters wram", WRAMX[$DFE0], BANK[4] ; window 10, after the cut roller

UC251Encounters::
    map_id CELADON_POKECENTER_2F_BETA ; Mt. Silver exterior
    db UC_GRASS
    db BULBASAUR, 6 ; 2.3%
    db CHARMANDER, 6 ; 2.3%
    db SQUIRTLE, 6 ; 2.3%
    db 0

    db 0 ; End of table

UC251EncountersEnd::

ENDL
