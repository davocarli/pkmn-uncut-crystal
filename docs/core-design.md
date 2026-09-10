# `core` design — v3, 2026-09-07 (supersedes v1 and v2 the same day)

**Status 2026-09-09: implemented in `src/uc/` and verified in mGBA** (boot path: loader → stage 1 → Init → marker; complete: all three hooks and the slot-4 glue verified in-game 2026-09-10). Two corrections found in testing: (1) the routine that returns into TimoVM's reinstall must leave **carry clear** — `CheckSpecialPhoneCall` does `call _hl_ ; jr nc, .NoPhoneCall`, and `OpenSRAM` returns with carry set — so `UCFarCall` ends with `and a` — **every return into the reinstall goes through it, so carry is always clear regardless of what the kernel or a slot-4 step code did** (found the hard way twice: first `OpenSRAM`'s `cp`, then `UCStep`'s `cp`/`ret nz` early exits, 2026-09-10); it also uses `pop de`, not `pop af`, so the callee's Z survives (17 B, `UCFrameStub` falls into it); (2) the reinstall's `call CopyBytes` is at `$DA36`, so the diverted bytes are `$DA37–$DA38`. Lengths (stubs 36 B, PokeB1 12 B, stage 1) are label-derived everywhere, not constants.

Scope: the Tier 1 bundle every other bundle requires (README §2a). First features carried by it:
save-time parking of story phone calls and the bike-shop call replay (`docs/resilience.md`).
English Crystal, both revisions; every home-bank address below is identical in v1.0 and v1.1
(checked against both `.sym` files).

## Scope (user, 2026-09-10)
`core` is exactly: (1) fixes for the three ways TimoVM's arm byte loses or suppresses a story call — save-time loss (hook 1), the bike-shop trigger (hook 2), the nurse's Pokérus branch (hook 3) — and (2) the loader + kernel entry points that let everything else of ours live in WRAM bank 4. Nothing more. The intent is to offer it to TimoVM as an updated base setup: his framework with four bytes changed, plus one Mail Writer code's worth of ours. Feature registry, settings, repoint primitive and repair belong to the `uc` runtime (README §2a, Tier 1b), not here.

