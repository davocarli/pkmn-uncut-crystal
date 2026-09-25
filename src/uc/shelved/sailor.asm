; Shelved 2026-09-25: the Olivine sailor is replaced by an injected NPC to come.
; Kept for its script shape (LOAD UNION fragment assembled for the buffer).
; Olivine Port, the sailor by the ship after the Hall of Fame. Included by
; shelved/cut_npcs.asm, which lists it in the NPC table. The bytes sit in the
; table's image, but the script is assembled for the buffer the game runs it
; from, so its jumps and text pointers come out right after the copy.

DEF OlivinePortSailorAfterHOFScript EQU $499C ; bank $1D, same in v1.0 and v1.1

UCSailorSrc:: ; where the bytes sit, as an offset in uc.bin: bank 4 address minus $D000
LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1] ; every fragment shares this union
UCSailorScript::
    checkevent EVENT_UC_OLD_SEA_MAP ; Check if the player has acquired the old sea map
    iffalse .original ; If not, return to the original npc script
    readvar VAR_WEEKDAY ; Read the current weekday
    ifnotequal THURSDAY, .original ; If not Thursday, run original script
    faceplayer
    opentext
    writetext .eventtext ; Display the event text for the sailor, found below
    yesorno ; A yes/no prompt for the player
    iffalse .no ; If the player selects no, jump to the .no label which just closes the text
    closetext
    warp CELADON_POKECENTER_2F_BETA, 12, 33 ; Warp to hijack map
    end
.no
    closetext
    end

.eventtext
    text "Go to FARAWAY"
    line "ISLAND?"
    done

.original
    sjump OlivinePortSailorAfterHOFScript ; Jump to the original script after the Hall of Fame
UCSailorScriptEnd::
ENDL
