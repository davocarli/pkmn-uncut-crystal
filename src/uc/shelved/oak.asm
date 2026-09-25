; Shelved 2026-09-25: Oak is replaced by an injected NPC to come.
; Kept for its script shape; EVENT_UC_OLD_SEA_MAP stays defined for the new ones.
; Oak's Lab, Professor Oak. Hands over the Old Sea Map once, after the Hall of
; Fame and after Red is beaten on Mt. Silver; the port sailor checks the flag.
; Included by shelved/cut_npcs.asm, assembled for UC_NPC_SCRIPT like sailor.asm.

DEF OaksLabOakScript EQU $73C8 ; pokecrystal's "Oak", bank $66, same in v1.0 and v1.1

UCOakSrc:: ; where the bytes sit, as an offset in uc.bin: bank 4 address minus $D000
LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1]
UCOakScript::
    checkevent EVENT_BEAT_ELITE_FOUR ; Red's flag alone is ambiguous: it is also set at a new game
    iffalse .original
    checkevent EVENT_RED_IN_MT_SILVER ; Set again once Red has been beaten
    iffalse .original
    checkevent EVENT_UC_OLD_SEA_MAP ; Only once
    iftrue .original
    faceplayer
    opentext
    writetext .text
    waitbutton
    closetext
    setevent EVENT_UC_OLD_SEA_MAP ; What the sailor looks for
    end

.text
    text "You say you fought"
    line "RED on MT. SILVER?"
    cont "You can have this."
    cont "You received OLD"
    cont "SEA MAP."
    done

.original
    sjump OaksLabOakScript ; His usual conversation
UCOakScriptEnd::
ENDL
