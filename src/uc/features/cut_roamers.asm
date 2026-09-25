; Requires: none
; Restore Cut Content module: the three Kanto birds roam. The game's three
; roamer slots hold Raikou and Entei in Johto; in Kanto they hold the birds,
; and the set the player is not with waits in sram. One step feature: track
; the map and the region, swap the sets on a region change, release the birds
; on the first Kanto step, note a bird that fled, and on a fresh map change
; onto a route let one of them roll to be there. A bird has no location of its
; own. One file since 2026-09-25: the framework half (.track) and the birds
; were two images while the starter roamer shared the framework.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "constants/map_data_constants.asm"
INCLUDE "constants/landmark_constants.asm"

DEF GetWorldMapLocation  EQU $2CAF ; b = group, c = map, returns a = landmark
DEF OpenSRAM             EQU $2FCB ; a = bank
DEF CloseSRAM            EQU $2FE1
DEF Random               EQU $2F8C ; a = random byte
DEF wMapGroup            EQU $DCB5 ; bank 1
DEF wMapNumber           EQU $DCB6 ; bank 1
DEF wEnvironment         EQU $D19A ; bank 1, ROUTE / TOWN / CAVE ...
DEF wTempEnemyMonSpecies EQU $D204 ; bank 1, the last enemy's species, survives the battle
DEF wRoamMon1            EQU $DFCF ; bank 1, 3 x 7 bytes: species, level, group, map, hp, dvs
DEF UC_ROAM_STRUCT       EQU 7
DEF UC_ROAM_SETLEN       EQU 3 * UC_ROAM_STRUCT
DEF UCRoamSlotsRegion    EQU $DCAF ; bank 1, unused padding inside the save: which set the slots hold
DEF UC_ROAM_BANK         EQU 2 ; window 3 lives in sram bank 2
DEF UC_ROAM_SRAM         EQU $D800 - $BE30 ; subtract from a label here to get its sram address
DEF UC_BIRD_LEVEL        EQU 50
DEF UC_BIRD_MASK         EQU $1F ; 1 in 32 to be on the route just entered
DEF UC_ROAM_NOWHERE      EQU $FF ; group and map of a roamer that is nowhere

SECTION "uc kanto roamers", ROM0[$0800]
LOAD "uc kanto roamers wram", WRAMX[$D800], BANK[4] ; window 3, first thing in it

UCKantoRoamers::
    db "UC" ; step code follows

.step
    call .track ; Which map, which region; the sets swap on a region change
    ld a, [UCRoamRegion] ; Load the current region into register a
    and a ; If region is 0 (Johto)
    ret z ; return early
    ld hl, wRoamMon1 + 1 ; Level byte of the first slot
    ld de, .birds ; Load the Kanto birds into de
.release
    call UCPeekB1 ; Get the level of the current slot
    and a ; Check if the current roamer has been released (non-zero)
    jr nz, .keep ; If the current roamer has already been released, skip releasing it
    ld a, UC_BIRD_LEVEL
    call UCPokeB1 ; level
    dec hl
    ld a, [de]
    call UCPokeB1 ; species
    inc hl
.keep
    inc de ; Move to the next bird in the list
    ld bc, UC_ROAM_STRUCT ; Load the size of the roamer structure into BC for pointer arithmetic
    add hl, bc ; Move HL to the next roamer's data structure in WRAM
    ld a, e ; Load the low byte of the current bird's address
    cp LOW(.birds + 3) ; Compare with the low byte of the address after the last bird
    jr nz, .release ; If not at the end of the bird list, release the next bird
; flee: the last enemy was a bird that is still out, so it got away
    ld hl, wTempEnemyMonSpecies
    call UCPeekB1
    ld c, a ; c = last enemy species
    ld hl, wRoamMon1
    ld b, 3
.flee
    call UCPeekB1 ; species, 0 = caught or never out
    and a
    jr z, .fleenext
    cp c
    jr nz, .fleenext
    call .nowhere
    push hl
    ld hl, wTempEnemyMonSpecies
    xor a
    call UCPokeB1 ; once per battle
    pop hl
