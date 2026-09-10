; WRAM0 stubs. Copied to $CFDA by the loader after a reset.
; Only code we have in always-mapped memory, so all bank switching goes through here.

INCLUDE "constants/hardware.inc"

DEF TIMOVM_DISPATCHER EQU $DA3A
DEF UC_FRAME      EQU $D002
DEF UC_BANK       EQU 4
DEF _hl_              EQU $2FEC ; jp hl

SECTION "uc stubs", ROM0[$0000]
LOAD "uc stubs wram", WRAM0[$CFDA]

; called from the OAM DMA hook instead of the dispatcher, a = 0
UCFrameStub::
    call TIMOVM_DISPATCHER
    ld hl, UC_FRAME
    ld b, UC_BANK ; continues into UCFarCall

; call hl with WRAM bank b. restores the bank, returns a & flags. clobbers b & de
UCFarCall::
    ldh a, [rWBK]
    push af
    ld a, b
    ldh [rWBK], a
    call _hl_
    ld b, a
    pop de
    ld a, d
    ldh [rWBK], a
    ld a, b
    and a
    ret

; a = [hl] in bank 1. call from bank 4 only
UCPeekB1::
    ld a, 1
    ldh [rWBK], a
    ld a, [hl]
    push af
    ld a, 4
    ldh [rWBK], a
    pop af
    ret

UCStubsEnd::

ENDL

; [hl] = a in bank 1. call from bank 4 only. lives in the other WRAM0 gap, UCInit copies it
LOAD "uc pokeb1", WRAM0[$CD14]
UCPokeB1::
    push af
    ld a, 1
    ldh [rWBK], a
    pop af
    ld [hl], a
    ld a, 4
    ldh [rWBK], a
    ret

UCPokeB1End::

ENDL
