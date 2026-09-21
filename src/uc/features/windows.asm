; Loads the runtime's other sram windows into wram bank 4, once per power-on.
; First in the step table, so every window is in place before the rest of the step runs.

INCLUDE "constants/hardware.inc"

DEF OpenSRAM        EQU $2FCB
DEF CloseSRAM       EQU $2FE1
DEF CopyBytes       EQU $3026 ; hl = source, de = destination, bc = length
DEF UC_WINDOWS_END  EQU $FF ; ends the window table, bank 0 is a real entry

SECTION "uc windows", ROM0[$0540]
LOAD "uc windows wram", WRAMX[$D540], BANK[4] ; window 1's free space

UCWindows::
    db "UC"
    jp .frame
    jp .step

.loaded: db 0 ; 1 once the windows are in bank 4, this power-on

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
    call CloseSRAM
    ld a, 1
    ld [.loaded], a
    ret

; sram bank, wram destination, length, sram source
; keep in step with UC_SLOT4_WINDOWS in tools/patcher.py
.windows
    db 1
    dw $D600, $C000 - $BE57, $BE57 ; window 2, bank 1 tail
    db 2
    dw $D800, $C000 - $BE30, $BE30 ; window 3, bank 2 tail
    db 3
    dw $DA00, $C000 - $BEEC, $BEEC ; window 4, bank 3 tail after the ram writer reservation
    db 0
    dw $DB20, $C000 - $BF12, $BF12 ; window 5, bank 0 tail
    db UC_WINDOWS_END

UCWindowsEnd::

ENDL
