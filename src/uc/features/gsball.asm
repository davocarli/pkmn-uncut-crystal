; This feature enables the GS Ball event after defeating the Elite 4.
; This is intended to mimic functionality from the VC Release.

INCLUDE "constants/hardware.inc"

DEF OpenSRAM           EQU $2FCB
DEF CloseSRAM          EQU $2FE1
DEF wHallOfFameCount   EQU $D95E
DEF sGSBallFlag        EQU $BE3C
DEF sGSBallFlagBackup  EQU $BE44 ; Backup Save GS Ball Flag
DEF GS_BALL_AVAILABLE  EQU $0B ; Value indicating truthy GS Ball

SECTION "uc gsball", ROM0[$0300]
LOAD "uc gsball wram", WRAMX[$D300], BANK[4] ; Run from location $D300 in WRAM bank 4

UCGSBall::
    db "UC" ; Signature to identify the feature is installed
    jp .frame
    jp .step

.loaded: db 0 ; Flag to indicate GS Ball flag has been processed on this load

.frame
    ; Frame-specific code can go here
    ret

.step
    ld a, [.loaded]
    and a ; If non-zero
    ret nz ; return

    ld hl, wHallOfFameCount
    call UCPeekB1 ; Loads data at address hl into a
    and a ; If zero
    ret z ;

    ld a, 1
    call OpenSRAM
    ld a, GS_BALL_AVAILABLE
    ld [sGSBallFlag], a ; Set the GS Ball flag in SRAM
    ld [sGSBallFlagBackup], a ; Backup the GS Ball flag in SRAM
    call CloseSRAM
    ld a, 1 ; Mark GS Ball as done
    ld [.loaded], a
    ret

UCGSBallEnd::

ENDL