.fleenext
    ld de, UC_ROAM_STRUCT
    add hl, de
    dec b
    jr nz, .flee
; place: on a fresh map change onto a route one bird may be here, the rest go nowhere
    ld a, [UCRoamMapChanged]
    and a
    ret z ; same map
    ld b, 1 ; 1 = no bird may be placed
    dec a
    jr nz, .placeall ; back to the map just left
    ld hl, wEnvironment
    call UCPeekB1
    cp ROUTE
    jr nz, .placeall
    ld b, 0 ; a route: one may roll
.placeall
    ld hl, wRoamMon1
    ld c, 3
.place
    call UCPeekB1
    and a
    jr z, .placenext ; empty slot
    ld a, b
    and a
    jr nz, .away
    call Random
    and UC_BIRD_MASK
    jr nz, .away
    inc b ; one bird per route
    inc hl
    inc hl
    ld a, [UCRoamMap]
    call UCPokeB1 ; group
    inc hl
    ld a, [UCRoamMap + 1]
    call UCPokeB1 ; map
    dec hl
    dec hl
    dec hl
    jr .placenext
.away
    call .nowhere
.placenext
    ld de, UC_ROAM_STRUCT
    add hl, de
    dec c
    jr nz, .place
    ret

; hl = a slot's species byte: send it nowhere. keeps hl
.nowhere
    push hl
    inc hl
    inc hl
    ld a, UC_ROAM_NOWHERE
    call UCPokeB1 ; group
    inc hl
    ld a, UC_ROAM_NOWHERE
    call UCPokeB1 ; map
    pop hl
    ret

.birds
    db ARTICUNO, ZAPDOS, MOLTRES

; the map and the region. Sets UCRoamMapChanged for this step and, on a map change,
; UCRoamRegion; when the region differs from the set in the slots, swaps the sets
.track
    ld hl, wMapGroup ; Address of current map group
    call UCPeekB1 ; Get current map group
    ld d, a ; Load into register d
    inc hl ; Increment HL to point to map number
    call UCPeekB1 ; Get current map number
    ld e, a ; Load into register e
    ld a, [UCRoamMap] ; Load the last seen map group into register a
    cp d ; Compare with the current map group
    jr nz, .changed ; Jump to map-changed logic if different
    ld a, [UCRoamMap + 1] ; Load the last seen map number into register a
    cp e ; Compare with current map number
    jr nz, .changed ; Jump to map-changed logic if different
    xor a ; Clear a
    ld [UCRoamMapChanged], a ; Indicate no map change
    ret
.changed
    ld a, 1 ; Load 1 into register a
    ld [UCRoamMapChanged], a ; Store 1 to indicate map change
    ld a, [UCRoamPrevMap] ; Load the previous map group into register a
    cp d ; Compare with current map group
    jr nz, .shift ; Jump to shift logic if the previous map group differs from the current one
    ld a, [UCRoamPrevMap + 1] ; Load the previous map number into register a
    cp e ; Compare with current map number
    jr nz, .shift ; Jump to shift logic if the previous map number differs from the current one
    ld a, 2 ; Load 2 into register a to indicate back to previous map
    ld [UCRoamMapChanged], a
.shift
    ld a, [UCRoamMap] ; Load the last seen map group into registr a
    ld [UCRoamPrevMap], a ; Store the last seen map as the previous map group
    ld a, [UCRoamMap + 1] ; Load the last seen map number into register a
    ld [UCRoamPrevMap + 1], a ; Store it as the previous map number
    ld a, d ; Load the current map group into register a
    ld [UCRoamMap], a ; Store the current map group
    ld a, e ; Load the current map number into register a
    ld [UCRoamMap + 1], a ; Store the current map number
    ld b, d ; Copy the current map group into register b
    ld c, e ; Copy the current map number into register c
    call GetWorldMapLocation ; Expects map group/number in registers b & c. Writes landmark to a
    and a ; Check if the location is a special landmark
    ret z ; Return if the location is a special landmark
    ld e, JOHTO_REGION ; Load Johto region into register e
    cp KANTO_LANDMARK ; Compare with the Kanto landmark
    jr c, .region ; If before Kanto landmark, region is Johto
    cp LANDMARK_VICTORY_ROAD
    jr nc, .region ; If after (or is) victory road, region is also Johto
    ld e, KANTO_REGION ; Otherwise, it's Kanto, load into register e
