; Cinnabar Pokemon Center, a drunk ex-sailor by the wall. Tells his story, and
; once the player holds the Old Sea Map offers the crossing to Faraway Island:
; Yes warps onto the Mt. Silver exterior host, whose header the hijack patches.
; Included by features/cut_npcs.asm, which lists it in the inject table.
; The script is assembled for the buffer the game runs it from, so its jumps
; and text pointers come out right after the copy. Three parts: A in window 9
; after the table, B in window 7, C in window 3, each assembled to follow the last.

SECTION "uc sailor a", ROM0[$0E6F] ; window 9, after the inject table

UCSailorASrc:: ; where the bytes sit, as an offset in uc.bin: bank 4 address minus $D000
LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1] ; every fragment shares this union
UCSailorAScript::
    faceplayer
    opentext ; Initialize text box
    checkevent EVENT_UC_OLD_SEA_MAP
    iffalse .nomap
    checkevent EVENT_UC_SAILOR_OFFERED
    iftrue .offer
    writetext .storytext ; First time with the map: the story, then the offer below
    waitbutton
    setevent EVENT_UC_SAILOR_OFFERED ; Next time straight to .offer
    ; no closetext, no end: the script reads on into .offer, one box for both

.offer
    writetext UCSailorBScript.offertext ; The crossing, as a question
    yesorno ; 1 in the script variable for Yes
    iffalse .no
    writetext UCSailorCScript.yestext
    waitbutton
    closetext ; The box must be gone before the map changes
    setevent EVENT_UC_FARAWAY_VISITED ; The scientist's last state
    warp CELADON_POKECENTER_2F_BETA, 12, 33 ; The exterior host; the hijack does the rest
    end

.no
    writetext UCSailorCScript.notext
    waitbutton
    closetext
    end

.nomap
    writetext .storytext ; No map: the story and nothing else
    waitbutton
    closetext
    end

.storytext
    ;    "                  "
    text "Hic! I was a"
    line "sailor, y'know."
    cont "Cinnabar was my"
    cont "home port"

    para "Then the volcano"
    line "blew… Hic! Now I"
    cont "just come back"
    cont "to remember…"
    done
UCSailorAScriptEnd::
ENDL
UCSailorASrcEnd::

SECTION "uc sailor b", ROM0[$0C4C] ; window 7, after the cut block table

UCSailorBSrc::
LOAD "uc sailor b script", WRAMX[UC_NPC_SCRIPT + (UCSailorAScriptEnd - UCSailorAScript)], BANK[3] ; right after part A
UCSailorBScript::
.offertext
    ;    "                  "
    text "Hm? That's a sea"
    line "map! Heh… my old"
    cont "boat still floats."
    cont "Want to set sail?"
    done
UCSailorBScriptEnd::
ENDL
UCSailorBSrcEnd::

SECTION "uc sailor c", ROM0[$098C] ; window 3, after the roamers

UCSailorCSrc::
LOAD "uc sailor c script", WRAMX[UC_NPC_SCRIPT + (UCSailorAScriptEnd - UCSailorAScript) + (UCSailorBScriptEnd - UCSailorBScript)], BANK[5] ; right after part B
UCSailorCScript::
.yestext
    ;    "                  "
    text "Hic! Just like the"
    line "old days… Hic!"
    done

.notext
    ;    "                  "
    text "Suit yourself…"
    line "Hic!"
    done
UCSailorCScriptEnd::
ENDL
UCSailorCSrcEnd::
