; Restore Cut Content module: its encounter table. Read by
; features/encounters.asm, which owns the format: map_id and method bits
; once, then its entries (species, chance out of 256) ended by a 0, then the
; next block. The Safari Zone has no wild table of its own: features/safari.asm
; stages a placeholder, so these chances add up to 256.

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "encounter_constants.asm"

SECTION "uc cut encounters", ROM0[$09A0]
LOAD "uc cut encounters wram", WRAMX[$D9A0], BANK[4] ; window 3, after the kanto roamers

UCCutEncounters::
    map_id SAFARI_ZONE_BETA
    db UC_CAVE
    db NIDORAN_M, 52 ; 20%
    db NIDORAN_F, 52 ; 20%
    db NIDORINO, 26; 10%
    db NIDORINA, 26 ; 10%
    db VENONAT, 52 ; 20%
    db PARAS, 26 ; 10%
    db PARASECT, 12 ; 5%
    db CHANSEY, 10 ; 4%
    db 0

    db 0 ; End of table

UCCutEncountersEnd::

ENDL
