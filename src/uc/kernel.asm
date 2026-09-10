; UCKernel, WRAM bank 4. UCLoader copies up to UCStage1End, UCInit copies the rest.
; UCFrame runs in the vblank interrupt: WRAM only, no SRAM, no HRAM.
; UCStep runs on the main thread once per step, interrupts off.
;
; image in sram bank 0 (see patcher):
;   stage 1, stubs (38), UCPokeB1 (12), rest of kernel

INCLUDE "constants/hardware.inc"

DEF CloseSRAM           EQU $2FE1
DEF CopyBytes           EQU $3026
DEF wUCLoaded           EQU $CFD8 ; wram0 flag, two bytes, set by UCInit when the kernel is up
DEF UC_LOADED_1         EQU $4B
DEF UC_LOADED_2         EQU $53
DEF UC_SIG_1          EQU $43 ; first two bytes of the image, "CK"
DEF UC_SIG_2          EQU $4B
DEF wGameLogicPaused    EQU $C2CD ; wram0, 1 while saving
DEF wSpecialPhoneCallID EQU $DC31 ; bank 1
DEF wUCParkedCall       EQU $DA0E ; bank 1, saved
DEF wScriptBank         EQU $D439 ; bank 1
DEF wScriptPos          EQU $D43A ; bank 1, 2 bytes little endian
DEF NURSE_CHECKPHONECALL_BANK EQU $2F  ; PokecenterNurseScript's checkphonecall (same in v1.0/v1.1)
DEF NURSE_CHECKPHONECALL_ADDR EQU $411F
DEF SPECIALCALL_ACE     EQU $9C
DEF SPECIALCALL_BIKESHOP EQU 6
DEF wStatusFlags2       EQU $D84D ; bank 1
DEF STATUSFLAGS2_BIKE_SHOP_CALL_F EQU 4
DEF wPlayerState        EQU $D95D ; bank 1
DEF PLAYER_BIKE         EQU 1
DEF wBikeStep           EQU $DCA2 ; bank 1, big endian
DEF GetMapPhoneService  EQU $2D05 ; a = 0 if the map has phone service
DEF UC_SLOT4          EQU $D200 ; bank 4: "U4", jp Frame4, jp Step4
DEF UC_SLOT4_FRAME    EQU $D202
DEF UC_SLOT4_STEP     EQU $D205
DEF UC_SLOT4_SIG_1  EQU $55 ; "U"
DEF UC_SLOT4_SIG_2  EQU $34 ; "4"
DEF UC_SLOT4_IMAGE    EQU $AE6B ; sram bank 0, to the end of the gap
DEF UC_SLOT4_LEN      EQU $B200 - UC_SLOT4_IMAGE
DEF UC_IMAGE_BASE       EQU $AC6B ; base address of the kernel image in SRAM bank 0

SECTION "uc kernel", ROM0[$0080]
LOAD "uc kernel wram", WRAMX[$D000], BANK[4]

; header. UCFrameStub and the loader jump to $D002 / $D005, don't move these
UCKernel::
    db UC_SIG_1, UC_SIG_2
    jp UCFrame
    jp UCStepEntry

wUCState:
    db 0

; stage 1 must hold everything the first pass needs: this, UCInit, nothing else
UCStepEntry::
    ld a, [wUCState]
    and a
    jp z, UCInit
    jp UCStep

; first UCStep after a reset. sram bank 0 still open
UCInit::
    ld hl, UC_IMAGE_BASE + (UCStage1End - UCKernel) + UCStubsEnd - UCFrameStub
    ld de, UCPokeB1
    ld bc, UCPokeB1End - UCPokeB1
    call CopyBytes
    ld de, UCStage1End
    ld bc, UCKernelEnd - UCStage1End
    call CopyBytes
    ; load slot 4
    ld hl, UC_SLOT4_IMAGE
    ld de, UC_SLOT4
    ld bc, UC_SLOT4_LEN
    call CopyBytes
    call CloseSRAM
    ld a, 1
    ld [wUCState], a
    ld hl, wUCLoaded
    ld [hl], UC_LOADED_1
    inc hl
    ld [hl], UC_LOADED_2
    and a ; clear carry to prevent call
    ret

UCStage1End::
; ---- part B, copied by UCInit
UCStep::
    ; call slot 4, if installed
    ld a, [UC_SLOT4]
    cp UC_SLOT4_SIG_1
    jr nz, .bikeshop ; skip to bike check if not installed
    ld a, [UC_SLOT4 + 1]
    cp UC_SLOT4_SIG_2
    call z, UC_SLOT4_STEP
.bikeshop:
    ld hl, wStatusFlags2
    call UCPeekB1
    bit STATUSFLAGS2_BIKE_SHOP_CALL_F, a
    ret z
    ; manually perform check for setting bike call, since
    ; rom will never overwrite non-zero special call from TimoVM
    ld hl, wPlayerState
    call UCPeekB1
    cp PLAYER_BIKE
    ret nz ; exit if not on bike
    ld hl, wBikeStep
    call UCPeekB1
    cp HIGH(1024)
    ret c
    ld hl, GetMapPhoneService
    ld b, 1
    call UCFarCall ; ROM call enabled by uc core
    and a
    ret nz
    ld hl, wSpecialPhoneCallID
    call UCPeekB1
    cp SPECIALCALL_ACE
    ret nz ; check to ensure TimoVM is current special call
    ld a, SPECIALCALL_BIKESHOP
    ld hl, wSpecialPhoneCallID
    call UCPokeB1
    ld hl, wStatusFlags2
    call UCPeekB1
    res STATUSFLAGS2_BIKE_SHOP_CALL_F, a
    jp UCPokeB1

UCFrame::
    ld a, [wUCState]
    and a
    ret z
    ; call slot 4, if installed
    ld a, [UC_SLOT4]
    cp UC_SLOT4_SIG_1
    jr nz, .paused
    ld a, [UC_SLOT4 + 1]
    cp UC_SLOT4_SIG_2
    call z, UC_SLOT4_FRAME
.paused:
    ld a, [wGameLogicPaused] ; to prevent saving queued special call
    and a
    jr z, .restore
    ; park the special phone call ID when game logic is paused
    ; this will ensure that if a story special call is queued and you
    ; save, it will not break the TimoVM setup.
    ld hl, wSpecialPhoneCallID
    call UCPeekB1
    and a
    ret z
    cp SPECIALCALL_ACE
    ret z
    
    ; store parked special phone call ID for later restore
    ld hl, wUCParkedCall
    call UCPokeB1
    ld a, SPECIALCALL_ACE
    ld hl, wSpecialPhoneCallID
    jp UCPokeB1

.restore:
    ; nurse pokerus msg check/fix
    ld hl, wScriptBank
    call UCPeekB1
    cp NURSE_CHECKPHONECALL_BANK
    jr nz, .parked
    ld hl, wScriptPos
    call UCPeekB1
    cp LOW(NURSE_CHECKPHONECALL_ADDR)
    jr nz, .parked
    inc hl
    call UCPeekB1
    cp HIGH(NURSE_CHECKPHONECALL_ADDR)
    jr nz, .parked
    ; hide special call from nurse
    ld hl, wSpecialPhoneCallID
    call UCPeekB1
    cp SPECIALCALL_ACE
    jr nz, .parked
    xor a
    call UCPokeB1
    .parked:
    ; not saving -- restore
    ld hl, wUCParkedCall
    call UCPeekB1
    and a
    ret z
    ld hl, wSpecialPhoneCallID
    call UCPokeB1
    xor a
    ld hl, wUCParkedCall
    jp UCPokeB1

UCKernelEnd::
ENDL
