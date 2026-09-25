; Requires: encounters, roller. The hijacked maps are reached through maphijack (cut_maps).
; Restore Cut Content module: its encounter table. Read by
; frameworks/encounters.asm, which owns the format: map_id and method bits
; once, then its entries (species, chance out of 256) ended by a 0, then the
; next block. These maps have no wild table: frameworks/roller.asm rolls the
; encounter and stages the row's placeholder species. A block may sum to less
; than 256 when another module's table continues the band on the same map --
; the picker carries the reduced roll on into it -- and whatever nobody claims
; is left as the placeholder. The Safari Zone has no 251 block, so it sums to
; 256; the two hijacked maps leave the last 20 to the starters.

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "frameworks/encounter_constants.asm"

SECTION "uc cut encounters", ROM0[$0A00]
LOAD "uc cut encounters wram", WRAMX[$DA00], BANK[4] ; window 4, first thing in it

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

    map_id CELADON_POKECENTER_2F_BETA ; Mt. Silver exterior, provisional
    db UC_GRASS
    db TANGELA, 60 ; 30%
    db LICKITUNG, 55 ; 22%
    db SCYTHER, 40 ; 16%
    db YANMA, 35 ; 12%
    db EXEGGUTOR, 25 ; 10%
    db AERODACTYL, 10 ; 6%
    db DITTO, 10 ; 4%
    db 0

    map_id CINNABAR_POKECENTER_2F_BETA ; the Unused Cave, provisional
    db UC_CAVE
    db DUNSPARCE, 192 ; 75%
    db DITTO, 52 ; 20%
    db UNOWN, 12 ; 4%
    db 0

    db 0 ; End of table

UCCutEncountersEnd::

ENDL
