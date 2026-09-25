; This feature replaces the EXIT option in the start menu with "UC OPTN",
; which opens a fullscreen settings menu styled after the OPTION menu.
; B still closes the start menu.
; The start menu reads its items from a table via a pointer in WRAM0, so
; we point it at our own copy of the table where EXIT is swapped for ours.
; Our copy (plus the settings menu) is staged at $D280 while not in battle.
; Each setting belongs to a feature. Rows for features that aren't installed
; are dropped when the menu is built, so the menu only shows what's there.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/coords.asm"
INCLUDE "macros/data.asm"
INCLUDE "constants/charmap.asm"
INCLUDE "constants/menu_constants.asm"
INCLUDE "macros/scripts/text.asm"
INCLUDE "macros/scripts/events.asm"

DEF wScriptVar                EQU $C2DD ; wram0, script return value
DEF wScriptBank               EQU $D439 ; bank 1
DEF wScriptPos                EQU $D43A ; bank 1
DEF wMenuCursorPosition       EQU $CF88 ; wram0, cursor byte of the loaded menu header
DEF START_MENU_BANK           EQU $25   ; StartMenuScript, inside its callasm
DEF START_MENU_POS            EQU $6B5C
DEF wMenuDataPointer          EQU $CF86 ; wram0
DEF wMenuDataBank             EQU $CF8A ; wram0
DEF START_MENU_DATA           EQU $66E3 ; StartMenu.MenuData, bank 4 of the ROM
DEF wMenuDataPointerTableAddr EQU $CF97 ; wram0, pointer to the start menu's item table
DEF wMenuItemsList            EQU $D03E ; bank 1. item count, then the ids
DEF wBattleMode               EQU $D22D ; bank 1
DEF wQueuedScriptBank         EQU $D0E8 ; bank 1
DEF wQueuedScriptAddr         EQU $D0E9
DEF wTilemap                  EQU $C4A0 ; wram0, 20 x 18
DEF vBGMap0                   EQU $9800 ; the start menu is anchored here, scroll 0
DEF UC_LABEL_COL              EQU 12
DEF UC_BLOB                   EQU $D280 ; wOTPartyCount, free outside battle
DEF UC_BLOB_CHUNK             EQU 20 ; 21 chunks = 420, the most that fits before $D42C

; Settings are bytes in the unused event flag range (1488-1599), so they get saved.
; One byte per setting, 0 = default
DEF UC_SET_B_TO_RUN  EQU $DB2C ; events 1488-1495
DEF UC_SET_FAST_TEXT EQU $DB2D ; events 1496-1503
DEF UC_SET_REPEL     EQU $DB2E ; events 1504-1511. 0 = no, 1 = ask, 2 = auto

; Menu rows are fixed size so the code can find them by index
DEF ITEM_LABEL   EQU 12 ; Label padded to this
DEF ITEM_VAL     EQU 20 ; Offset of the value within a row
DEF VAL_LEN      EQU 4  ; Values padded to this
DEF ITEM_LEN     EQU ITEM_VAL + VAL_LEN + 1
DEF DESC_LEN     EQU 8
DEF NUM_SETTINGS EQU 3

; Row: label, line feed, indent, colon, value, terminator
MACRO ucitem
    db \1
    ds ITEM_LABEL - STRLEN(\1), ' '
    db "<LF>      :"
    ds VAL_LEN, ' '
    db "@"
ENDM

; Setting: owning feature (0 = always shown), setting byte, value count, value strings
MACRO ucsetting
    dw \1, \2
    db \3
    dw \4
    db 0
ENDM

SECTION "uc options", ROM0[$0480]
LOAD "uc options wram", WRAMX[$D480], BANK[4] ; Run from location $D480 in WRAM bank 4

UCOptions::
    db $55, $43 ; "UC" signature, as bytes since the charmap is loaded
    jp .frame
    jp .step

.staged: db 0 ; Number of chunks copied to $D280 so far, +1 once scanned
.mask:   db 0 ; Bit n set if setting n's feature is installed

