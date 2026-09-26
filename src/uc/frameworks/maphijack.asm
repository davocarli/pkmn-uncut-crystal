; Map-header hijack. Every map load copies the map's header into wram: tileset,
; environment, size, where the blocks are, connections. On a host map listed in
; a table this rewrites that copy to a cut map's data and queues a reloadmap, so
; the game redraws from the new header. Only warp, door, connection and continue
; loads copy the header, so the patch survives battles and menus. Tables per
; module, looked up by UCFindMap: uc_hijack (host, size, header bytes, music),
; then uc_exit rows, uc_exits_end, then the next map; a 0 group ends the table.
; The step half warps out on an exit row.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "core/module_constants.asm"
INCLUDE "frameworks/hijack_constants.asm"

DEF hMapEntryMethod    EQU $FF9F ; non-zero from a warp being taken until the new map is ready
DEF wMapTileset        EQU $D199 ; bank 1, first of the 10 header bytes
DEF wMapBlocksPointer  EQU $D1A1 ; bank 1, 2 bytes, the last two of them
DEF wMapConnections    EQU $D1A8 ; bank 1, one bit per side
DEF wMapMusic          EQU $C2C0 ; wram0
DEF wMapTimeOfDay      EQU $C2D0 ; wram0, PALETTE_AUTO (0) follows the clock like an outdoor map
DEF wLandmarkSignTimer EQU $C2DA ; wram0, counts down while the host's name is on screen
DEF wYCoord            EQU $DCB7 ; bank 1
DEF wXCoord            EQU $DCB8 ; bank 1
DEF hROMBank           EQU $FF9D ; the rom bank the game has switched in
DEF Bankswitch         EQU $10 ; rst: switch to rom bank a
DEF GetMapScreenCoords EQU $486D ; bank $41: the screen's anchor in the block grid, from the player's coords and wMapWidth
DEF GetMapScreenCoords_BANK EQU $41
DEF LoadBlockData      EQU $24CD ; the block grid from the header
DEF BufferScreen       EQU $2879 ; saves the 6x5 blocks at the anchor; a reload pastes them back over the grid

SECTION "uc maphijack", ROM0[$0D49]
LOAD "uc maphijack wram", WRAMX[$DD49], BANK[4] ; window 8, after the injector

UCMapHijack::
    db "UC" ; frame code follows

.frame
    ; on a listed host with the header unpatched: patch it, then queue .reload
    call UCMapHijackFind ; Find the map in the hijack tables
    ret nc ; Return if not listed in the hijack
    ret z ; Return if the header is already hijacked
    ld de, wMapTileset ; de = the game's copy of the header
    ld b, UC_HEADER_LEN ; Load header length into register b
.copy
    ld a, [hli] ; Next byte of our entry
    push hl ; Save the entry cursor
    ld h, d ; Load high byte of map header address
    ld l, e ; Load low byte of map header address
    call UCPokeB1 ; Write it into the game's copy
    pop hl ; Restore the entry cursor
    inc de ; Move along the game's copy
    dec b ; Decrement the length counter
    jr nz, .copy ; Loop until all bytes have been copied
    push hl ; Save the entry cursor, now on the music byte
    xor a ; Zero, for the four writes below
    ld hl, wMapConnections ; Load map connections address
    call UCPokeB1 ; No neighbouring maps to walk into
    xor a ; Zero again, Poke leaves the bank number in a
    ld [wLandmarkSignTimer], a ; No sign with the host's name, wram0 so no Poke needed
    ld [wLandmarkSignTimer + 1], a ; Both bytes of the timer
    ld [wMapTimeOfDay], a ; PALETTE_AUTO, day and night like an outdoor map
    ; the reload pastes the screen window saved at the warp back over the grid, at an anchor worked out
    ; for the host's width: redo the anchor, the grid and the saved window for the new header first
    ldh a, [hROMBank]
    push af ; The rom bank the game had
    ld a, GetMapScreenCoords_BANK
    rst Bankswitch
    ld hl, GetMapScreenCoords
    ld b, 1
    call UCFarCall ; Anchor for the new width, with the game's wram bank mapped
    ld hl, LoadBlockData
    ld b, 1
    call UCFarCall ; The grid from the new header
    ld hl, BufferScreen
    ld b, 1
    call UCFarCall ; Save the window from it, so the paste is a no-op
    pop af
    rst Bankswitch ; Back to the game's rom bank
    pop hl ; Restore the entry cursor
    ld a, [hl] ; Load the music byte
    ld [wMapMusic], a ; Set the map music
    ld hl, .reload ; Load the address of the reload script
    ld c, 2 ; Length of the reload script
    jp UCRunScript ; Queue it, its ret returns for us

; what the game runs after a map's own script would: fade, copy the blocks and tileset again, fade in
.reload
    reloadmap
    end

; Module, then its table. 0 = always on
.tables
    db MOD_CUT
    dw UCCutMaps
    db TABLE_END

UCMapHijackFind::
    ldh a, [hMapEntryMethod] ; Load current map entry value
    and a ; Check if the map entry method is non-zero
    ret nz ; Return if non-zero
    ld hl, UCMapHijack.tables ; Load address of the hijack tables, under the other label
    call UCFindMap ; c with hl = this host's entry, if it is listed
    ret nc
    push hl ; The entry
    ld bc, 8 ; The blocks pointer's low byte, 9th of the header
    add hl, bc
    ld b, [hl] ; Ours
    ld hl, wMapBlocksPointer
    call UCPeekB1 ; The game's
    pop hl
    cp b ; z if the header is already ours
    scf ; Found
    ret

; step half, listed separately in the step table
UCMapHijackStep::
    db "UC" ; step code follows

.step
    call UCMapHijackFind ; Find map hijack
    ret nc ; Return if no map matches
    ret nz ; Return if the header is not ours yet, a warp now would fire on the host's own floor
    ld bc, UC_HEADER_LEN + 1 ; Skip past the header bytes
    add hl, bc ; Load address after header bytes
    push hl ; Save that address for later use
    ld hl, wYCoord ; Load address of the Y coordinate of the player
    call UCPeekB1 ; Peek the Y coordinate
    ld d, a ; d = the player's row
    inc hl ; Move to the x coordinate, the next byte
    call UCPeekB1 ; Peek the x coordinate
    ld e, a ; e = the player's column
    pop hl ; Restore the address from before the coordinate check
.exits
    ld a, [hli] ; Load value at current address into register a
    cp UC_EXITS_END ; Check if we've reached the end of the exits table
    ret z ; Return if we've reached the end of the table
    cp d ; Compare with y coordinate
    ld a, [hli] ; Get x coordinate
    jr nz, .skipexit ; Skip the exit if the row doesn't match, ld left the flags alone
    cp UC_ANY_X ; Check if the exit applies to any x coordinate
    jr z, .go ; Jump to warp handling if at an exit
    cp e ; Compare with x coordinate
    jr nz, .skipexit ; Skip the exit if the byte doesn't match
.go
    ld c, 6 ; Set the length of the warp script
    jp UCRunScript ; Run the warp script
.skipexit
    ld bc, 6 ; Skip past the current exit entry
    add hl, bc ; Move to the next exit entry
    jr .exits ; Continue checking the next exit entry

UCMapHijackEnd::

ENDL
