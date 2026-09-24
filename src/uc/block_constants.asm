; Map block tables, for the block override (features/blocks.asm).
; The game keeps the current map as one byte per block in wram0, with a
; 3-block border on every side, so cell (x, y) of a map w blocks wide is at
; wOverworldMapBlocks + (y + 3) * (w + 6) + x + 3. The macros do that sum
DEF wOverworldMapBlocks EQU $C800

; uc_map MAP: starts the map's entry, its width comes from map_constants.
; uc_map_end closes it. The size byte between them is for UCFindMap
DEF UC_MAP_N = 0
MACRO uc_map
    map_id \1
    DEF UC_MAP_WIDTH = \1_WIDTH
    DEF UC_MAP_N += 1
    db .ucmapend{d:UC_MAP_N} - .ucmapbody{d:UC_MAP_N}
.ucmapbody{d:UC_MAP_N}
ENDM

MACRO uc_map_end
    db 0
.ucmapend{d:UC_MAP_N}
ENDM

; uc_block x, y, block: put this block id at (x, y), counted in blocks from the top left
MACRO uc_block
    db HIGH(wOverworldMapBlocks + (\2 + 3) * (UC_MAP_WIDTH + 6) + \1 + 3)
    db LOW(wOverworldMapBlocks + (\2 + 3) * (UC_MAP_WIDTH + 6) + \1 + 3)
    db \3
ENDM