.frame
    ld hl, wBattleMode ; Address of battle mode
    call UCPeekB1 ; Get battle mode
    and a ; If not in battle
    jr z, .stage ; Jump to staging
    xor a ; Otherwise, battles clobber $D280
    ld [.staged], a ; so start over afterwards
    ret

.stage
    ld a, [UCWindow2Loaded] ; gone 2026-09-21: now UCWindows.loaded in core/windows.asm
    and a ; If the second window isn't loaded yet
    ret z ; return, the blob isn't in bank 4
    ld a, [.staged]
    cp (UCOptionsBlobEnd - UCOptionsBlob + UC_BLOB_CHUNK - 1) / UC_BLOB_CHUNK ; Total chunks
    jr c, .copychunk ; If chunks remain, copy the next one
    jr z, .scan ; If all chunks are staged, scan for installed features
    jr .menucheck ; Otherwise everything is ready, check the menu

.copychunk
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl ; hl = chunk * 4
    ld d, h
    ld e, l
    add hl, hl
    add hl, hl ; hl = chunk * 16
    add hl, de ; hl = chunk * 20
    push hl ; Save the offset
    ld de, UCOptionsBlob + $D000 ; Blob in bank 4
    add hl, de
    ld d, h
    ld e, l ; de = source
    pop hl
    ld bc, UC_BLOB
    add hl, bc ; hl = destination
    ld b, UC_BLOB_CHUNK ; Bytes to copy
.copy
    ld a, [de] ; Load next byte of the blob
    inc de
    call UCPokeB1 ; Write it to bank 1
    inc hl
    dec b
    jr nz, .copy ; Repeat until the chunk is done
    ld hl, .staged
    inc [hl] ; Count the chunk
    ret

.scan
    ; Check each setting's feature for the "UC" signature and build a bitmask.
    ; Reads the bank 4 copy of the blob, since bank 1 isn't visible here
    ld hl, UCOptionsTable.settings + UCOptionsBlob + $D000 - UC_BLOB
    ld b, NUM_SETTINGS
    ld c, 0 ; The mask
.scanloop
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a ; de = feature address
    push hl
    or e ; If 0
    jr z, .installed ; always show it
    ld a, [de]
    cp $55 ; "U"
    jr nz, .notinstalled
    inc de
    ld a, [de]
    cp $43 ; "C"
    jr nz, .notinstalled
.installed
    scf ; Carry = installed
    jr .scanbit
.notinstalled
    and a ; Clear carry
.scanbit
    rr c ; Shift it into the mask from the top
    pop hl
    ld de, DESC_LEN - 2
    add hl, de ; Next setting
    dec b
    jr nz, .scanloop
    REPT 8 - NUM_SETTINGS
    srl c ; Bring setting 0 down to bit 0
    ENDR
    ld a, c
    ld [.mask], a
    ld hl, UCOptionsTable.installed
    call UCPokeB1 ; The blob needs it to build the rows
    ld hl, .staged
    inc [hl] ; Count the scan
    ret

