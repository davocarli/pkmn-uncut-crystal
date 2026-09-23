; Safari Zone. The gate and the zone are complete maps in the rom, wired to
; Fuchsia City by warps, but the gate's door block is a wall and the zone has
; no wild table. The door and the zone's entrance come from the block
; override (cut_blocks.asm); this rolls the zone's encounters itself, and the
; species come from the cut encounter table.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/collision_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "module_constants.asm"

DEF hMapAnims            EQU $FFDE ; 0 outside the overworld
DEF wMapGroup            EQU $DCB5 ; bank 1
DEF wMapNumber           EQU $DCB6 ; bank 1
DEF wPlayerTileCollision EQU $D4E4 ; bank 1, collision of the tile under the player
DEF Random               EQU $2F8C ; a = random byte
DEF UC_SAFARI_RATE       EQU 25 ; encounter chance per grass step, out of 256
DEF UC_SAFARI_SPECIES    EQU NIDORAN_M ; placeholder, the cut table always replaces it
DEF UC_SAFARI_LEVEL      EQU 22 ; lowest level
DEF UC_SAFARI_LEVEL_MASK EQU 7 ; plus 0-7

SECTION "uc safari", ROM0[$0A70]
LOAD "uc safari wram", WRAMX[$DA70], BANK[4] ; window 4, after the starter roamer

UCSafari::
    db "UC" ; step code follows

.step
    ld hl, wMapGroup ; Load Map Group address
    call UCPeekB1 ; Get Map Group Value
    cp GROUP_SAFARI_ZONE_BETA ; Compare to Safari Zone Beta group
    ret nz ; Return early if not matching

    inc hl ; Move to next byte (Map Number)
    call UCPeekB1 ; Get Map Number
    cp MAP_SAFARI_ZONE_BETA ; Compare with Safari Zone Beta map number
    ret nz ; Return early if not matching

    ld hl, wPlayerTileCollision ; Load address of collision data
    call UCPeekB1 ; Get collision value
    cp COLL_TALL_GRASS ; Compare with tall grass
    jr z, .grass ; Skip to grass encounter code
    cp COLL_LONG_GRASS ; Compare with long grass
    ret nz ; Return early if not in grass, otherwise continue to grass encounter below
.grass
    call Random ; Generate a random byte for encounter check
    cp UC_SAFARI_RATE ; Compare with Safari Zone Encounter Rate
    ret nc ; Return if random byte is greater than or equal to encounter rate

    call Random ; Generate a random byte for encounter level
    and UC_SAFARI_LEVEL_MASK ; Mask the random byte to a value between 0 and 7
    add UC_SAFARI_LEVEL ; Add the base Safari Zone encounter level (22)
    ld [.script + 2], a ; Store the encounter level in the script
    ld hl, .script ; Load the address of the encounter script
    ld c, 6 ; Length of encounter script
    jp UCRunScript ; Run the encounter script

; a scripted wild battle, like the game's static encounters. the level byte is
; filled in by .step; the species is a placeholder the cut table replaces
.script
    loadwildmon UC_SAFARI_SPECIES, 0
    startbattle
    reloadmapafterbattle
    end

UCSafariEnd::

ENDL
