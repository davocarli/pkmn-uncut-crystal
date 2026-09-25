; UCLoader, 43 bytes at $DA47. TimoVM's reinstall calls this instead of CopyBytes,
; so we run once per step on the main thread with interrupts off and SRAM closed.
; entry: hl = $DA15, de = $C000, bc = 12 (his hook copy)

INCLUDE "constants/hardware.inc"

DEF OpenSRAM     EQU $2FCB
DEF CopyBytes    EQU $3026
DEF FarCopyWRAM  EQU $306B ; bc bytes hl -> de, bank a
DEF UC_STEP  EQU $D005
DEF UC_BANK  EQU 4
DEF START_WRAM   EQU $D000
DEF wUCLoaded   EQU $CFD8 ; wram0 flag, set by UCInit once the kernel is up
DEF UC_LOADED_1 EQU $4B
DEF UC_IMAGE_BASE   EQU $AC6B ; sram bank 0

SECTION "uc loader", ROM0[$0040]
LOAD "uc loader wram", WRAMX[$DA47], BANK[1]
UCLoader::
    call CopyBytes ; original TimoVM copy routine
    ld a, [wUCLoaded]
    cp UC_LOADED_1
    jr z, .kernelstep ; skip loading if the kernel is already installed

    ; Install the kernel
    xor a
    call OpenSRAM
    ld a, UC_BANK
    ld hl, UC_IMAGE_BASE
    ld de, START_WRAM
    ; b is still 0 from call to CopyBytes
    ld c, LOW(UCStage1End - UCKernel) ; must be < 256
    call FarCopyWRAM
    ld de, UCFrameStub
    ld c, LOW(UCStubsEnd - UCFrameStub)
    call CopyBytes

.kernelstep
    ld hl, UC_STEP
    ld b, UC_BANK
    jp UCFarCall

ENDL
