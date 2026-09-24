; NPC script tables, for features/npcswap.asm.
; The game copies a map's object events into wMapObjects, 16 bytes each,
; record 0 the player, record 1 the map's first object_event. Byte $A of a
; record is the pointer to the script that runs when the object is talked to
DEF wMapObjects              EQU $D71E ; bank 1
DEF MAPOBJECT_LENGTH         EQU 16
DEF MAPOBJECT_SCRIPT_POINTER EQU $A
DEF VAR_WEEKDAY              EQU $0B ; readvar id
DEF EVENT_UC_OLD_SEA_MAP     EQU 300 ; an unused event flag, saved with the game

; uc_npc MAP, OBJECT, Name: object OBJECT of MAP runs UC<Name>Script from npcs/.
; The fragment defines UC<Name>Src (its bytes in bank 4), UC<Name>Script and UC<Name>ScriptEnd
MACRO uc_npc
    map_id \1
    db 5 ; size of the body, for UCFindMap
    dw wMapObjects + \2 * MAPOBJECT_LENGTH + MAPOBJECT_SCRIPT_POINTER
    dw UC\3Src + $D000
    db UC\3ScriptEnd - UC\3Script
ENDM
