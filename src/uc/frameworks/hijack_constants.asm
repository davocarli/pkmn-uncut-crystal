; Map-header hijack tables, for frameworks/maphijack.asm.
; The game copies a map's header into wram on every load; the hijack rewrites
; that copy so an unreachable host map shows a cut map's blocks instead.

; block data and attributes of the maps involved, from pokecrystal.sym
DEF BetaSilverCaveOutside_Blocks EQU $5A37 ; bank $2A, 20x18, johto tileset
DEF BetaUnionCave_Blocks         EQU $455F ; bank $2B, 10x9, cave tileset
DEF CeladonPokecenter2FBeta_MapAttributes  EQU $63C8 ; bank $25, kept as the host's own
DEF CinnabarPokecenter2FBeta_MapAttributes EQU $5D74 ; bank $25

DEF UC_HEADER_LEN EQU 10  ; tileset .. blocks pointer, the run replaced in the wram copy
DEF UC_ANY_X      EQU $FF ; uc_exit: any column on that row
DEF UC_EXITS_END  EQU $FF ; ends a map's exits

; uc_hijack HOST, TILESET, ENV, ATTRS, BORDER, WIDTH, HEIGHT, BLOCKS_BANK, BLOCKS, MUSIC
; starts a map's entry; uc_exit rows follow, then uc_exits_end closes it.
; The 10 header bytes are laid out as the game keeps them: height before width
DEF UC_HIJACK_N = 0
MACRO uc_hijack
    map_id \1
    DEF UC_HIJACK_N += 1
    db .uchijackend{d:UC_HIJACK_N} - .uchijackbody{d:UC_HIJACK_N} ; size, for UCFindMap
.uchijackbody{d:UC_HIJACK_N}
    db \2, \3
    dw \4
    db \5, \7, \6
    db \8
    dw \9
    db \<10>
ENDM

; uc_exit y, x, DEST, dx, dy: standing on (x, y) warps to DEST at (dx, dy). 8 bytes: the key, then a script
MACRO uc_exit
    db \1, \2
    warp \3, \4, \5
    end
ENDM

MACRO uc_exits_end
    db UC_EXITS_END
.uchijackend{d:UC_HIJACK_N}
ENDM
