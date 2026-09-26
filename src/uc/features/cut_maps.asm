; Requires: maphijack
; Restore Cut Content module: its map-header hijack table. Read by
; frameworks/maphijack.asm, which owns the format: uc_hijack, its uc_exit rows,
; uc_exits_end, then the next map; a 0 group ends the table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "constants/tileset_constants.asm"
INCLUDE "constants/music_constants.asm"
INCLUDE "frameworks/hijack_constants.asm"

SECTION "uc cut maps", ROM0[$0DF4]
LOAD "uc cut maps wram", WRAMX[$DDF4], BANK[4] ; window 8, after the hijack

UCCutMaps::
    ; Mt. Silver exterior on the Celadon beta floor: johto tileset, tree border, 20x18
    uc_hijack CELADON_POKECENTER_2F_BETA, TILESET_JOHTO, TOWN, CeladonPokecenter2FBeta_MapAttributes, $05, 20, 18, $2A, BetaSilverCaveOutside_Blocks, MUSIC_INDIGO_PLATEAU
    uc_exit 34, UC_ANY_X, CINNABAR_POKECENTER_1F, 6, 3 ; the bottom row, back below the sailor
    uc_exit 5, 20, CINNABAR_POKECENTER_2F_BETA, 3, 17 ; the cave tile, onto the cave's left mat
    uc_exits_end

    ; the Unused Cave on Cinnabar's
    uc_hijack CINNABAR_POKECENTER_2F_BETA, TILESET_CAVE, CAVE, CinnabarPokecenter2FBeta_MapAttributes, $09, 10, 9, $2B, BetaUnionCave_Blocks, MUSIC_UNION_CAVE
    uc_exit 17, UC_ANY_X, CELADON_POKECENTER_2F_BETA, 20, 6 ; The bottom goes back outside
    uc_exits_end

    db 0 ; End of table

UCCutMapsEnd::

ENDL