Fact that bounds the fix list: `wSpecialPhoneCallID` is read in exactly five places in the game — `CheckSpecialPhoneCall` (the ACE vector), the phone-call script setup (inside a call, real ID), `readvar VAR_SPECIALPHONECALL` (inside Elm's caller script, real ID), the bike-shop trigger (`ID == 0` test) and `checkphonecall`, whose only user is the nurse's Pokérus branch (`std_scripts.asm:127`). So the arm byte misleads exactly two consumers.

## Decisions (user, 2026-09-07)
1. **Four bytes of TimoVM's framework are changed**, nothing else of his: the call target in the
   hook template (`$DA1A–$DA1B`) and the call target in the reinstall routine (`$DA37–$DA38`).
   Everything else — Mail Writer, bootstrap, dispatcher, slots — stays byte-identical to the wiki.
2. **No constant-effect slot is used.** Slots 1, 2 and 3 stay free for wiki codes, and they keep
   working: our per-frame stub calls TimoVM's dispatcher, which runs them as before.
3. **Bike-shop call replay is in scope**, inside `core`.

## Why this shape
The kernel is far bigger than any saved WRAM we own, so it lives in SRAM and is copied into WRAM
bank 4 after every power-on (no execution from SRAM; bank 4 is never used by the English game).
Copying means opening SRAM, which is only safe when the game itself is not mid-operation. TimoVM's
reinstall routine runs on the **main thread, once per step, with interrupts off and SRAM
closed**, and it contains exactly one `call CopyBytes`. Pointing that call at our loader gives us a
safe main-thread moment every step: the loader does his copy, then ours, then hands the kernel a
per-step pass. His hook template contains exactly one `call` too (to his dispatcher); pointing it
at a WRAM0 stub that calls his dispatcher *and then* the kernel gives us the per-frame pass. Two
call targets, four bytes.

Two execution contexts follow, and every kernel hook is one or the other:
- **Frame** (interrupt, every frame bank 1 is mapped and `hOAMUpdate` is clear): WRAM only,
  through the bank-1 accessors. Never SRAM, never HRAM scratch (`hTempBank`/`hFarByte` are shared
  with the main thread's `GetFarByte`; an interrupt between its store and reload would corrupt a
  read). Budget rule until measured: under ~300 M-cycles.
- **Step** (main thread, inside the reinstall, interrupts off, SRAM closed, once per completed
  step on which `wSpecialPhoneCallID` is `$9C`, i.e. no story call is pending): anything goes —
  SRAM, ROM helpers, bank switches.

The v2 "idle predicate" (stack-peeking for `DelayFrame`) is no longer needed anywhere.

## Memory map

### TimoVM's framework, as modified (saved WRAM)
| Bytes | Wiki value | Ours | Effect |
|---|---|---|---|
| `$DA1A–$DA1B` (hook template `$DA15`, copied to `$C000` every step) | `3A DA` (`call z, $DA3A` = dispatcher) | `DA CF` (`call z, $CFDA` = FrameStub) | per-frame pass |
| `$DA37–$DA38` (reinstall `$DA21`) | `26 30` (`call $3026` = CopyBytes) | `47 DA` (`call $DA47` = loader) | per-step pass + boot load |

### Persistent, ours (saved WRAM)
| What | Where | Size | Notes |
|---|---|---|---|
| Loader | `$DA47–$DA71` | 43 of 43 B | runs every step in place of his `call CopyBytes` |
| `wParkedCall` | `$DA0E` | 1 B | zeroed by the installer; `$DA0F` spare |
| SRAM image | `00:$AC6B…` (1429 B gap) first; other gaps as needed | TBD (`budget.py`) | stage 1 (header + Init + Frame/Step dispatch) + WRAM0 image (38 B) + kernel + bundle images; fixed map |

`$DA0E–$DA71` is the unlabeled `ds 100` after `wErinFightCount`. TimoVM's setup uses
`$DA10–$DA14` (TM15 bootstrap) and `$DA15–$DA46` (framework); the Mail Writer is at `$D9C0–$D9F1`.
No Crystal code on the Mail Writer Codes page writes `$DA0E–$DA0F` or `$DA47–$DA71`. Expansion
room if ever needed: unused `wEventFlags` blocks 1484–1599 (14 B at `$DB2B`) and 833–999 (20 B at
`$DADA`, reserved for object-visibility flags by §4.4), 3 B per hop.

### Volatile WRAM0 (always mapped; `Init` in `home/init.asm` clears it on every reset, so never garbage)
| What | Where | Size | Installed by |
|---|---|---|---|
| `wKernelLoaded` = `KERNEL_LOADED_1/2` (`$4B $53`), "kernel loaded and initialised" | `$CFD8–$CFD9` | 2 B | kernel `Init`, last thing it does |
| `UCFrameStub` (falls into UCFarCall) | `$CFDA–$CFE1` | 8 B | loader, from the SRAM image |
| `UCFarCall` (call hl in bank b, restore bank; returns a, Z = a==0, **carry always clear**) | `$CFE2–$CFF2` | 17 B | loader, from the SRAM image |
| `UCPeekB1` (hl → a, bank 1) | `$CFF3–$CFFE` | 12 B | loader, from the SRAM image |
| spare | `$CFFF` | 1 B | |
| `PokeB1` (a → [hl], bank 1) | `$CD14–$CD1F` | 12 B | kernel `Init` |

`$CFD8–$CFFF` and `$CD14–$CD1F` are the only linker `EMPTY` ranges in WRAM0 (`pokecrystal.map`);
both are used to the last byte. `wDaysSince` (`$CFD7`) is only accessed as single bytes.
`wUnusedMapBuffer` is *not* free (`ClearUnusedMapBuffer` fills it).

### Kernel (WRAM bank 4, `$D000–$DFFF`, never cleared by the game)
```
$D000  UC_SIG_1/2    ; $43 $4B "CK", the image signature; informational, the WRAM0 flag is what the loader tests
$D002  jp UCFrame      ; FrameStub calls here every frame
$D005  jp UCStepEntry  ; loader calls here every step: wUCState == 0 → UCInit, else jp UCStep
$D008  wUCState        ; 0 in the image = needs Init; Init sets 1
$D009  UCStepEntry, UCInit  = the rest of stage 1 (≤ 255 B, copied by the loader)
       UCStage1End: UCStep, UCFrame = part B, copied by UCInit (the image keeps stubs + PokeB1 between the two parts)
```

## The code

Home-bank routines: `OpenSRAM $2FCB`, `CloseSRAM $2FE1`, `CopyBytes $3026`, `FarCopyWRAM $306B`
("copy bc bytes from hl to a:de", switches `rWBK` for the copy and restores it), `_hl_ $2FEC`.
Register facts: at loader entry `hl=$DA15, de=$C000, bc=12` (his copy's arguments); `CopyBytes`
leaves `bc=0` and `hl`/`de` one past the end — both facts are used below.

### Loader (43 B at `$DA47`, replaces his `call CopyBytes`)
```
call CopyBytes   ; CD 26 30     his 12-byte hook copy $DA15 → $C000, exactly as before; bc = 0 after
ld a, [$CFD8]    ; FA D8 CF
cp M1            ; FE xx        marker present ⇒ kernel and stubs are up
jr z, .step      ; 28 19
xor a            ; AF
call OpenSRAM    ; CD CB 2F     bank 0
ld a, 4          ; 3E 04
ld hl, $AC6B     ; 21 6B AC     image start (final address from the fixed map)
ld de, $D000     ; 11 00 D0
ld c, N          ; 0E nn        stage-1 length (b is 0)
call FarCopyWRAM ; CD 6B 30     → bank 4 and back; hl now points at the WRAM0 image in SRAM
ld de, $CFDA     ; 11 DA CF
ld c, 38         ; 0E 26        FrameStub + FarCall + PeekB1 (b still 0)
call CopyBytes   ; CD 26 30     SRAM → WRAM0
.step
ld hl, $D005     ; 21 05 D0     Step entry
ld b, 4          ; 06 04
jp $CFE5         ; C3 E5 CF     FarCall; its ret returns into the reinstall, which ends with reti
```
Python:
```python
def loader():                              # main thread, every step, interrupts off
    copy(0xDA15, 0xC000, 12)               # TimoVM's own work
    if wram0[0xCFD8] != M1:                # first step after a reset
        open_sram(0)
        bank4[0xD000:0xD000+N] = sram0[0xAC6B:0xAC6B+N]           # stage 1
        wram0[0xCFDA:0xD000] = sram0[0xAC6B+N:0xAC6B+N+38]        # the three stubs
        # SRAM is left open on purpose: Init closes it
    far_call(bank=4, 0xD005)               # Step → Init on the first pass, then per-step hooks
```
`FarCopyWRAM` is what lets bank-1 code write bank 4 at all: code in bank 1 cannot switch banks
itself (the next instruction fetch would come from the new bank), so the switch happens inside a
ROM routine whose return lands back in bank 1. The 43 bytes fit exactly.

### FrameStub (11 B at `$CFDA`; the hook's `call z` lands here with a = 0, as his dispatcher expects)
```
call $DA3A       ; CD 3A DA     TimoVM's dispatcher: re-arms $9C when the ID is 0, runs slots 1–3
ld hl, $D002     ; 21 02 D0     Frame entry
ld b, 4          ; 06 04
jp $CFE5         ; C3 E5 CF     FarCall; its ret returns to the hook body at $C000
```

### FarCall (15 B at `$CFE5`): call hl with WRAM bank b mapped, restore the bank, return a
```
ldh a, [rWBK]    ; F0 70
push af          ; F5
ld a, b          ; 78
ldh [rWBK], a    ; E0 70
call _hl_        ; CD EC 2F
ld b, a          ; 47           keep the callee's result
pop af           ; F1
ldh [rWBK], a    ; E0 70
ld a, b          ; 78
ret              ; C9
```
Used in both directions: bank 1 → 4 (stubs, loader) and bank 4 → 1 (kernel calling a ROM helper
that reads bank-1 data, e.g. `GetMapPhoneService`). Clobbers b and flags.

### Bank-1 accessors for Frame code
```
PeekB1  $CFF4: ld a,1 ; ldh [rWBK],a ; ld a,[hl] ; push af ; ld a,4 ; ldh [rWBK],a ; pop af ; ret
               3E 01    E0 70          7E          F5        3E 04    E0 70          F1       C9
PokeB1  $CD14: push af ; ld a,1 ; ldh [rWBK],a ; pop af ; ld [hl],a ; ld a,4 ; ldh [rWBK],a ; ret
               F5        3E 01    E0 70          F1       77          3E 04    E0 70          C9
```
Only ever called from bank 4 (`rWBK`=4). No HRAM, no ROM helpers, so safe in the interrupt.

## Init (bank 4, main thread, first Step after a reset; SRAM open on bank 0)
1. Walk the image table: `OpenSRAM bank ; CopyBytes gap → bank-4 destination` for each remaining
   piece (`rWBK` is already 4).
2. `CloseSRAM`.
3. Copy `PokeB1` to `$CD14`.
4. Zero volatile kernel state; `wKState = 1`; write `M1 M2` at `$CFD8` last.
5. `ret` — back through FarCall into the reinstall.

Cost: one full load ≈ 2.8 KB × 13 M-cycles ≈ one frame, once per power-on, on the first step, with
interrupts off — a single missed VBlank. If visible, Init can load one piece per Step instead
(Frame already returns immediately while `wKState` is 0, so a partial kernel is never called).

## Hooks

### Frame hook — save-time parking (`docs/resilience.md`)
```python
def parking_frame():
    if wram0[0xC2CD]:                 # wGameLogicPaused: save / Hall of Fame / Bill's PC
        id = peek_b1(0xDC31)
        if id not in (0, 0x9C):
            poke_b1(0xDA0E, id)       # wParkedCall
            poke_b1(0xDC31, 0x9C)     # what SavePlayerData will copy
    else:
        p = peek_b1(0xDA0E)
        if p:
            poke_b1(0xDC31, p)        # vanilla CheckSpecialPhoneCall fires it next step
            poke_b1(0xDA0E, 0)
```
Facts (save.asm): every save path is `PauseGameLogic` → prompt/text → `SavePlayerData` (copies
`$D47B–$DCA4`, both bytes) → `ResumeGameLogic`. `wGameLogicPaused` only gates joypad reads and
the game timer, so no script can queue a new ID while paused. ~40 B, ~150 M-cycles/frame.

### Step hook — bike-shop call replay
Vanilla (`events.asm` `.BikeShopCall`, once per step): `STATUSFLAGS2_BIKE_SHOP_CALL_F` (bit 4 of
`wStatusFlags2` `$D84D`) set, `wPlayerState` (`$D95D`) == `PLAYER_BIKE` (1),
`GetMapPhoneService` == 0, `wBikeStep` (`$DCA2`, big-endian) ≥ 1024, **and
`wSpecialPhoneCallID` == 0** → write `SPECIALCALL_BIKESHOP` (6), clear the flag. Under TimoVM the
last test always fails because the byte reads `$9C`. Step only runs when it *is* `$9C`, so:
```python
def bikeshop_step():
    f = peek_b1(0xD84D)
    if not (f & 0x10): return
    if peek_b1(0xD95D) != 1: return
    if peek_b1(0xDCA2) < 4: return                    # high byte of the step count
    if far_call(bank=1, 0x2D05) != 0: return          # GetMapPhoneService, bank 1 mapped
    poke_b1(0xDC31, 6)                                # fires on the next step (WhereverYouAre)
    poke_b1(0xD84D, f & ~0x10)
```
~35 B. The ID write lands after `CheckSpecialPhoneCall` has already read `$9C` this step, so the
call is evaluated on the following step, same as vanilla's one-step latency.

### Frame hook 3 — nurse / Pokérus (present "no call" to the nurse's check)
`checkphonecall` treats any non-zero ID as "a call is pending" and the nurse then skips the Pokérus check, so under TimoVM nobody ever catches Pokérus and Elm's Pokérus call never happens. **Narrowed to exactly that command (user, 2026-09-10: patch the known bug, touch nothing else).** In `PokecenterNurseScript` the command is preceded by `pause 10`; `GetScriptByte` advances `wScriptPos` after every read, so for the 20 frames of that pause the script engine sits with `wScriptBank:wScriptPos` = `2F:411F`, the `checkphonecall` opcode (byte-identical in v1.0 and v1.1; the Pokécom Center nurse uses the same script). Fix, in the un-paused half of `UCFrame`:
```python
def nurse_frame():                    # every frame, not paused
    if peek_b1(0xD439) != 0x2F: return          # wScriptBank
    if peek_b1(0xD43A) != 0x1F: return          # wScriptPos low
    if peek_b1(0xD43B) != 0x41: return          # wScriptPos high
    if peek_b1(0xDC31) != 0x9C: return          # a real ID: leave it
    poke_b1(0xDC31, 0)
```
His dispatcher re-arms `$9C` first thing every frame; we zero it again in the same interrupt, so when the pause ends `checkphonecall` reads 0, the nurse runs `CheckPokerus`, and on a hit queues `SPECIALCALL_POKERUS` herself. The next script command that yields (`farwritetext`) moves `wScriptPos`, the condition stops matching, and the re-arm stands. ~35 B. The byte is `$9C` everywhere else exactly as in TimoVM's setup.

Superseded broader variant (zero while `wScriptRunning` ≠ 0): also correct and 15 B smaller — analysis kept below because it establishes that the ID is inert during any script.

Why zeroing during *any* script loses no capability (researched 2026-09-10): `wScriptRunning` is set by `PlayerEvents` for every player event (map scripts, NPC talk, signs, warps, connections, hatching, trainer sightings, and the start menu — `StartMenuScript` is a map script) and cleared by `Script_end`/`endall`. While it is set, `PlayerEvents` returns early, so `CountStep`'s `CheckSpecialPhoneCall` — the only code that *acts* on the ID — never runs; the ID is inert. Its other readers during a script are `checkphonecall` (nurse only) and `readvar VAR_SPECIALPHONECALL` inside Elm's caller script, which reads a real ID before clearing it. We only ever zero `$9C`, so IDs written by `specialphonecall` are untouched. TimoVM's own reactivate code (`3E 9C EA 31 DC C9`), run from the item menu (a script), still works: his dispatcher and our hook flip the byte within each VBlank until the menu closes, then `$9C` stands. His deactivate code (writes 0 before the first step, hook down) is unaffected because our kernel isn't running then. Ordering that matters: `UCFrameStub` calls his dispatcher *before* `UCFrame`, so on the first paused frame the byte is already re-armed when the park half looks at it.

## Slot 4 — the extended slot (`core`'s interface to everything else)
Short form (the pitch; user's draft 2026-09-10, corrected):

> The updated setup includes:
> - **Special-call fixes.** Saving while a story call is pending no longer disables the setup: the pending call ID is parked at save time and put back as soon as the save is over, so the call still happens. The bike-shop call and the Pokémon Center's Pokérus check, both silently suppressed by the original setup, work again.
> - **Slot 4.** A fourth constant-effect slot holding about 1 KB of code, stored in unused SRAM and loaded into WRAM bank 4 on the first step after power-on. Unlike the other slots it has two entry points: a per-frame entry inside the VBlank interrupt, like the others, and a per-step entry on the main thread with interrupts off and SRAM closed, so persistent code there can safely open SRAM to read or write it and call ROM routines that switch banks.
> - Slots 1–3 are unaffected and keep working as before.

Long form (for the wiki section itself):

> **Slot 4.** The updated setup adds a fourth constant-effect slot. It holds up to about 1 KB of code, stored in unused SRAM and copied into WRAM bank 4 on the first step after power-on, so it survives resets like slots 1–3 do.
>
> It has two entry points. The **per-frame entry** runs inside the VBlank interrupt, like the other slots: good for watching or adjusting WRAM every frame, bad for anything slow or anything that touches the cartridge. The **per-step entry** runs once each time the player completes a step in the overworld, on the main thread, with interrupts off and SRAM closed. That is the state the game itself is in between its own operations, so code there can do things the per-frame slots never safely could: open SRAM and read or write it, keep persistent data of its own in unused SRAM, call any ROM routine including ones that switch banks or use HRAM scratch, and run for longer than a VBlank allows without corrupting the screen.
>
> Code in slot 4 runs with WRAM bank 4 mapped and reaches saved data through the PeekB1/PokeB1 helpers the setup installs. Slots 1–3 are unaffected.
>
> Fine print: the per-step entry does not run on steps where a story phone call is pending (it rides on the same Special Call that reinstalls the hook), so it is not a reliable step counter.

Contract (fixed addresses, README §2a "fixed map"):
| | SRAM (bank 0) | bank 4 | size |
|---|---|---|---|
| `core` image (stage 1 + stubs + PokeB1) | `$AC6B–$AE6A` | `$D000–$D1FF` | 512 B (re-cut 2026-09-10: three fixes = 267 B image; stage 1 must stay ≤ 255 B) |
| slot 4 image | `$AE6B–$B1FF` | `$D200–$D594` | 917 B, the rest of the bank-0 gap |

Slot 4 header at `04:D200`: `db "U4"` signature (`UC_SLOT4_SIG_1/2`), `jp Frame4` at `$D202`, `jp Step4` at `$D205`. `UCInit` always copies the whole slot-4 window from SRAM (917 B ≈ 12k M-cycles, once per power-on); `UCFrame` and `UCStep`, after `core`'s own hooks, check the signature and `call $D202` / `call $D205` if present. An uninstalled slot 4 is whatever the gap held (`$FF` on fresh SRAM, `$00` after delete-save), neither of which matches the signature. The UC Runtime (README §2a Tier 1b) is our slot-4 code; it owns the other four gaps and loads bundles from them itself.

## Install contract for `core`
- Patcher: patch the four framework bytes, write the loader, zero `$DA0E`, write the SRAM image
  into the gaps, re-checksum, both save blocks.
- Mail Writer code: `tools/mailcode.py` turns the same write list into a self-contained payload
  (TimoVM-style: `OpenSRAM` / `ld hl,data` once / per write `ld de` + count + `call CopyBytes` /
  `CloseSRAM` / `ret`, data appended in copy order so `hl` is never reloaded), 414 B = one code of
  26 mails, printed as hex for his MailConverter. **Verified by hand 2026-09-10**: all 26 mails typed
  on `build/cartridge-test-hijack.sav`, START, one step, bike-shop call replayed.
  **Real limit is 26 mails (416 B), not 428**: each new mail's compose screen initialises 34 bytes
  at the writer's pointer, and a 27th mail's buffer (`$D420–$D441`) runs through `wScriptFlags`,
  `wScriptMode`, `wScriptRunning`, `wScriptBank`, `wScriptPos`. Longer jobs are split across codes
  (`installers()`), writes cut at any address; `written_bytes()` decodes a payload for the
  round-trip check. Worth telling TimoVM.
- Compatibility: re-running TimoVM's "Setting up an OAM DMA hijack" code restores his four bytes;
  the game keeps working with plain TimoVM behaviour and `core` is dormant until the `core` code
  (or the patcher's repair) is re-run. Wiki slot codes and the reactivate/deactivate/reset codes
  are unaffected. The cold case in `docs/resilience.md` (hook down at save time) is unchanged.
- README §4.4: SRAM is touched only from Step (main thread); the "bootstrap store: box names and
  TM/HM quantities" line is stale.

## Verification checklist (Phase 1, BGB)
- Write-watch `$CFD8–$CFFF`, `$CD14–$CD1F` and `04:D000–DFFF` during ordinary play (nothing but us).
- Confirm the reinstall path: breakpoint `$DA47`, interrupts off, SRAM disabled at entry.
- Measure Frame's cycle count and the one-time load hitch.
- Both revisions: the four patched bytes and all home-bank addresses.
