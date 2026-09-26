; NPC injection tables, for frameworks/npcinject.asm.
; The game copies a map's object events into wMapObjects, 16 bytes each, record 0
; the player, record 1 the map's first object_event; an empty slot holds sprite 0
; and struct id -1. A row writes the 13 object_event bytes of a record (never byte
; 0, the object struct id) and points it at our script buffer, so a row on an empty
; slot makes an NPC and a row on a used slot replaces one.
;
; A row is: uc_inject, then uc_part per script fragment, then one spawn macro, then
; uc_inject_end. A fragment is assembled for the buffer it runs from:
;   UC<Name>Src::
;   LOAD UNION "uc npc scripts", WRAMX[UC_NPC_SCRIPT], BANK[1]
;   UC<Name>Script:: ... UC<Name>ScriptEnd::
;   ENDL
; A part is at most 255 B. A fragment that does not fit one window is split at a
; text boundary into two files, part A as above and part B assembled to follow it:
;   LOAD "uc <name> b", WRAMX[UC_NPC_SCRIPT + (UC<Name>AScriptEnd - UC<Name>AScript)], BANK[n]
; with a bank number of its own (2..7): the linker refuses two sections that
; overlap unless they are one union, and nothing ever reads the bank. Part A
; names part B's labels in full (UC<Name>BScript.after). Both parts are listed,
; in order, with uc_part.
DEF wMapObjects              EQU $D71E ; bank 1
DEF UC_NPC_SCRIPT            EQU $D2C0 ; bank 1, where an injected script is copied. After the runtime's
                                        ; queued-script buffer ($D280): a queued warp is still mid-script
                                        ; when the next map's injector copies
IF !DEF(MAPOBJECT_LENGTH) ; a table file may have pulled in constants/map_object_constants.asm for SPRITEMOVEDATA_*
DEF MAPOBJECT_LENGTH         EQU 16
DEF MAPOBJECT_SPRITE         EQU 1 ; first byte a row writes
DEF MAPOBJECT_SCRIPT_POINTER EQU $A
ENDC
DEF UC_RECORD_LEN            EQU 13 ; sprite .. event flag, what ReadObjectEvents copies
DEF VAR_WEEKDAY              EQU $0B ; readvar id
DEF VAR_UNOWNCOUNT           EQU $0E ; readvar id: kinds of UNOWN caught
DEF NUM_UNOWN                EQU 26
; unused event flags, saved with the game. Never 264..599: that byte range of wEventFlags
; ($DA93..$DABC) is TimoVM's constant-effect slot, nops his dispatcher runs every frame, so a
; set bit there becomes an instruction (300..302 made ld [hl], b, which trashed the special
; call id). 833..999 are unused and clear of every TimoVM structure
DEF EVENT_UC_OLD_SEA_MAP     EQU 833 ; the scientist's map
DEF EVENT_UC_SAILOR_OFFERED  EQU 834 ; the sailor has told his story once
DEF EVENT_UC_FARAWAY_VISITED EQU 835 ; the sailor has taken the player across
DEF UC_LOAD_USED_SPRITES_GFX EQU 94 ; LoadUsedSpritesGFX in data/events/special_pointers.asm

; uc_inject MAP, SLOT, X, Y, SPRITE, MOVEMENT, RADIUS_X, RADIUS_Y, PALETTE
; opens a row; uc_part rows follow, then a spawn macro and uc_inject_end
DEF UC_INJECT_N = 0
MACRO uc_inject
    map_id \1
    DEF UC_INJECT_N += 1
    db .ucinjectend{d:UC_INJECT_N} - .ucinjectbody{d:UC_INJECT_N} ; size, for UCFindMap
.ucinjectbody{d:UC_INJECT_N}
    db \2 ; the record to write
    db \5, \4 + 4, \3 + 4, \6 ; sprite, y, x, movement function
    dn \8, \7 ; movement radius, y then x
    db -1, -1 ; hours: always here
    dn \9, 0 ; palette, OBJECTTYPE_SCRIPT
    db 0 ; sight range, for trainers
    dw UC_NPC_SCRIPT ; talking runs our buffer
    dw -1 ; no event flag
ENDM

; uc_part Name[, OFFSET]: one part of the script, copied in the order the parts are listed.
; OFFSET turns the Src offset into a bank 4 address: $D000, or $C000 for a part in
; window 5, whose sections assemble $1000 past their address (patcher.py)
MACRO uc_part
    db UC\1ScriptEnd - UC\1Script ; its length
    IF _NARG > 1
    dw UC\1Src + \2
    ELSE
    dw UC\1Src + $D000 ; where the bytes sit, bank 4
    ENDC
ENDM

; the spawn script, queued once the record is written. appear puts the object on the map.
; script object ids are the record plus one: GetScriptObject decrements before the lookup
MACRO uc_spawn_appear
    db 0 ; end of the parts
    db 3 ; length of the spawn script
    appear \1 + 1
    end
ENDM

; same, for a sprite the map does not already carry: the injector has put it at the end of
; wUsedSprites, so LoadUsedSpritesGFX copies its tiles into vram after the map's own, which
; it copies again where they already are. Nothing on screen moves
MACRO uc_spawn_load_appear
    db 0 ; end of the parts
    db 6 ; length of the spawn script
    db special_command
    dw UC_LOAD_USED_SPRITES_GFX
    appear \1 + 1
    end
ENDM

; overwriting a record of an object that is already on the map: nothing to spawn
MACRO uc_spawn_none
    db 0 ; end of the parts
    db 0 ; nothing to queue
ENDM

MACRO uc_inject_end
.ucinjectend{d:UC_INJECT_N}
ENDM
