; Requires: npcinject
; Restore Cut Content module: its NPC injection table. Read by
; frameworks/npcinject.asm, which owns the format: uc_inject rows, a 0 group ends
; the table. One NPC per map. A row is
;   uc_inject MAP, SLOT, X, Y, SPRITE, MOVEMENT, RADIUS_X, RADIUS_Y, PALETTE
;   uc_part Name          ; one per script fragment, in copy order
;   uc_spawn_load_appear SLOT   ; or uc_spawn_appear SLOT, or uc_spawn_none
;   uc_inject_end
; The scripts come from fragment files included after the table, one per NPC,
; assembled for UC_NPC_SCRIPT (see inject_constants.asm for the LOAD UNION shape
; and the split of a fragment over two windows).

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

SECTION "uc cut injects", ROM0[$0E30]
LOAD "uc cut injects wram", WRAMX[$DE30], BANK[4] ; window 9, first thing in it

UCCutInjects::
    ; a fourth scientist in the research center, by the door; the map has three already, so no sprite reload
    uc_inject RUINS_OF_ALPH_RESEARCH_CENTER, 4, 1, 2, SPRITE_SCIENTIST, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, PAL_NPC_BLUE
    uc_part ScientistA, $C000 ; window 5
    uc_part ScientistB
    uc_spawn_appear 4
    uc_inject_end

    ; the ex-sailor in the Cinnabar Pokemon Center; the map has no sailor sprite of its own
    uc_inject CINNABAR_POKECENTER_1F, 4, 6, 2, SPRITE_SAILOR, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, PAL_NPC_BLUE
    uc_part SailorA
    uc_part SailorB
    uc_part SailorC
    uc_spawn_load_appear 4
    uc_inject_end

    db 0 ; End of table
UCCutInjectsEnd::
ENDL

; The script fragments, one file per NPC, each in its own section
INCLUDE "npcs/faraway_scientist.asm"
INCLUDE "npcs/faraway_sailor.asm"