.menucheck
    ld a, [.mask]
    and a ; If no setting's feature is installed
    ret z ; return, leave EXIT alone
    ; Is the start menu open?
    ld a, [wMenuDataBank]
    cp 4 ; Start menu lives in bank 4
    ret nz
    ld a, [wMenuDataPointer]
    cp LOW(START_MENU_DATA)
    ret nz
    ld a, [wMenuDataPointer + 1]
    cp HIGH(START_MENU_DATA)
    ret nz ; If not the start menu's data, return
    ld hl, wScriptBank
    call UCPeekB1 ; Get script bank
    cp START_MENU_BANK
    ret nz
    ld hl, wScriptPos
    call UCPeekB1 ; Get script position, low byte
    cp LOW(START_MENU_POS)
    ret nz
    inc hl
    call UCPeekB1 ; High byte
    cp HIGH(START_MENU_POS)
    ret nz ; If the start menu script isn't running, return

    ; Point the start menu at our table
    ld hl, wMenuDataPointerTableAddr
    ld a, LOW(UCOptionsTable)
    ld [hli], a
    ld a, HIGH(UCOptionsTable)
    ld [hl], a

    ; The menu was already drawn with EXIT, so fix the label ourselves.
    ; EXIT is always the last item, drawn at row 2n
    ld hl, wMenuItemsList
    call UCPeekB1 ; Get number of items
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl ; hl = 8n
    ld d, h
    ld e, l ; de = 8n
    add hl, hl
    add hl, hl ; hl = 32n
    push hl ; Save 32n for the VRAM address
    add hl, de ; hl = 40n, two tilemap rows per item
    ld de, wTilemap + UC_LABEL_COL
    add hl, de ; hl = tilemap address of the label
    pop de ; de = 32n
    ld a, e
    add a, e
    ld e, a
    ld a, d
    adc a, d
    ld d, a ; de = 64n, two VRAM rows per item
    ld a, e
    add a, LOW(vBGMap0 + UC_LABEL_COL)
    ld e, a
    ld a, d
    adc a, HIGH(vBGMap0 + UC_LABEL_COL)
    ld d, a ; de = VRAM address of the label
    ld a, [hl]
    cp $84 ; Is "E" drawn there yet?
    ret nz
    inc hl
    ld a, [hld]
    cp $97 ; And "X"?
    ret nz ; If not, return
    ld bc, UCOptionsTable.label
    ld a, 7 ; Length of "UC OPTN"
    ; Fall into .copyboth

.copyboth
    ; Copies a bytes from bc to the tilemap (hl) and VRAM (de). VBlank only!
    push af
    xor a
    ldh [rVBK], a ; Select the VRAM tile map, not attributes
    pop af
.copyloop
    push af ; Save the count
    ld a, [bc]
    inc bc
    ld [hli], a ; Write to the tilemap
    ld [de], a ; Write to VRAM
    inc de
    pop af
    dec a
    jr nz, .copyloop ; Repeat until done
    ret

.step
    ret

UCOptionsEnd::

ENDL


; The blob. Stored in bank 4 (second window) but runs from $D280 in bank 1,
; so every pointer in here is a $D2xx address.
SECTION "uc options blob", ROM0[$0600]

UCOptionsBlob::

LOAD "uc options blob wram", WRAMX[UC_BLOB], BANK[1]

; Copy of StartMenu.Items with EXIT replaced. handler, label, description
UCOptionsTable::
    dw $6937, $6721, $674E ; Pokedex
    dw $6976, $6726, $675C ; Pokemon
    dw $695B, $672B, $676B ; Pack
    dw $6928, $6730, $678E ; Status
    dw $690B, $6732, $679E ; Save
    dw $691C, $6737, $67B1 ; Option
    dw .exit, .label, .desc ; Exit -- ours!
    dw $694C, $6743, $677A ; Pokegear
    dw $68F0, $6749, $67D1 ; Quit

.label: db "UC OPTN@"
.desc:  db   "Uncut"
        next "Crystal@"

.exit
    ; The start menu calls this instead of StartMenu_Exit when A is pressed
    ld a, 1 ; Any ROM bank works, the script is in WRAM
    ld [wQueuedScriptBank], a
    ld a, LOW(.script)
    ld [wQueuedScriptAddr], a
    ld a, HIGH(.script)
    ld [wQueuedScriptAddr + 1], a ; Queue our script
    ld a, 3 ; Tells the start menu to close and run the queued script
    ret

.script
    opentext
    callasm .build ; Drop rows for features that aren't installed
    loadmenu .header
    callasm .refresh ; Fill in the current values
.menu
    verticalmenu ; Draws the menu and waits. Selected row in wScriptVar, 0 if B
    callasm .select ; Cycle the selected setting, wScriptVar = 0 to close
    iftrue .menu ; Redraw in place, no closewindow
    closewindow
    closetext
    end

.header
    db MENU_BACKUP_TILES
    menu_coords 0, 0, 19, 17 ; Fullscreen
    dw .data
    db 1 ; Default selection
.data
    db STATICMENU_CURSOR | STATICMENU_WRAP
.count: db 0 ; Number of rows, filled in by .build

; One row per setting, in the same order as .settings. Compacted by .build
.items
    ucitem "B TO RUN"
    ucitem "FAST TEXT"
    ucitem "RE-USE REPEL"
