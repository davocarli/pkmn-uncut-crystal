; Encounter roller tables, for frameworks/roller.asm.
; One row per map the game rolls nothing on: it has no wild table, so the
; roller does the game's job and the encounter override picks the species.

DEF UC_ROLL_GRASS EQU 0 ; only on tall or long grass
DEF UC_ROLL_ANY   EQU 1 ; on every step, wherever the player is

DEF UC_ROLLER_LEN EQU 5 ; where, rate, base level, level mask, placeholder species

; uc_roller MAP, WHERE, RATE, LEVEL, MASK, SPECIES: on MAP roll RATE out of 256
; per step for a LEVEL + (random & MASK) SPECIES. The size byte is for UCFindMap
MACRO uc_roller
    map_id \1
    db UC_ROLLER_LEN ; size of the body, for UCFindMap
    db \2, \3, \4, \5, \6
ENDM
