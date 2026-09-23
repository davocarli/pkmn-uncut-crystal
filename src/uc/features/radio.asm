; Plays the unused tracks on dead-air radio frequencies. The game's own
; NoRadioStation silences and clears the name box whenever the knob moves,
; so this only ever has to start a track, never stop one.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "constants/charmap.asm"
INCLUDE "constants/music_constants.asm"
INCLUDE "module_constants.asm"

DEF PlayMusic                  EQU $3B97 ; de = song id, saves/restores the rom bank itself
DEF wJumptableIndex            EQU $CF63 ; pokegear state, bank 0
DEF POKEGEARSTATE_RADIOJOYPAD  EQU $0C ; radio card open and taking input
DEF wPokegearRadioMusicPlaying EQU $C6DC ; bank 0, ENTER_MAP_MUSIC ($FF) = dead air, a song id = keep playing on exit
DEF wMapMusic                  EQU $C2C0 ; bank 0, the map's song, replayed on map change
DEF wRadioTuningKnob           EQU $D958 ; bank 1, even 0-80, shown as (knob + 2) / 4
DEF wTilemap                   EQU $C4A0 ; bank 0, 20 x 18 screen tiles
DEF UC_RADIO_NAME_COORD        EQU wTilemap + 9 * 20 + 2 ; where the game prints station names
DEF UC_RADIO_END               EQU $FF ; ends the station table

SECTION "uc radio", ROM0[$0720]
LOAD "uc radio wram", WRAMX[$D720], BANK[4] ; window 2

UCRadio::
    db $55, $43 ; "UC" signature, as bytes since the charmap is loaded. Frame code follows

.frame
    ld a, [wJumptableIndex] ; Load the current state of the pokegear
    cp POKEGEARSTATE_RADIOJOYPAD ; Compare to radio
    ret nz ; If not on radio, return early
    ld a, [wPokegearRadioMusicPlaying] ; Load exit code for current station
    cp ENTER_MAP_MUSIC ; Compare to dead air "music"
    ret nz ; If not dead air, return early

    ld hl, wRadioTuningKnob ; Load the address of the radio knob
    call UCPeekB1 ; Get value at that address
    ld b, a ; Store the knob value in register b
    ld hl, .stations ; Load the address of the station table into hl
.loop
    ld a, [hli] ; Load the next byte from the station table into a
    cp UC_RADIO_END ; Compare to end of station table
    ret z ; If end of table, return early
    cp b ; Compare the knob value to the table's station byte
    jr z, .stationfound ; If they match, jump to handler for station
    inc hl ; Skip byte for track and continue looping
.skipname
    ld a, [hli] ; Load the next byte from the station table
    cp '@' ; Compare to '@' which is marks the end of the station's name
    jr nz, .skipname ; If not the end, repeat skipname
    jr .loop
.stationfound
    ld d, 0 ; Write 0 to register d
    ld e, [hl] ; Load the track byte into register e
    inc hl ; [hli] only available with register a
    call PlayMusic ; Expects de to hold the track id
    ld a, e ; Load track byte into register a
    ld [wPokegearRadioMusicPlaying], a ; Load the track into playing state
    ld [wMapMusic], a ; Load the track into map music
    ld de, UC_RADIO_NAME_COORD ; Location of radio station name
.copyname
    ld a, [hli] ; Load next character of the station's name
    cp '@' ; Is character '@' which marks end of station's name?
    ret z ; If end of name, return early
    ld [de], a ; Store the character at the destination location
    inc de ; Increment the destination pointer
    jr .copyname ; loop for the next character, until early return

; knob value, track, name ended by "@"
.stations
    db 6, MUSIC_GS_OPENING, "GS Intro@"
    db 22, MUSIC_GS_OPENING_2, "GS Intro 2@"
    db 46, MUSIC_MOBILE_ADAPTER_MENU, "Mobile Menu@"
    db 60, MUSIC_MOBILE_ADAPTER, "Mobile Link@"
    db 74, MUSIC_MOBILE_CENTER, "Mobile Ctr@"
    db UC_RADIO_END

UCRadioEnd::

ENDL