.rowmap: ds NUM_SETTINGS + 1 ; Setting index for each row, $FF ends it

.settings
    ucsetting 0, UC_SET_B_TO_RUN,  2, .yesno ; TODO: point at the feature once it exists
    ucsetting 0, UC_SET_FAST_TEXT, 2, .yesno
    ucsetting 0, UC_SET_REPEL,     3, .repelvals

.yesno:     db "NO  ", "YES "
.repelvals: db "NO  ", "ASK ", "AUTO"

.installed: db 0 ; Bitmask from the scan

.build
    ; Keeps rows whose feature is installed, moving them up over dropped ones.
    ; Runs once per staging, the blob copy resets .count
    ld a, [.count]
    and a
    ret nz
    ld a, [.installed]
    ld c, a ; c = mask
    ld b, 0 ; b = setting index
    ld hl, .items ; hl = source row
    ld de, .items ; de = destination row
.buildloop
    ld a, b
    cp NUM_SETTINGS
    jr z, .builddone
    srl c ; Carry = this setting's feature is installed
    jr nc, .buildskip
    push hl
    ld a, [.count]
    call .rowmapat
    ld [hl], b ; rowmap[count] = setting index
    ld hl, .count
    inc [hl]
    pop hl
    push bc
    ld b, ITEM_LEN
.buildcopy
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .buildcopy ; Copy the row up
    pop bc
    jr .buildnext
.buildskip
    ld a, l
    add ITEM_LEN
    ld l, a
    jr nc, .buildnext
    inc h ; Skip the source row
.buildnext
    inc b
    jr .buildloop
.builddone
    ld a, [.count]
    call .rowmapat
    ld [hl], $FF ; End the row map
    ret

.rowmapat
    ; a = row, returns hl = its entry in .rowmap
    ld hl, .rowmap
    add a, l
    ld l, a
    ret nc
    inc h
    ret

.settingat
    ; a = setting index, returns hl = its entry in .settings
    add a, a
    add a, a
    add a, a ; a = index * 8
    ld hl, .settings
    add a, l
    ld l, a
    ret nc
    inc h
    ret

.select
    ; Called after verticalmenu. Cycles the selected row's setting to its next value
    ld a, [wScriptVar] ; Selected row, 1 based. 0 if B was pressed
    and a
    ret z
    ld [wMenuCursorPosition], a ; Keep the cursor on this row when redrawn
    dec a
    call .rowmapat
    ld a, [hl] ; Setting index
    call .settingat
    inc hl
    inc hl ; Skip the feature
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld b, a ; bc = setting byte
    ld a, [bc]
    inc a ; Next value
    cp [hl] ; If it's past the value count
    jr c, .store
    xor a ; wrap to 0
.store
    ld [bc], a
    ; Fall into .refresh. wScriptVar is still the row, so the script loops

.refresh
    ; Writes each row's current value into its text
    ld hl, .rowmap
    ld de, .items + ITEM_VAL ; Value of the first row
.refreshloop
    ld a, [hli]
    cp $FF ; If end of the row map
    ret z
    push hl
    push de
    call .settingat
    inc hl
    inc hl ; Skip the feature
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld b, a ; bc = setting byte
    ld a, [bc]
    add a, a
    add a, a ; a = value * 4
    ld c, a
    ld b, 0
    inc hl ; Skip the value count
    ld a, [hli]
    ld h, [hl]
    ld l, a ; hl = value strings
    add hl, bc ; hl = this value's string
    pop de
    ld b, VAL_LEN
.refreshcopy
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .refreshcopy ; Copy the value into the row
    ld a, e
    add ITEM_LEN - VAL_LEN
    ld e, a
    jr nc, .refreshnext
    inc d ; de = next row's value
.refreshnext
    pop hl
    jr .refreshloop

ENDL

UCOptionsBlobEnd::

; The staging copies whole chunks, so the last one must not run into wOTPartyDataEnd
ASSERT ((UCOptionsBlobEnd - UCOptionsBlob + UC_BLOB_CHUNK - 1) / UC_BLOB_CHUNK) * UC_BLOB_CHUNK <= $D42C - UC_BLOB
