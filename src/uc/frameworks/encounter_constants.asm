; How an encounter happened, for the encounter override (frameworks/encounters.asm).
; One bit each so an entry can accept several
DEF UC_GRASS     EQU 1 << 0
DEF UC_CAVE      EQU 1 << 1
DEF UC_SURF      EQU 1 << 2
DEF UC_OLD_ROD   EQU 1 << 3
DEF UC_GOOD_ROD  EQU 1 << 4
DEF UC_SUPER_ROD EQU 1 << 5
DEF UC_HEADBUTT  EQU 1 << 6
DEF UC_ANY_ROD   EQU UC_OLD_ROD | UC_GOOD_ROD | UC_SUPER_ROD
DEF UC_ANY       EQU $FF
