; Encounter roller. A map with no wild table of its own gets nothing from the
; game: ChooseWildEncounter returns from the lookup and zeroes the staged
; species. This does the same job from a table -- one row per map with where
; to roll, a rate, a base level, a level mask and a placeholder species -- and
; queues the scripted battle the encounter override then picks the real
; species for. Tables per module, looked up by UCFindMap.
; Listed after the hijack's step half: both queue through UCRunScript, which
; keeps whatever is queued already, so an exit warp wins the same step.
; Unown: the battle loader rerolls an Unown's DVs until its letter is in an
; unlocked set, forever if no Ruins puzzle is solved (the game refuses the
; encounter instead, in the lookup we skip). So every queued battle unlocks
; all four sets and the frame half puts the saved byte back once the battle
; is over -- before any menu can save it.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/collision_constants.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "core/module_constants.asm"
INCLUDE "frameworks/roller_constants.asm"

DEF wPlayerTileCollision EQU $D4E4 ; bank 1, collision of the tile under the player
DEF wRepelEffect         EQU $DCA1 ; bank 1, steps of repel left, 0 = none
DEF Random               EQU $2F8C ; a = random byte, keeps hl and de
DEF hMapAnims            EQU $FFDE ; 0 from the start of the battle intro until after the battle
DEF wUnlockedUnowns      EQU $DEF3 ; bank 1, one bit per unlocked unown letter set, saved with the game
DEF UC_UNOWN_ALL_SETS    EQU $0F ; the four sets, every letter
DEF UC_UNLOCK_PENDING    EQU 7 ; bit of .unlocked: a restore is due
DEF UC_UNLOCK_SEEN       EQU 6 ; bit of .unlocked: the battle has started

SECTION "uc roller", ROM0[$0F30]
LOAD "uc roller wram", WRAMX[$DF30], BANK[4] ; window 10, first thing in it

UCRoller::
    db "UC" ; step code follows

.step
    ld hl, .tables ; Load address of the roller tables
    call UCFindMap ; c with hl = this map's row, if it is listed
    ret nc
    push hl ; The row, kept across the tile check
    ld a, [hl] ; Where the row rolls
    and a ; UC_ROLL_ANY
    jr nz, .onthistile ; rolls wherever we are
    ld hl, wPlayerTileCollision
    call UCPeekB1 ; Get the collision under the player
    cp COLL_TALL_GRASS
    jr z, .onthistile
    cp COLL_LONG_GRASS
    jr nz, .leave ; Anywhere else there is nothing to roll
.onthistile
    ld hl, wRepelEffect
    call UCPeekB1 ; Get the steps of repel left
    and a ; If a repel is running
    jr nz, .leave ; no encounter
    call Random ; Roll for an encounter
    pop hl ; The row
    inc hl ; Past the where byte
    cp [hl] ; Its rate, out of 256
    ret nc ; Missed
    inc hl
    ld d, [hl] ; d = the base level
    inc hl
    ld e, [hl] ; e = the level mask
    inc hl
    ld a, [hl] ; The placeholder species
    ld [.script + 1], a ; into the script
    call Random ; Roll for the level
    and e ; Keep the mask's bits
    add d ; on top of the base level
    ld [.script + 2], a ; into the script
    ld hl, wUnlockedUnowns
    call UCPeekB1 ; The sets unlocked so far
    set UC_UNLOCK_PENDING, a ; Flag it, the sets never use the top bits
    ld [.unlocked], a ; Kept until the battle is over
    ld a, UC_UNOWN_ALL_SETS
    call UCPokeB1 ; Every letter for this one battle, hl still on the byte
    ld hl, .script
    ld c, 6 ; Length of the encounter script
    jp UCRunScript ; Queue it, its ret returns for us

.leave
    pop hl ; Balance the row we kept
    ret

; a scripted wild battle, like the game's static encounters. the species and
; the level are filled in by .step; the override swaps the species from its
; own table, and the row's placeholder is what it leaves when nothing claims the roll
.script
    loadwildmon 0, 0
    startbattle
    reloadmapafterbattle
    end

; Module, then its table. 0 = always on
.tables
    db MOD_CUT
    dw UCCutRoller
    db TABLE_END

; frame half, listed in the frame table: puts the unown sets back after the battle
UCRollerFrame::
    db "UC" ; frame code follows

.frame
    ld a, [UCRoller.unlocked]
    and a ; Nothing pending
    ret z
    ld b, a
    ldh a, [hMapAnims]
    and a ; Off from the battle intro on
    jr nz, .overworld
    set UC_UNLOCK_SEEN, b ; The battle has started, restore once it is over
    ld a, b
    ld [UCRoller.unlocked], a
    ret
.overworld
    bit UC_UNLOCK_SEEN, b ; Still waiting for the battle to start
    ret z
    ld a, b
    and UC_UNOWN_ALL_SETS ; The sets as they were
    ld hl, wUnlockedUnowns
    call UCPokeB1
    xor a
    ld [UCRoller.unlocked], a ; Done
    ret

UCRoller.unlocked: db 0 ; The saved unown sets, with the pending and seen bits

UCRollerEnd::

ENDL
