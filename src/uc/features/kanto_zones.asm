; Requires: zones
; Kanto Improvements module: its zones. Read by frameworks/zones.asm, which
; owns the format: map_id, x1, y1, x2, y2 (inclusive, in steps), zone id,
; environment to force while inside (0 = none)

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "frameworks/zone_constants.asm"

SECTION "uc kanto zones", ROM0[$06D0]
LOAD "uc kanto zones wram", WRAMX[$D6D0], BANK[4]

UCKantoZones::
    map_id ROUTE_2
    db 0, 12, 11, 27 ; The tree maze, the Viridian Forest remnant
    db ZONE_VIRIDIAN_FOREST, CAVE ; Cave mode: encounters on every tile
    db 0 ; End of table

UCKantoZonesEnd::

ENDL
