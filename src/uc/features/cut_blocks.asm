; Restore Cut Content module: its block table. Read by features/blocks.asm,
; which owns the format: uc_map, then uc_block x, y, id entries, uc_map_end,
; then the next map. Block ids are the map's own tileset's.

INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "block_constants.asm"

SECTION "uc cut blocks", ROM0[$0C10]
LOAD "uc cut blocks wram", WRAMX[$DC10], BANK[4] ; window 7, after the block override

UCCutBlocks::
    ; Safari Zone: the gate in Fuchsia is a wall, the zone's exit warps sit on plain floor
    uc_map FUCHSIA_CITY
    uc_block 9, 1, $3A ; kanto: the gate's wall with the door bottom left
    uc_map_end

    uc_map SAFARI_ZONE_BETA
    ; the entrance, laid out like the National Park's south gate: rails two
    ; blocks tall, the mats between them, the gate building's roof below. No
    ; park block has a rail beside a warp carpet, so the rails sit one tile
    ; out on their own blocks and the doorway is four tiles wide
    uc_block 3, 10, $16 ; rail on the block's right, up the path
    uc_block 4, 10, $01 ; floor between the rails (the rails were here, one tile in)
    uc_block 5, 10, $01
    uc_block 6, 10, $14 ; rail on the block's left
    uc_block 3, 11, $16 ; rails again beside the mats
    uc_block 4, 11, $0A ; park: gate doorway, warp carpet along the bottom
    uc_block 5, 11, $0A ; the second exit warp
    uc_block 6, 11, $14
    uc_block 3, 12, $28 ; roof, left to right; solid, so pressing down turns you and the mats' warp fires
    uc_block 4, 12, $29
    uc_block 5, 12, $29
    uc_block 6, 12, $2A
    uc_block 3, 13, $2C ; roof edge and brick wall
    uc_block 4, 13, $2D
    uc_block 5, 13, $2D
    uc_block 6, 13, $2E
    uc_map_end

    db 0 ; End of table

UCCutBlocksEnd::

ENDL
