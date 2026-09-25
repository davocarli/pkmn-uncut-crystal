INCLUDE "constants/hardware.inc"
INCLUDE "core/module_constants.asm"

DEF _hl_               EQU $2FEC

; For message display
DEF wMapReentryScriptQueueFlag    EQU $D45C ; 1 means a script is queued
DEF wMapReentryScriptBank         EQU $D45D ; Bank of queued script
DEF wMapReentryScriptAddress      EQU $D45E ; 2 bytes store address of queued script
DEF UC_MSG_SCRIPT                 EQU $D280 ; Address of msg script. Note that in-battle it's used for party count
DEF UC_MSG_TEXT                   EQU UC_MSG_SCRIPT + 7 ; Address of msg text

SECTION "uc slot4", ROM0[$0200] ; Location of Slot 4 in uc

LOAD "uc slot4 wram", WRAMX[$D200], BANK[4] ; Run from location $D200 in WRAM bank 4

UCSlot4:: ; Start of Slot 4
    db "U4" ; Signature of Slot 4
    jp Frame4 ; Jump to per-frame handler
    jp Step4 ; Jump to per-step handler

UCModules:: db 0 ; One bit per enabled module, set by each module's install code

Frame4: ; Contains code to run every frame
    ld hl, FrameFeatures ; Load the address of frame features table
    jr RunFeatures ; Runs the features from the loaded table

Step4: ; Contains code to run every step
    ld hl, StepFeatures ; Load the address of step features table
    ; falls naturally into RunFeatures

RunFeatures: ; Runs the features from the loaded table. A feature is "UC" then its code
.loop
    ld a, [hli] ; low byte
    ld e, a ; Store low byte in register e
    ld a, [hli] ; high byte
    ld d, a ; Store high byte in register d
    or e ; If 0 (end of table)
    ret z
    ld a, [hli] ; Module the feature belongs to, 0 = always on
    and a
    jr z, .run
    push hl
    ld hl, UCModules
    and [hl] ; If the module is off
    pop hl
    jr z, .loop ; skip the feature
.run
    push hl ; The feature may modify hl, so we save it first
    ld h, d ; set the high byte of hl to d
    ld l, e ; Set the low byte of hl to e
    ld a, [hli]
    cp 'U' ; Compare signature of feature
    jr nz, .next
    ld a, [hli]
    cp 'C'
    jr nz, .next ; If not "UC", skip -- not installed
    call _hl_ ; Call the feature's code, right after its signature
.next ; Label to continue to next feature in the table
    pop hl ; Restore the original hl value we pushed
    jr .loop ; Repeat the loop

UCShowMessage::
    ; queues a text box to appear. hl should point to message text in bank 4
    ; text ends with $57.
    ; Store message text address in de to free up hl
    ld d, h ; Store high byte of message text in d
    ld e, l ; Store low byte of message text in e
    ld hl, wMapReentryScriptQueueFlag
    call UCPeekB1 ; Check for queued script
    and a ; If already queued, skip showing message
    ret nz

    push de ; Save message text address
    ld de, .script
    ld bc, UC_MSG_SCRIPT

.copyscript
    ld a, [de] ; Load next byte of script
    inc de ; Increment de to point at next byte of script
    ld h, b
    ld l, c
    call UCPokeB1
    inc bc ; Increment bc to point to next byte of msg
    ld a, e
    cp LOW(.scriptend)
    jr nz, .copyscript
    pop de ; Restore message text address

.copytext
    ld a, [de] ; load next byte of text
    inc de ; Increment de to point at next byte of text
    cp $57 ; Indicates end of text
    ld h, b
    ld l, c
    call UCPokeB1
    inc bc ; Increment bc to point to next byte of msg
    jr nz, .copytext
    jp UCRunScript.queue

.script
    db $47             ; opentext
    db $4C, LOW(UC_MSG_TEXT), HIGH(UC_MSG_TEXT) ; writetext
    db $54             ; waitbutton
    db $49             ; closetext
    db $91             ; end
.scriptend

UCRunScript::
    ; Copies a script to $D280 and queues it to run.
    ; hl = address in bank 4, c = script length
    ; z is set when queued, nz if a script is already queued
    
    ; store hl in de and c in b for later use
    ld d, h
    ld e, l
    ld b, c

    ld hl, wMapReentryScriptQueueFlag
    call UCPeekB1 ; Check if a script is already queued
    and a
    ret nz ; return if a script is already queued
    ld hl, UC_MSG_SCRIPT
.copyscript
    ld a, [de] ; Load next byte of script
    inc de ; increment de to point at next byte of script
    call UCPokeB1 ; write byte of script to $D280
    inc hl ; increment hl to point at next byte of $D280
    dec b
    jr nz, .copyscript ; repeat until all bytes are copied
.queue
    ld a, 1
    ld hl, wMapReentryScriptBank
    call UCPokeB1
    ld a, LOW(UC_MSG_SCRIPT)
    ld hl, wMapReentryScriptAddress
    call UCPokeB1
    ld a, HIGH(UC_MSG_SCRIPT)
    inc hl
    call UCPokeB1

    ld a, 1
    ld hl, wMapReentryScriptQueueFlag
    call UCPokeB1
    xor a
    ret

; Feature address, then the module it belongs to (0 = always on).
; A feature with both hooks has a second signature for its other half (UCTrainerHouseStep)
FrameFeatures:
    dw UCTrainerHouse
    db 0
    dw UCZones
    db 0
    dw UCEncounters
    db 0
    dw UCRadio
    db MOD_CUT
    dw UCBlocks ; map block overrides, tables per module
    db 0
    dw UCNpcInject ; injected NPCs, tables per module
    db 0
    dw UCMapHijack ; map-header hijack, tables per module
    db 0
    dw UCRollerFrame ; puts the unown sets back after a rolled battle
    db 0
    dw 0 ; End of frame features list

StepFeatures:
    dw UCWindows ; first, so the other windows are loaded before anything reads them
    db 0
    dw UCKantoRoamers
    db MOD_CUT
    dw UCGSBall
    db 0
    dw UCTrainerHouseStep
    db 0
    dw UCMapHijackStep ; exits of hijacked maps
    db 0
    dw UCRoller ; battles on maps with no wild table, after the hijack so its exit warp queues first
    db 0
    dw 0 ; End of step features list

UCSlot4End::

ENDL