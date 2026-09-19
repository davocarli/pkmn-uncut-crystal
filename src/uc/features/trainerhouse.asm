; This feature changes the default Trainer House trainer.
; The default trainer is set to me -- the developer of this SRAM hack.
; The feature will not overwrite any existing custom Trainer that may
; have been registered legitimately by connecting with others.
; TODO: As of 2026-09-19, this party is a placeholder and must be updated before release.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "constants/charmap.asm"
INCLUDE "constants/pokemon_constants.asm"
INCLUDE "constants/move_constants.asm"
INCLUDE "constants/trainer_constants.asm"
INCLUDE "constants/text_constants.asm"
INCLUDE "constants/battle_constants.asm"

DEF OpenSRAM                          EQU $2FCB
DEF CloseSRAM                          EQU $2FE1
DEF CopyBytes                          EQU $3026
DEF sMysteryGiftTrainerHouseFlag       EQU $ABFD

DEF wBattleMode                        EQU $D22D ; 0 = not in battle
DEF wOtherTrainerClass                 EQU $D22F ; Class of the other trainer in battle, bank 1
DEF wOtherTrainerID                    EQU $D231 ; ID of the other trainer in battle, bank 1
DEF wBattleResult                      EQU $D0EE ; Result of the battle, bank 1
DEF wEventDecoBed4                     EQU $DAC6 ; bit 7 = Pikachu Bed

SECTION "uc trainerhouse", ROM0[$0340]
LOAD "uc trainerhouse wram", WRAMX[$D340], BANK[4]

UCTrainerHouse::
    db $55, $43 ; "UC" signature, as bytes since the charmap is loaded
    jp .frame
    jp .step

.loaded: db 0 ; Indicates if we already loaded the trainer this run
.armed: db 0 ; Will be set to 1 when battling David

.frame
    ld hl, wBattleMode ; Address of battle mode
    call UCPeekB1 ; Get battle mode
    and a ; If not in battle
    jr z, .notinbattle ; Jump to not in battle
    ld hl, wOtherTrainerClass ; Address of opponent trainer class
    call UCPeekB1 ; Get trainer class
    cp CAL ; Compare with CAL class
    ret nz ; If not matching, return
    ld hl, wOtherTrainerID ; Address of opponent trainer ID
    call UCPeekB1 ; Get trainer ID
    cp CAL2 ; Compare with CAL2 (ID)
    ret nz ; If not matching, return
    ; Arm the feature
    ld a, 1
    ld [.armed], a
    ret

.notinbattle
    ld a, [.armed] ; Load the armed flag
    and a ; If not armed
    ret z
    xor a ; Otherwise, disarm
    ld [.armed], a ; Clear the armed flag
    ld hl, wBattleResult ; Address of battle result
    call UCPeekB1 ; Get battle result
    and ~BATTLERESULT_BITMASK ; Check against WIN result
    ret nz ; If not WIN, return
    ld hl, wEventDecoBed4
    call UCPeekB1 ; Get event deco bed
    set 7, a ; Set bit 7 (Pikachu Bed)
    jp UCPokeB1 ; Store value in B1

.step
    ld a, [.loaded]
    and a ;If non-zero
    ret nz
    xor a
    call OpenSRAM
    ld a, [sMysteryGiftTrainerHouseFlag]
    and a ; Is the Mystery Gift Trainer House flag set?
    jr nz, .done ; If flag is set, don't overwrite
    ld hl, .data ; Load address of default trainer data
    ld de, sMysteryGiftTrainerHouseFlag
    ld bc, .dataend - .data
    call CopyBytes
    ; Fall into .done

.done
    call CloseSRAM
    ld a, 1
    ld [.loaded], a
    ret

.data
    db 1                                                          ; sMysteryGiftTrainerHouseFlag
    db "David@", 0, 0, 0, 0, 0                                    ; sMysteryGiftPartnerName, 11 bytes
    db 1                                                          ; sMysteryGiftUnusedFlag
    db 80, TYPHLOSION, FLAMETHROWER, EARTHQUAKE,  THUNDERPUNCH, SWIFT
    db 80, CROBAT,     WING_ATTACK,  SLUDGE_BOMB, CONFUSE_RAY,  TOXIC
    db 80, SUICUNE,    SURF,         ICE_BEAM,    AURORA_BEAM,  REST
    db 80, ESPEON,     PSYCHIC_M,    BITE,        MORNING_SUN,  SWIFT
    db 80, TYRANITAR,  CRUNCH,       ROCK_SLIDE,  EARTHQUAKE,   FIRE_BLAST
    db 80, LANTURN,    THUNDERBOLT,  SURF,        THUNDER_WAVE, CONFUSE_RAY
    db -1                                                         ; end of party
.dataend

UCTrainerHouseEnd::

ENDL