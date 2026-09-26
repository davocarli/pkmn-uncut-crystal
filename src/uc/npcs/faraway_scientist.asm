; Ruins of Alph research center, a fourth scientist by the door. Hands over the
; Old Sea Map once every kind of UNOWN is caught; the Cinnabar sailor reads it.
; Included by features/cut_npcs.asm, which lists it in the inject table.
; The script is assembled for the buffer the game runs it from, so its jumps
; and text pointers come out right after the copy. Two parts: A in window 5,
; B in window 4, assembled to follow A in the buffer.

SECTION "uc scientist a", ROM0[$1108] ; window 5, first thing in it: assembled $1000 past its address

UCScientistASrc:: ; where the bytes sit, as an offset in uc.bin
LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1] ; every fragment shares this union
UCScientistAScript::
    faceplayer ; Face the player
    opentext ; Initialize text box
    checkevent EVENT_UC_FARAWAY_VISITED ; Check if player has gone to faraway island
    iftrue UCScientistBScript.after ; Jump to after text
    checkevent EVENT_UC_OLD_SEA_MAP ; Check if player has received Old Sea Map
    iftrue .waiting ; Jump to waiting text
    readvar VAR_UNOWNCOUNT ; Check # of UNOWN caught
    ifequal NUM_UNOWN, .give ; If all UNOWN are caught, jump to giving Old Sea Map
    writetext .beforetext ; Print 'before caught' text
    waitbutton ; Wait for player to press a button
    closetext ; Close the text box
    end

.beforetext
    text "Did you know UNOWN"
    line "emit radio waves?"
    cont "I'm studying them."
    cont "Come back later."

    done

.give
    writetext .givetext ; Show givetext (below)
    waitbutton ; Wait for user input
    closetext ; Close text box
    setevent EVENT_UC_OLD_SEA_MAP ; Set event flag
    end

.givetext
    text "I discovered the"
    line "UNOWN radio waves"
    cont "hide coordinates!"
    cont "Can you check them"
    cont "for me?"

    para "<PLAYER> received"
    line "OLD SEA MAP!"
    done

.waiting
    writetext UCScientistBScript.waitingtext ; Show waiting text
    waitbutton ; Wait for user input
    closetext ; Close text box
    end
UCScientistAScriptEnd::
ENDL
UCScientistASrcEnd::

SECTION "uc scientist b", ROM0[$0A70] ; window 4, after UCFindMap

UCScientistBSrc::
LOAD "uc scientist b script", WRAMX[UC_NPC_SCRIPT + (UCScientistAScriptEnd - UCScientistAScript)], BANK[2] ; right after part A; the bank only keeps the linker's overlap check quiet
UCScientistBScript::
.waitingtext
    text "Did you check the"
    line "coordinates yet?"
    done

.after
    writetext .aftertext ; Show after text
    waitbutton ; Wait for user input
    closetext ; Close text box
    end

.aftertext
    text "A jungle island"
    line "full of Pokémon?"

    para "The UNOWN hold so"
    line "many mysteries!"
    done
UCScientistBScriptEnd::
ENDL
UCScientistBSrcEnd::
