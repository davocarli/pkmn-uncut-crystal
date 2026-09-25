; Modules. Each install module owns one bit of UCModules (slot4.asm) and its
; install code sets it. Features and tables tagged with a bit are skipped while
; it is clear. 0 means always on: base features and shared frameworks
DEF MOD_EXCLUSIVES EQU 1 << 0 ; Version Exclusives
DEF MOD_KANTO      EQU 1 << 1 ; Kanto Improvements
DEF MOD_CUT        EQU 1 << 2 ; Restore Cut Content
DEF MOD_251        EQU 1 << 3 ; 251 Edition
DEF MOD_QOL        EQU 1 << 4 ; Quality of Life

DEF TABLE_END      EQU $FF ; Ends a list of module tables
