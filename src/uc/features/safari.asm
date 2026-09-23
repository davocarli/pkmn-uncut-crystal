; Safari Zone. The gate and the zone are complete maps in the rom, wired to
; Fuchsia City by warps, but the gate's door block is a wall and the zone has
; no wild table. Opens the door while in Fuchsia and rolls the zone's
; encounters itself; the species come from the cut encounter table.

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
DEF UC_FUCHSIA_DOOR      EQU $C874 ; wram0, Fuchsia block (9,1) in wOverworldMapBlocks: the gate's door
DEF UC_SAFARI_DOOR       EQU $3A ; kanto block, same wall with the door bottom left
DEF UC_SAFARI_EXIT       EQU $C8E7 ; wram0, zone blocks (4,11) and (5,11): under its exit warps, plain floor in the rom
DEF UC_SAFARI_EXIT_DOOR  EQU $0A ; park block, the gate doorway: warp carpet along the bottom
DEF UC_SAFARI_RATE       EQU 25 ; encounter chance per grass step, out of 256
DEF UC_SAFARI_SPECIES    EQU NIDORAN_M ; placeholder, the cut table always replaces it
DEF UC_SAFARI_LEVEL      EQU 22 ; lowest level
DEF UC_SAFARI_LEVEL_MASK EQU 7 ; plus 0-7

SECTION "uc safari", ROM0[$0A70]
LOAD "uc safari wram", WRAMX[$DA70], BANK[4] ; window 4, after the starter roamer

UCSafari::
    db "UC" ; frame code follows

.frame
    ldh a, [hMapAnims] ; Load the map animations flag
    and a ; If animations flag is 0, we are not in overwold
    ret z ; Return early
    
    ld hl, wMapGroup ; Load Map Group address
    call UCPeekB1 ; Get Map Group Value
    ld d, a ; Keep the group in d
    inc hl ; Move to next byte (Map Number)
    call UCPeekB1 ; Get Map Number
    ld e, a ; Keep the map number in e
    ld a, d
    cp GROUP_FUCHSIA_CITY ; Compare group with Fuchsia City
    jr nz, .zone ; Not Fuchsia's group, check the zone
    ld a, e
    cp MAP_FUCHSIA_CITY ; Compare with Fuchsia map number
    ret nz ; Return early if not matching

    ld a, UC_SAFARI_DOOR ; Load Safari Zone Door Block into register a
    ld [UC_FUCHSIA_DOOR], a ; Set Fuchsia City's door block to Safari Zone Door
    ret

.zone
    cp GROUP_SAFARI_ZONE_BETA ; a still holds the group, compare with the zone's
    ret nz ; Return early if not matching
    ld a, e
    cp MAP_SAFARI_ZONE_BETA ; Compare with the zone's map number
    ret nz ; Return early if not matching
    ld hl, UC_SAFARI_EXIT ; Address of the two blocks under the exit warps
    ld a, UC_SAFARI_EXIT_DOOR ; Gate doorway block, warp carpet along the bottom
    ld [hli], a ; First block, move to the next
    ld [hl], a ; Second block: the exit warps fire now
    ret

; step half, listed separately in the step table
UCSafariStep::
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
