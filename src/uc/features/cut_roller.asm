; Requires: roller
; Restore Cut Content module: its encounter roller table. Read by
; frameworks/roller.asm through UCFindMap, which owns the format: uc_roller rows
; (map_id, size, then where to roll, rate, base level, level mask, placeholder
; species), a 0 group ends the table. The Safari Zone's numbers are the ones
; its own hook used; the two hijacked maps' are provisional defaults.

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "frameworks/roller_constants.asm"

SECTION "uc cut roller", ROM0[$0FC0]
LOAD "uc cut roller wram", WRAMX[$DFC0], BANK[4] ; window 10, after the roller

UCCutRoller::
    uc_roller SAFARI_ZONE_BETA, UC_ROLL_GRASS, 25, 22, 7, NIDORAN_M
    uc_roller CELADON_POKECENTER_2F_BETA, UC_ROLL_GRASS, 25, 40, 7, AERODACTYL ; Mt. Silver Exterior "Farawy Island"
    uc_roller CINNABAR_POKECENTER_2F_BETA, UC_ROLL_ANY, 25, 40, 7, UNOWN ; Unused Cave (Mt. Silver "Interior")

    db 0 ; End of table

UCCutRollerEnd::

ENDL
