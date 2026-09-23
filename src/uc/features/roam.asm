; Roaming framework. Johto and Kanto each get three roamers: the game's three
; slots hold the set for the region the player is in, the other set waits in
; sram. Runs on the step after a map change; the region units (kanto_roamers,
; starter_roamer) read the two exported bytes.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "constants/landmark_constants.asm"

DEF GetWorldMapLocation EQU $2CAF ; b = group, c = map, returns a = landmark
DEF OpenSRAM            EQU $2FCB ; a = bank
DEF CloseSRAM           EQU $2FE1
DEF wMapGroup           EQU $DCB5 ; bank 1
DEF wMapNumber          EQU $DCB6 ; bank 1
DEF wRoamMon1           EQU $DFCF ; bank 1, 3 x 7 bytes: species, level, group, map, hp, dvs
DEF UC_ROAM_SETLEN      EQU 3 * 7
DEF UCRoamSlotsRegion   EQU $DCAF ; bank 1, unused padding inside the save: which set the slots hold
DEF UC_ROAM_BANK        EQU 2 ; window 3 lives in sram bank 2
DEF UC_ROAM_SRAM        EQU $D800 - $BE30 ; subtract from a label here to get its sram address

SECTION "uc roam", ROM0[$0800]
LOAD "uc roam wram", WRAMX[$D800], BANK[4] ; window 3

UCRoam::
    db "UC" ; step code follows

.step
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

; read by the region units. exported labels go last: they end the local label scope
UCRoamMap:: db 0, 0 ; group, number seen on the last step
UCRoamPrevMap:: db 0, 0 ; the map before that
UCRoamRegion:: db 0 ; JOHTO_REGION or KANTO_REGION of the current map
UCRoamMapChanged:: db 0 ; on the step a map change was seen: 1 = new map, 2 = back to the previous map

UCRoamEnd::

ENDL