.region
    ld a, e ; Retrieve region from register e
    ld [UCRoamRegion], a ; Write region to UCRoamRegion
    ld hl, UCRoamSlotsRegion ; Load the address of the slots region into hl
    call UCPeekB1 ; Get the value of the slots region from WRAM into register a
    ld b, a ; Store the slots region value in register b for comparison
    ld a, [UCRoamRegion] ; Load the current region into register a for comparison with the slots region
    cp b ; Compare the current region with the slots region
    ret z ; Return if the current region matches the slots region. No need to swap.
    ld a, UC_ROAM_BANK ; Load the SRAM bank for roaming data into register a
    call OpenSRAM ; Open the SRAM bank for roaming data
    ld a, b ; Load the region from register b into register a for setting the SRAM address
    call .setaddr ; Set DE to the SRAM address of the old region's roamer set
    ld hl, wRoamMon1 ; Load the address of the first roaming Pokémon into HL
    ld b, UC_ROAM_SETLEN ; Load the length of the roamer set into register b for the save loop
.save
    call UCPeekB1 ; Get the value of the current roamer from WRAM into register a
    ld [de], a ; Store the current roamer value into SRAM
    inc hl ; Move to the next byte in WRAM
    inc de ; Move to the next byte in SRAM
    dec b ; Decrement the counter for the number of bytes left to save
    jr nz, .save ; Repeat the save loop if there are more roamers to save
    ld a, [UCRoamRegion] ; Load value of current region into register a
    call .setaddr ; Set DE to the SRAM address of the current region's roamers
    ld hl, wRoamMon1 ; Load the address of the first roaming Pokémon into hl
    ld b, UC_ROAM_SETLEN ; Load the length of the roamer set into register b
.load ; Loads the roamers from SRAM into WRAM. Essentially sets those roamers as "active".
    ld a, [de] ; Load the current roamer value from SRAM into register a
    call UCPokeB1 ; Write the current roamer value to WRAM
    inc hl ; Move to the next byte in WRAM
    inc de ; Move to the next byte in SRAM
    dec b ; Decrement the counter for the number of bytes left to load
    jr nz, .load ; Repeat the load loop if there are more roamers to load
    call CloseSRAM ; Close SRAM, done writing
    ld a, [UCRoamRegion] ; Load the current region into register a for updating the slots region
    ld hl, UCRoamSlotsRegion ; Load the address of the slots region into HL for updating
    jp UCPokeB1 ; Write the current region to the slots region in WRAM. Nothing left to do.
; a = region, returns de = sram address of that region's set. sram bank 2 must be open
.setaddr
    and a ; Check if the region is Johto (0) or Kanto (1)
    ld de, .sets - UC_ROAM_SRAM ; Load Johto roamers SRAM address
    ret z ; Return if the region is Johto
    ld de, .sets + UC_ROAM_SETLEN - UC_ROAM_SRAM ; Load Kanto roamers SRAM address
    ret ; Return with DE pointing to the Kanto roamers SRAM address

; the two sets, johto then kanto. sram only: this wram copy is stale after the first write
.sets: ds 2 * UC_ROAM_SETLEN, 0

; state, read by the harness by name. exported labels go last: they end the local label scope
UCRoamMap:: db 0, 0 ; group, number seen on the last step
UCRoamPrevMap:: db 0, 0 ; the map before that
UCRoamRegion:: db 0 ; JOHTO_REGION or KANTO_REGION of the current map
UCRoamMapChanged:: db 0 ; on the step a map change was seen: 1 = new map, 2 = back to the previous map

UCKantoRoamersEnd::

ENDL
