# WRAM bank survey (static)

Source: pokecrystal commit `7a7881d0d`, `ram/wram.asm`, `layout.link`, `pokecrystal.map`, and every
`ldh [rWBK], a` in the tree (496 sites). Method: same as the SRAM audit in `docs/sram-map.md` —
list what the linker allocates, then find every write that could land in the region.

## Linker allocation of the switchable banks (`$D000–$DFFF`)

| Bank | Sections | Allocated | Free (linker) |
|---|---|---|---|
| 1 | WRAM 1, Misc WRAM 1 (UNION), More WRAM 1, Enemy Party, Party | full | 0 |
| 2 | Pic Animations (`wTempTilemap` 360 B + `wPokeAnimStruct` 41 B) | `$D000–$D190` | **`$D191–$DFFF` = 3695 B** |
| 3 | Battle Tower RAM | full | 0 |
| 4 | News Script RAM (`w4_d000:: ds $1000`) | full, one label | 0 by linker, **4096 B in practice** (below) |
| 5 | GBC Video (`$D000–$D28F`), Battle Animations (`$D300–$D461`), Mobile RAM (`$D800–$DC49`) | three islands | `$D290–$D2FF` 112, `$D462–$D7FF` 926, `$DC4A–$DFFF` 950 |
| 6 | Scratch RAM (UNION: tilemap/attrmap scratch, decompression, `w6_d000` "unidentified uses") | full | 0 |
| 7 | Stack RAM (`wWindowStack`, grows down from `$DFFF`) | full | 0 |

## Who switches to each bank

Aggregated from the value loaded into `a` immediately before each `ldh [rWBK], a`
(`pop af` / `ldh a,[rWBK]` restores excluded):

- **Bank 4:** 16 sites, **all in `mobile/mobile_5f.asm`**, plus two `CopyBytes` of `$1000` bytes from
  SRAM bank 6 (`s6_a006`) into `w4_d000` in the same file. No other file names `w4_d000` or bank 4.
- **Bank 2:** 5 sites — `home/copy_tilemap.asm` (2, `wTempTilemap`, bounded by `SCREEN_AREA`) and
  `engine/gfx/pic_animation.asm` (3, `wPokeAnimStruct`; the `ByteFill` is bounded by
  `wPokeAnimStructEnd - wPokeAnimStruct`). Nothing indexes past `$D190`.
- **Non-constant switches outside mobile code:** `home/copy.asm` (`hTempBank`, callers pass `BANK()`
  constants), `engine/battle_anims/pokeball_wobble.asm:56` and `engine/tilesets/timeofday_pals.asm:64,93`
  (all three restore a bank saved earlier in a register). Every other dynamic switch is in `mobile/`.
- **Interrupt paths:** `home/vblank.asm`, `home/serial.asm`, `home/time.asm` never touch `rWBK`.

## Is the bank-4 code reachable on English Crystal?

Call-graph walk inside `mobile_5f.asm` (scratchpad `callgraph.py`) from every label the rest of the
game references. Only two entry points reach a bank-4 writer:

1. **`Function17d2ce`** — registered in `data/events/special_pointers.asm`, but **no script anywhere
   in the tree invokes it** (`grep 'special Function17d2ce'` → nothing). Dead special.
2. **`RunMobileScript`** — dispatched by the `<MOBILE>` text control character (`$15`,
   `home/text.asm` `MobileScriptChar`). **No text in the tree contains `<MOBILE>`.** Reachable only if
   a glitch prints a string that happens to contain `$15`, i.e. never in normal play.

The other exported entry points (`BattleTowerMobileError`, `CheckStringForErrors`, `Function17d0f3`,
`Menu_ChallengeExplanationCancel`, `DisplayMobileError`, `Mobile_CopyDefault*`) never reach bank 4.
The Mobile main-menu options are gated on `ENGINE_MAIN_MENU_MOBILE_CHOICES`, which **nothing sets**
(only the GameShark code `010576CF` from the plan does), and the mobile menu itself lives in
`mobile_menu.asm`/`mobile_46.asm`, which do not write bank 4.

**Verdict: bank 4 (`$D000–$DFFF`, 4096 B) is never written by reachable code.** Adopt it as the
kernel bank (§4.3 design). Bank 2's tail (`$D191–$DFFF`, 3695 B) is the second candidate, with the
same static confidence but a live neighbour (`wTempTilemap` is used by many menus). Bank 5's gaps are
usable fallback but bank 5 is switched to ~40 times per frame-path (palettes, LY overrides), so an
off-by-one anywhere in that code would land on us; keep it in reserve.

## Two facts that shape the runtime design

- **Boot does not clear banks 2–7.** `ClearWRAM` (`home/init.asm`) has the retail bug `jr nc`
  instead of `jr c` (`docs/bugs_and_glitches.md`): it wipes bank 1 only. So a kernel copy in bank 4
  survives a soft reset in emulators, but on hardware power-on WRAM is undefined — **never rely on
  it**. The program persists in SRAM and is copied in at Special Call reinstall time, as planned.
- **The OAM DMA hook always runs with interrupts disabled.** In every VBlank handler
  (`VBlank_Normal`, `_Cutscene`, `_CutsceneCGB`, `_Serial`) `call hTransferShadowOAM` comes before the
  handler's `ei`. L1's `rWBK` save/switch/restore inside the hook cannot be interrupted, so no
  interrupt handler can observe the kernel bank mapped.

## Costs

- Reinstall copy SRAM→WRAM via `CopyBytes` is ~13 M-cycles/byte: the full 2831 B budget copies in
  ~37k cycles ≈ 35 ms at single speed, once per reinstall, on the main thread. Not a constraint.
- L1 bank swap per frame: `ldh a,[rWBK]; push af; ld a,4; ldh [rWBK],a; call K; pop af; ldh [rWBK],a`
  = 9 bytes, ~14 M-cycles overhead on top of the kernel's own time.

## Still to confirm at runtime (BGB write-watch, Phase 0 item 6)

- Write-watch `04:D000–DFFF` across overworld, battle, PC, Pokégear, save, link, Battle Tower.
- That the 3DS VC emulator, Analogue Pocket and Chromatic implement all eight WRAM banks
  (they run Crystal as a CGB title, so they must; but "must" is not "measured").
