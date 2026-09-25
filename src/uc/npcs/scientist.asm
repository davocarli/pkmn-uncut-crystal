; Ruins of Alph research center, a fourth scientist by the door. Hands over the
; Old Sea Map once every kind of UNOWN is caught; the Cinnabar sailor reads it.
; Included by features/cut_injects.asm, which lists it in the inject table.
; The script is assembled for the buffer the game runs it from, so its jumps
; and text pointers come out right after the copy.

SECTION "uc scientist", ROM0[$1200] ; scratch offset past every window until it is split and placed

UCScientistSrc:: ; where the bytes sit, as an offset in uc.bin: bank 4 address minus $D000
LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1] ; every fragment shares this union
UCScientistScript::
    ; the four states go here

; drafts, 18 characters a line
.before
    text "The UNOWN carvings"
    line "speak of an island"
    cont "far to the south…"

    para "Catch every kind"
    line "of UNOWN and I'll"
    cont "tell you more."
    done

.give
    text "All 26 UNOWN!"
    line "Then take this."

    para "A chart the ruins'"
    line "builders left…"

    para "<PLAYER> received"
    line "the OLD SEA MAP!"
    done

.waiting
    text "A sailor on"
    line "CINNABAR ISLAND"
    cont "could read that"
    cont "map for you."
    done

.after
    text "So the island"
    line "was real…"

    para "What did you find"
    line "there?"
    done
UCScientistScriptEnd::
ENDL
