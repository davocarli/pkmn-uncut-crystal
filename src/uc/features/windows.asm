; Loads the runtime's other sram windows into wram bank 4, once per power-on.
; First in the step table, so every window is in place before the rest of the step runs.

INCLUDE "constants/hardware.inc"

DEF OpenSRAM        EQU $2FCB
DEF CloseSRAM       EQU $2FE1
DEF CopyBytes       EQU $3026 ; hl = source, de = destination, bc = length
DEF UC_WINDOWS_END  EQU $FF ; ends the window table, bank 0 is a real entry

SECTION "uc windows", ROM0[$0520]
LOAD "uc windows wram", WRAMX[$D520], BANK[4] ; window 1, after the encounters

UCWindows::
    db "UC"
    jp .frame
    jp .step

.loaded: db 0 ; non-zero once the windows are in bank 4, this power-on

.frame
    ret

.step
    ld a, [.loaded]
    and a
    ret nz
    ld hl, .windows
.loop
    ld a, [hli] ; sram bank, or the end byte
    cp UC_WINDOWS_END
    jr z, .done
    call OpenSRAM
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a ; de = wram destination
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld b, a ; bc = length
    ld a, [hli]
    push hl ; table cursor, parked on the source's high byte
    ld h, [hl]
    ld l, a ; hl = sram source
    call CopyBytes
    pop hl
    inc hl ; past the source, on to the next window
    jr .loop
.done
    ld [.loaded], a ; a is still the end byte, non-zero
    jp CloseSRAM

; sram bank, wram destination, length, sram source. in bank 4 order
; keep in step with UC_SLOT4_WINDOWS in tools/patcher.py
; every row costs 7 bytes here and in the mail code: drop the ones still empty at release
.windows
    db 0
    dw $D108, $C000 - $BF12, $BF12 ; window 5, bank 0 tail, after the kernel
    db 1
    dw $D600, $C000 - $BE57, $BE57 ; window 2, bank 1 tail
    db 2
    dw $D800, $C000 - $BE30, $BE30 ; window 3, bank 2 tail
    db 0
    dw $D9D0, $AC60 - $AC30, $AC30 ; window 6, mystery gift padding
    db 3
    dw $DA00, $C000 - $BEEC, $BEEC ; window 4, bank 3 tail after the ram writer reservation
    db 1
    dw $DB14, $AD0D - $AB83, $AB83 ; window 7, save block padding
    db 0
    dw $DCA2, $BF0D - $BD83, $BD83 ; window 8, backup save block padding
    db 1
    dw $DE30, $B260 - $B160, $B160 ; window 9, active box padding
    db 0
    dw $DF30, $AE6B - $ADA4, $ADA4 ; window 10, slack after the core image
    db UC_WINDOWS_END

UCWindowsEnd::

ENDL
