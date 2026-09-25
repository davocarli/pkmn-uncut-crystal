; Requires: npcinject
; Restore Cut Content module: its NPC injection table. Read by
; frameworks/npcinject.asm, which owns the format: uc_inject rows, a 0 group ends
; the table. One NPC per map. A row is
;   uc_inject MAP, SLOT, X, Y, SPRITE, MOVEMENT, RADIUS_X, RADIUS_Y, PALETTE
;   uc_part Name          ; one per script fragment, in copy order
;   uc_spawn_reload_appear SLOT   ; or uc_spawn_appear SLOT, or uc_spawn_none
;   uc_inject_end
; The scripts come from fragment files included after the table, one per NPC,
; assembled for UC_NPC_SCRIPT (see inject_constants.asm for the LOAD UNION shape
; and the split of a fragment over two windows). Empty until the NPCs land.

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/data.asm" ; dn, for the record's packed bytes
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "macros/scripts/text.asm"
INCLUDE "constants/charmap.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/event_flags.asm"
INCLUDE "constants/ram_constants.asm"
INCLUDE "constants/map_object_constants.asm" ; SPRITEMOVEDATA_*, and the record offsets
INCLUDE "constants/sprite_constants.asm"
INCLUDE "constants/sprite_data_constants.asm"
INCLUDE "frameworks/inject_constants.asm"

SECTION "uc cut injects", ROM0[$0D12]
LOAD "uc cut injects wram", WRAMX[$DD12], BANK[4] ; window 8, after the injector

UCCutInjects::
    db 0 ; End of table
ENDL

; The script fragments, one file per NPC, each in its own section
INCLUDE "npcs/scientist.asm"

UCCutInjectsEnd:: ; as an offset in uc.bin, like the Src labels
