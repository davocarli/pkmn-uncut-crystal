; Shelved 2026-09-25 with shelved/npcswap.asm: its rows become uc_inject rows in
; features/cut_injects.asm once the new NPCs are written. npc_constants.asm is gone.
; Restore Cut Content module: its NPC script table. Read by shelved/npcswap.asm,
; which owns the format: uc_npc rows, a 0 group ends the table. One NPC per
; map. The scripts are included from npcs/, one file each, assembled for
; UC_NPC_SCRIPT (see sailor.asm).

INCLUDE "constants/hardware.inc"
INCLUDE "macros/const.asm"
INCLUDE "macros/scripts/maps.asm"
INCLUDE "macros/scripts/events.asm"
INCLUDE "macros/scripts/text.asm"
INCLUDE "constants/charmap.asm"
INCLUDE "constants/map_constants.asm"
INCLUDE "constants/event_flags.asm"
INCLUDE "constants/ram_constants.asm"
INCLUDE "npc_constants.asm"

SECTION "uc cut npcs", ROM0[$0E30]
LOAD "uc cut npcs wram", WRAMX[$DE30], BANK[4] ; window 9, first thing in it

UCCutNpcs::
    uc_npc OLIVINE_PORT, 3, Sailor ; the sailor at the ship after the Hall of Fame
    uc_npc OAKS_LAB, 1, Oak ; Professor Oak, the Old Sea Map

    db 0 ; End of table
ENDL

; The scripts, one file per NPC, stored after the table
INCLUDE "shelved/sailor.asm"
INCLUDE "shelved/oak.asm"

UCCutNpcsEnd:: ; as an offset in uc.bin, like the Src labels
