INCLUDE "constants/hardware.inc"

DEF OpenSRAM           EQU $2FCB
DEF CloseSRAM          EQU $2FE1
DEF _hl_               EQU $2FEC

SECTION "uc slot4", ROM0[$0200] ; Location of Slot 4 in uc

LOAD "uc slot4 wram", WRAMX[$D200], BANK[4] ; Run from location $D200 in WRAM bank 4

UCSlot4:: ; Start of Slot 4
    db "U4" ; Signature of Slot 4
    jp Frame4 ; Jump to per-frame handler
    jp Step4 ; Jump to per-step handler

Frame4: ; Contains code to run every frame
    ld hl, FrameFeatures ; Load the address of frame features table
    ld bc, 0 ; Set bc to 0 for calculating table offset
    jr RunFeatures ; Runs the features from the loaded table

Step4: ; Contains code to run every step
    ld hl, StepFeatures ; Load the address of step features table
    ld bc, 3 ; Set bc to 3 for calculating table offset
    ; falls naturally into RunFeatures

RunFeatures: ; Runs the features from the loaded table
.loop
    ld a, [hli] ; low byte
    ld e, a ; Store low byte in register e
    ld a, [hli] ; high byte
    ld d, a ; Store high byte in register d
    or e ; If 0 (end of table)
    ret z
    push hl ; The feature may modify hl, so we save it first
    push bc ; Save bc as the feature may modify it
    ld h, d ; set the high byte of hl to d
    ld l, e ; Set the low byte of hl to e
    ld a, [hli]
    cp 'U' ; Compare signature of feature
    jr nz, .next
    ld a, [hli]
    cp 'C'
    jr nz, .next ; If not "UC", skip -- not installed
    add hl, bc ; hl points to the feature's code
    call _hl_ ; Call the feature at the address now stored in hl
.next ; Label to continue to next feature in the table
    pop bc ; Restore the original bc value we pushed
    pop hl ; Restore the original hl value we pushed
    jr .loop ; Repeat the loop

FrameFeatures:
    dw UCTrainerHouse
    dw 0 ; End of frame features list

StepFeatures:
    dw UCGSBall
    dw UCTrainerHouse
    dw 0 ; End of step features list

UCSlot4End::

ENDL