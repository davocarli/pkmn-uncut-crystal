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

DEF OpenSRAM                          EQU $2FCB
DEF CloseSRAM                          EQU $2FE1
DEF CopyBytes                          EQU $3026
DEF sMysteryGiftTrainerHouseFlag       EQU $ABFD

SECTION "uc trainerhouse", ROM0[$0340]
LOAD "uc trainerhouse wram", WRAMX[$D340], BANK[4]

UCTrainerHouse::
    db $55, $43 ; "UC" signature, as bytes since the charmap is loaded
    jp .frame
    jp .step

.loaded: db 0 ; Indicates if we already loaded the trainer this run

.frame
    ret

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