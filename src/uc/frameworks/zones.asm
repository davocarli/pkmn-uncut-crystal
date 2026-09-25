; "Zones" are rectangle coordinates that define specific areas
; on the map. They are used by other features to determine when
; the player enters or leaves those areas. For example, this is
; how we enable/disable "cave mode" as the player enters/exits
; the Viridian Forest.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "frameworks/zone_constants.asm"
INCLUDE "core/module_constants.asm"

DEF hMapAnims      EQU $FFDE ; Flag indicates whether map animations are enabled -- should always be true when the player is in the overworld
DEF wEnvironment   EQU $D19A ; Current Environment type, such as "cave"
DEF wMapGroup      EQU $DCB5 ; Current map group
DEF wMapNumber     EQU $DCB6 ; Current map number within the group
DEF wYCoord        EQU $DCB7 ; Current Y coordinate of the player
DEF wXCoord        EQU $DCB8 ; Current X coordinate of the player

SECTION "uc zones", ROM0[$0600]
LOAD "uc zones wram", WRAMX[$D600], BANK[4] ; Loading into unused space window 2

UCZones::
    db "UC" ; Signature of installed feature, the frame code follows

.frame
    ldh a, [hMapAnims] ; Load map animations flag address
    and a ; If: map animations disabled = not in overworld
    ret z ; Return early
    ld hl, wMapGroup ; Load map group address
    call UCPeekB1 ; Get map group
    ld d, a ; Store map group in d
    inc hl
    call UCPeekB1
    ld e, a ; Store map number in e
    ld hl, wYCoord ; Load Y coordinate address
    call UCPeekB1 ; Get player Y coordinate
    ld b, a ; save y coordinate to b
    inc hl
    call UCPeekB1
    ld c, a ; save x coordinate to c
    ld hl, .tables
.tableloop
    ld a, [hli] ; Module the table belongs to, 0 = always on
    cp TABLE_END ; If end of the list
    jr z, .none ; not in any zone
    and a
    jr z, .tableok
    push hl
    ld hl, UCModules
    and [hl] ; If the module is off
    pop hl
    jr z, .tableskip ; skip its table
.tableok
    ld a, [hli]
    push hl ; Remember where we are in the list
    ld h, [hl]
    ld l, a ; hl = the table

.loop
    ld a, [hl] ; Load Group
    and a ; If group == 0
    jr z, .tabledone ; end of this table
    push hl ; Save hl for re-use
    cp d ; Compare loaded group with current map group
    jr nz, .skip ; If the map group does not match, skip this zone
    inc hl
    ld a, [hl] ; Map number
    cp e ; Compare loaded map number with current map number
    jr nz, .skip ; If map number does not match, skip this zone

    ; Check if inside zone of map
    inc hl ; Increment hl to move to first coordinate
    ld a, c ; x
    cp [hl] ; If x < x1
    jr c, .skip ; Skip, not in zone
    inc hl ; move to y1
    ld a, b ; store y coordinate
    cp [hl] ; If y < y1
    jr c, .skip ; Skip, not in zone
    inc hl ; move to x2
    ld a, [hli] ; x2
    cp c ; If x > x2
    jr c, .skip ; Skip, not in zone
    ld a, [hli] ; y2
    cp b ; If y > y2
    jr c, .skip ; Skip, not in zone

    ; Player is inside the zone!!!
    ld a, [hli] ; Zone ID
    ld c, a
    ld a, [hl] ; Environment type to force
    ld b, a ; Save the environment to force in b
    pop hl ; Balance the push, the table is done with
    pop hl ; and the list
    ld a, [UCZoneCurrent]
    cp c ; If we were already inside this zone
    jr z, .force ; Skip to just keep the forced zone
    ld a, c
    ld [UCZoneCurrent], a ; Just entered a new zone
    ld a, b ; Check environment type
    and a ; If not forcing an environment (a == 0)
    ret z ; Return early
    ld hl, wEnvironment
    call UCPeekB1 ; Get current environment type
    ld [.saved], a ; Save the current environment type
    ld a, d
    ld [.savedmap], a
    ld a, e
    ld [.savedmap + 1], a ; Remember which map it belongs to
.force
    ld a, b
    and a ; Nothing to force
    ret z ; Return early
    ld hl, wEnvironment ; Environment to force
    jp UCPokeB1 ; Push the forced environment type

.skip
    pop hl ; Restore hl value
    ld a, l
    add ZONE_LEN
    ld l, a
    jr nc, .loop
    inc h
    jr .loop

.tabledone
    pop hl ; Back to the list
    inc hl
    jr .tableloop
.tableskip
    inc hl
    inc hl ; Past the address
    jr .tableloop

.none
    ld a, [UCZoneCurrent]
    and a ; If not inside a zone
    ret z ; Return early
    xor a
    ld [UCZoneCurrent], a ; Clear the current zone
    ld a, [.savedmap] ; Load map group
    and a ; If no environment type was forced to begin with
    ret z ; Return early
    cp d ; If we changed maps entirely
    jr nz, .clear ; The game should have already loaded the new environment type
    ld a, [.savedmap + 1] ; Load the saved map
    cp e ; Compare with the current map
    jr nz, .clear ; The game should have already loaded the new environment type
    ld a, [.saved] ; Load the saved environment type
    ld hl, wEnvironment ; Environment to restore
    call UCPokeB1 ; Write restored environment type

.clear ; Clear the saved map ; used when reverting or changing maps
    xor a
    ld [.savedmap], a ; Nothing forced
    ret

.saved: db 0 ; Original map environment
.savedmap: db 0, 0 ; Map group and number the saved environment belongs to. Group 0 = nothing forced

; Zone tables, one per module: module bit (0 = always on), table address.
; Each table is its own image, see features/*_zones.asm
.tables
    db MOD_KANTO
    dw UCKantoZones
    db TABLE_END

; Which zone the player is in, 0 if none. Read by other features
UCZoneCurrent:: db 0

UCZonesEnd::

ENDL
