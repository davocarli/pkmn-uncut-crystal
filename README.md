# Pokémon - Uncut Crystal — Implementation Plan

Project name (2026-09-09): **Pokémon - Uncut Crystal**. Everything of ours carries a `UC`/`uc` prefix: asm labels and constants (`UCLoader`, `wUCLoaded`, `UC_BANK`), patcher functions (`install_uc_core`), sources in `src/uc/`, build output `build/uc.bin`/`uc.sym`. `core` stays an internal bundle name only (Pokémon Core Crystal exists).

**This is the living plan.** It supersedes the original handoff document and the 2026-09-04 plan update; both are folded in here. Read it fully before writing code. "Established facts" and "Corrections" are accumulated knowledge and must not be re-derived, only verified against the built disassembly. Changelog at the bottom.

---

## 0. Status (updated 2026-09-04)

Phase 0 in progress, teach-and-code mode. Done: RGBDS 1.0.3 installed; `pokecrystal` submodule at commit `7a7881d0d` (2026-08-13); both revisions built and hash-verified against `roms.sha1` (v1.0 `f4cd194b…`, v1.1 `f2f52230…`); repo layout created; `docs/labels.txt` written from §8. `tools/symdiff.py` (user-written) + a ROM byte diff done: 3 labels / 584 bytes differ, all attributed (`docs/revision-diff.md`); **no project label differs → indirection table = 0 bytes**. `docs/facts.md` generated. `patcher.py` verify/fix CLI done, VC footer and mGBA tail passed through unchanged, `sentinel`/`sentinel-check` subcommands fill the SRAM gaps with a position-dependent marker so ordinary play on the 3DS reveals any write. `docs/sram-map.md` done: 3020 B unallocated SRAM, confirmed free by static audit of every SRAM write (2831 B available after reserving TimoVM's RAM Writer range). Patcher options (a) and (b)-framework (`install-timovm`, `install-dma-hijack`) written and verified in mGBA. **Phase 1 started:** `src/uc/` (stubs, loader, kernel stage 1) and `install-uc-core` written and verified in mGBA 2026-09-09 — the kernel loads and initialises. Save-time parking, bike-shop replay and the nurse Pokérus fix implemented and verified in-game 2026-09-10 (fresh save and cartridge save). `core` complete 2026-09-10 (slot-4 contract included). Next: the UC Runtime as slot-4 content; the TimoVM proposal can go out. Language survey done 2026-09-10 (`docs/languages.md`): FR/DE/IT/SP are a rebuild with per-language ROM addresses and, for IT, different patch offsets; JP is a separate port. `tools/mailcode.py` (user-written) turns the write list into a TimoVM-style installer payload, hex for his MailConverter; one 26-mail code installs `core` over his setup, **verified by hand in mGBA 2026-09-10** (all 26 mails typed, bike call replayed). Real Mail Writer limit found to be 26 mails / 416 B, not 428; longer jobs split across codes. Next: `core` design on the fixed address map, BGB trace of the Special Call chain, prior-art reading.

---

## 1. Project definition

### 1.1 Goal
Enhance a **stock, unmodified retail Pokémon Crystal cartridge (USA, MBC3, 32 KB SRAM)** — or the 3DS Virtual Console release — with restored cut content and native-feeling quality-of-life features, using **only Arbitrary Code Execution (ACE)**: code and data written into SRAM/WRAM and executed via in-game glitches. This is an **SRAM hack**, as opposed to a ROM hack: the ROM is never touched; the program lives in the save.

**Positioning:** no public Gen 2 kernel exists. Private persistent custom-event/GUI work for Gen 2 exists on the Glitch City Research Institute (GCRI) Discord, whose author confirms the approach is doable "if you know what you're doing and watch the size limits." No known project anywhere targets **content restoration** rather than a cheat menu. The Gen 1 precedent is BBMenu/BBMenuSE (§10, prior art) — read it before designing the kernel; reuse its patterns.

**Deliverables and their roles (decided 2026-09-04):**
1. A **save-file patcher** — Python reference tool *and* a client-side **static website** (upload `.sav`, download patched `.sav`) with two options: (a) "TimoVM ACE setup only" and (b) "Full SRAM hack". See §5.2. **Expected install path for most people, but not the recommended one:** the project recommends the hand install (TimoVM's guides, then ours) and offers the patcher for those the guides turn away.
2. A written **install guide** a person can follow on original hardware with no external devices (hand-entered data only). **The recommended install path, and required regardless of install time: it is the existence proof that the whole thing can be done by hand.** Hand install is on the order of 5 button presses per byte, so ~15k presses for a 3 KB program; the guide states that honestly.
3. Optional: **premade saves** (patcher output) for users who own a dumper.

**How the proof is kept honest without redoing 15k presses per release:** one complete hand install on real hardware, recorded, for at least the minimal program (the ACE layers + feature 1), plus the CI equivalence test that the generated guide, `patcher.py` and the web patcher produce byte-identical saves for every build. Per-part verification checks in the guide (BBMenuSE model) are what make a hand install debuggable.

**Target ROM: both USA revisions — v1.0 and v1.1 (Rev 1) — from a single program.** The 3DS VC is built from v1.1 (pokecrystal `make crystal11_vc`). v1.0 = chip `CGB-BYTE-0`, header `$014C` = `$00`. v1.1 = `CGB-BYTE-1`, `$014C` = `$01`, CRC32 `3358E30A`; Australian and European VC are v1.1-based.

pokecrystal's `_CRYSTAL11` conditionals show **four** v1.1 changes (TCRF lists three): the unused Mobile Stadium background (LF→CRLF), the Pokédex page-number byte (`wPokedexStatus` `$CF65` → `$C7E5`), a Battle Tower trainer-text fix, and a Battle Tower trainer-sampling fix (v1.0 samples only 21 of 70). None is in scope; the RAM layout otherwise identical. Full attribution: `docs/revision-diff.md`.

**Design rule — revision-agnostic by construction:** RAM-only implementations wherever possible. Unavoidable ROM calls/table reads go through a small SRAM indirection table populated at install time from `$014C` — **only if** the symbol diff shows a used address differs. Budget ≈20–40 bytes if any differ, zero if none do. The genuine unknown is whether TimoVM's ACE setup byte sequences embed revision-dependent ROM addresses; if so, the install guide branches, not the program.

### 1.2 Hard constraints (non-negotiable)
1. **No ROM modification.** GameShark codes are a prototyping/verification tool in an emulator only.
2. **Every install step performable on original hardware** with no link cable, second console, or dumper.
3. **All original content stays accessible.** A host map used for a restored map must load normally unless entered through a custom warp.
4. **SRAM is the binding budget** (~1 KB reliably free; §4.4). Every feature accounts for its bytes.
5. **Installability is a budget.** Every program byte *can* be typed by hand and the guide must stay feasible. SRAM (constraint 4) is the harder limit in practice; minimize bytes for both reasons.
6. **Never execute code from SRAM (`$A000–$BFFF`).** Confirmed by the GCRI author and by BBMenuSE for Gen 1: the (C)GB emulator used by 3DS VC cannot execute from the SRAM window, and Crystal itself cannot either. L2 routines are *stored* in SRAM, *copied* to WRAM, *executed* from WRAM. Independently required because MBC registers are write-only (§4.3).

### 1.3 Target platforms
Original GBC, GBA/SP, Game Boy Player; ModRetro Chromatic (primary test device) and Analogue Pocket; **3DS Virtual Console** (v1.1). VC notes: (a) TimoVM's guides have VC-specific steps — bad clone via the Hall of Fame SRAM glitch, some codes cartridge-only; (b) the VC emulator already sets the GS Ball flag on Hall of Fame entry, so feature 1 is a no-op there (keep idempotent, say so in the guide); (c) VC has a forward path to Bank/HOME, so injected Pokémon must be legal (seed DVs, legal species/level/moves); (d) RTC is emulated; (e) Printer disabled; (f) **VC save container:** a GCL thread mentions a 16-byte footer to reach `$800F`, confirmed: a Checkpoint export of the user's VC save carries the footer, and after an online converter stripped it the file is exactly `$8000` bytes and verifies clean with `patcher.py`, i.e. identical to the cartridge layout. **Characterised 2026-09-04:** a raw Checkpoint export is `$8010` bytes = the four banks + a 16-byte footer whose contents vary between saves (opaque; all-zero in one, non-zero in another). **Patcher requirement:** accept the raw export directly, patch the first `$8000` bytes, re-attach the footer unchanged. **Unresolved contradiction (2026-09-04):** the user's title is the **eShop** release (so v1.1 and the official patch with the `Enable_GS_Ball_mobile_event` hook), yet their save with 13 Hall of Fame entries has `sGSBallFlag` = `sGSBallFlagBackup` = 0 and no GS Ball events set. Either those entries did not happen on the 3DS (imported save), or the hook does not fire as documented. **Experiment:** enter the Hall of Fame once more on the 3DS, export with Checkpoint, read `.sav` byte `0x3E3C`. If still 0, correction 7 and §1.3(b) are wrong and feature 1 is needed on VC too; raise on the GCRI thread; writing a VC save back needs a modded 3DS and a save manager (out of scope; link to tools).

Per-frame timing-sensitive code must be validated on original GBC, the Chromatic, and VC.

### 1.4 Development tooling and working style
- **Save read/write:** GBxCart RW ordered, not yet here. Until then, **FGBWEB** (https://germaneguise.github.io/fgbweb/) turns the Chromatic into a cartridge reader over USB-C (WebUSB, Chrome/Edge). It loads archival gateware into the FPGA's SRAM (nothing flashed; power cycle restores). "Restore save" overwrites with no undo — verify backups first; disconnect explicitly. FlashGBX-compatible `.sav` files.
- **Assembler wrapper:** evaluate M4n0zz's QuickRGBDS (https://github.com/M4n0zz/QuickRGBDS), used to build BBMenu, before rolling our own build scripts.
- **Teaching mode throughout.** The user's background is Python; no prior GBZ80/RGBDS/Game Boy hardware knowledge. Explain each concept before first use, annotate assembly generously, prefer Python for every tool not forced into assembly, state rejected alternatives. The user should finish able to read and modify the payload unaided. (Session protocol: `/teach-and-code` — the user writes anything carrying a new concept.)
- **Community:** the GCRI Discord is where TimoVM, M4n0zz, aestellic, CasualPokePlayer and the Gen 2 author work; a thread is open. **Ask there before spending days on an unresolved Phase 0 unknown.** Replies arrive as plan updates.

---

## 2. Scope: prioritized feature list

Priority decides *what is in scope*; dependencies decide build order (§6). Not everything will fit.

| # | Feature | Feasibility (0–5) |
|---|---|---|
| 1 | GS Ball event auto-triggers after Elite Four (VC behavior on cartridge) | 5 |
| 2 | Reusable custom encounter-table framework (first use: the five G/S-exclusive families restored to one location each in Crystal, low rate) | 4 |
| 3 | Viridian Forest gets an injected encounter table | 4 |
| 4 | Dead-air radio frequencies play unused tracks, with station names if cheap | 4 |
| 5 | "Custom Settings" menu at home (bedroom PC) with toggles: HM field moves without teaching (needs a mon that *can* learn it); B to Run | 5 (menu) / 3 (each toggle) |
| 6 | Reusable roaming framework, Johto and Kanto (starters in Johto; bird trio in Kanto) | 4 |
| 7 | Roamer release gated on events: weak-vs-yours starter from game start; strong-vs-yours after E4 once the first is caught/KO'd | 5 |
| 8 | Reusable static-encounter framework with injected overworld sprite (Mew & Mewtwo in Kanto) | 5 |
| 9 | Unused-trainer gauntlet, no healing, from the Battle Tower | 4 |
| 10 | Gauntlet rewards: first win → Tentacool Doll; full clear → Unown Doll | 5 |
| 11 | Custom default Trainer House opponent | 5 |
| 12 | Trainer House win → Pikachu Bed | 5 |
| 13 | Restore Test Cave with the Cerulean Cave encounter table | 3 |
| 14 | Mewtwo static encounter in Test Cave | 3 |
| 15 | Restore Mt. Silver Exterior (FUJI); cave entrance warps to Unused Cave with a Mew static encounter | 3 |
| 16 | Restore Haunted House as one floor with a custom encounter table | 3.5 |
| 17 | Move Relearner as an injected NPC in Kanto | 4 |
| 18 | Restore Safari Zone with encounter data | 4 |
| 19 | Bug Catching Contest rules inside the Safari Zone | 3 |
| 20 | Continuous Repel with "use another?" prompt | 4 |
| 21 | Custom Settings additions: Fast & Instant text; Infinite TMs; Turn Off Phone | 5 |
| 22 | Professor with all 251 caught unlocks all Mystery Gift decorations | 4 |
| 23 | *(stretch)* Second Haunted House floor | 3 |
| 24 | *(stretch)* Trainer Rankings counters maintained by the payload, shown via Custom Settings | 3 |
| 25 | *(stretch)* All Haunted House floors | 2 |

**Decisions already made (do not relitigate):** 3 roamer slots per region (Kanto = Articuno/Zapdos/Moltres; Johto 1–2 = Raikou/Entei, 3 = starter roamer, level 5). Existing overworld sprites only. Custom Settings replaces the bedroom PC interaction (PC / SETTINGS submenu OK; PC functions remain at every Pokémon Center). HM toggle keeps badge requirement. Move Relearner is an NPC, not a menu item.

### 2a. Install bundles (approved by the user 2026-09-07)

The program is **modular**: each bundle is one or more Mail Writer codes (or one patcher checkbox) and users pick which to install. Frameworks are pulled in automatically by the features that need them. Every bundle has a **fixed SRAM address** recorded in `docs/sram-map.md`'s ledger (simplicity over packing; skipped bundles leave holes), and registers with the kernel's feature table. The full inventory is not expected to fit at once (see budget note below); modularity is what makes that acceptable.

**Tier 0 — prerequisite (TimoVM's):** Mail Writer + Special Call/OAM DMA framework = patcher options (a) and (b).

**Tier 1 — `core` (scope fixed by the user 2026-09-10; intended to be offered to TimoVM as an updated base setup):** exactly two things and nothing else. (1) **Fix his framework's special-call bugs**: save-time parking (done, verified), bike-shop call replay, nurse Pokérus branch (`docs/core-design.md` hooks 1–3; these are the only two places in the game that misread the arm byte, plus the save-time loss). (2) **Slot 4, the extended slot**: four bytes of his framework redirect his two calls to our loader (`$DA47`) and per-frame stub; the loader copies `core` from SRAM into WRAM bank 4, and `core` in turn loads and calls a fourth, ~1 KB slot with a per-frame *and* a per-step (main-thread) entry (`docs/core-design.md`, "Slot 4"). Slots 1–3 untouched; his Mail Writer, bootstrap, dispatcher are byte-identical to the wiki. Patcher: `install-timovm` and `install-dma-hijack` stay as they are; `install-uc-core` is an add-on that changes the four bytes. Whether it becomes one combined code is for after the discussion with TimoVM.

**Tier 1b — UC Runtime (approved 2026-09-10; always installed with any bundle; ours, not offered to TimoVM):** the slot-4 code. Feature registry walked per frame and per step, settings/custom-flag block, WRAM event-table repoint primitive (§4.2), repair entry, bundle loading from the other SRAM gaps.

**Tier 2 — frameworks (never offered alone):**

| Framework | Provides | Pulled in by |
|---|---|---|
| `enc` | encounter framework §7.2 | version exclusives, Viridian Forest, Test Cave, Haunted House, Safari Zone |
| `menu` | Custom Settings menu §7.4 | every toggle |
| `roam` | roaming framework §7.7 | birds, starters |
| `npc` | static encounter + NPC injection §7.8 | Mewtwo, Mew, Move Relearner |
| `map` | map-header hijack §7.6 | Test Cave, Mt. Silver exterior, Haunted House, Safari Zone |
| `battle` | trainer-battle start + win detection | gauntlet, Trainer House reward |

**Tier 3 — user-selectable feature bundles:**

| Bundle | Scope # | Requires |
|---|---|---|
| GS Ball after Elite Four | 1 | core |
| Radio: unused tracks on dead air | 4 | core |
| Professor unlocks Mystery Gift decorations at 251 | 22 | core |
| Trainer House custom opponent | 11 | core (data only) |
| Version-exclusive encounters — the five families absent from Crystal (Mankey, Vulpix, Mareep, Girafarig, Remoraid), **each at exactly one location, at a low rate (TBD)**, via species substitution on that map's vanilla encounters; one bundle | 2 | enc |
| Viridian Forest encounters | 3 | enc |
| HM field moves without teaching | 5 | menu |
| B to Run | 5 | menu |
| Fast and instant text | 21 | menu |
| Infinite TMs | 21 | menu |
| Turn Off Phone | 21 | menu |
| Continuous Repel | 20 | menu |
| Kanto roaming birds | 6 | roam |
| Johto roaming starters | 6, 7 | roam |
| Test Cave | 13 | map, enc |
| Mewtwo in Test Cave (separate code; guide recommends both) | 14 | Test Cave, npc |
| Mt. Silver exterior and Unused Cave | 15 | map |
| Mew in Unused Cave (separate code; guide recommends both) | 15 | Mt. Silver bundle, npc |
| Haunted House | 16 | map, enc |
| Haunted House extra floors | 23, 25 | Haunted House |
| Safari Zone | 18 | map, enc |
| Bug Contest rules in the Safari Zone | 19 | Safari Zone |
| Move Relearner NPC | 17 | npc |
| Battle Tower gauntlet | 9 | battle |
| Gauntlet rewards | 10 | gauntlet |
| Trainer House win reward | 12 | battle |
| Trainer Rankings display | 24 | menu |

**Budget note.** Persistent budget is 2831 B of SRAM (`docs/sram-map.md`); WRAM bank 4 is runtime space only, reloaded from SRAM at each reinstall, so every installed byte lives in SRAM. Nothing has been measured yet; rough guesses (frameworks ~1.1 KB, features ~1.5–2 KB now that version exclusives are five substitution entries rather than full tables) suggest the full set is near or over the budget, which is the handoff plan's own expectation ("not everything will fit"). `budget.py` replaces guesses with numbers per bundle as each is assembled; compression of tables into bank 4 is a fallback if needed.


---

## 3. Corrections to naive assumptions

1. **The swarm hook is not a general injection path.** `_SwarmWildmonCheck` passes the ROM swarm table to `LookUpWildmonsForMapDE`; only Dark Cave and Route 35 match. The encounter framework is payload-owned (§7.2).
2. **"Unused mobile SRAM" does not exist here.** `sram.asm` puts mobile data and Trainer Rankings in SRAM banks 4–7, which exist only on the Japanese MBC30 cart. International Crystal is MBC3 with 4 banks; the Trainer Rankings routines are stubbed.
3. **Cut maps have no map-table entries or event data.** Restored via the map-header hijack (§7.6), not by warping to an ID.
4. **FUJI (2A:5A37) renders acceptably** with an older blockset 01 that still ships in Crystal. Minor tile mismatches, not corruption. It is not the Space World '97 map.
5. **Trainer Rankings counters are dead** in the international build.
6. **No `BATTLETYPE_SAFARI` in Gen 2.** `BATTLETYPE_CONTEST` and the bug-contest status bits are the mechanism for feature 19.
7. **The VC GS Ball fix is not a ROM patch.** The emulator writes the save on Hall of Fame entry. Feature 1 reproduces it.
8. **Dead-air radio is silence, not static.** `NoRadioStation` plays `MUSIC_NONE`.
9. **Code cannot execute from SRAM** on Crystal or on VC (confirmed, §1.2.6). Everything runs from WRAM/HRAM.
10. **Map/scene scripts do not run every frame** (e.g. not in battle). `wCurMapSceneScriptsPointer` is not a primary hook; at most an overworld-only supplement. The OAM DMA hijack is the per-frame entry, full stop.
11. **Handoff label names were stale.** Current pokecrystal calls the GS Ball byte `sGSBallFlag` (`01:BE3C`) and its mirror `sGSBallFlagBackup` (`01:BE44`); the constant is `GS_BALL_AVAILABLE EQU $b` in `constants/battle_tower_constants.asm`. `sMobileEventIndex` / `EnableGSBallScene` do not exist in the repo (the latter comes from a pret wiki tutorial). Expect more of these; `symdiff.py` reports unresolved names.
12. **The WRAM bank register is readable.** pokecrystal calls it `rWBK` (`$FF70`, SVBK) and itself does `ldh a, [rWBK]` / `ldh [rWBK], a` save-restore in `home/copy_tilemap.asm` and `home/game_time.asm`. Unlike MBC registers, the DMA hook can save/switch/restore it safely (§4.3).

---

## 4. Architecture

### 4.1 Layers
```
┌───────────────────────────────────────────────────────────────┐
│ L0  ACE entry + persistence  (TimoVM framework, verified in    │
│     the user's save; layout in docs/timovm-footprint.md).       │
│     Required layers: Fast 0x1500 v2 (Mail Writer) + Special    │
│     Call/OAM DMA framework. Optional: RAM Writer. Our L1 stub   │
│     is the TENANT OF HIS SLOT 3 ($DAAB, 17 B): switch to the    │
│     kernel's WRAM bank, call it, restore bank 1, ret. Slots 1-2 │
│     stay his (user codes keep working). Main-thread reinstall   │
│     (SRAM→WRAM copy) extends his Special Call routine into the  │
│     free saved padding at $DA47–$DA71 (43 B). Decided 2026-09-04│
│     bad clone → 0x1500 control-code ACE → box-name bootstrap   │
│     → Mail Writer → install → OAM DMA hijack at HRAM $FF80     │
│     → Special Call ACE re-installs the hook after every reset  │
│     and COPIES the kernel image SRAM → free WRAM bank           │
├───────────────────────────────────────────────────────────────┤
│ L1  Per-frame stub inside the DMA hook (HRAM)                  │
│     TINY: save rWBK, switch to the kernel's WRAM bank, call    │
│     the dispatcher, restore rWBK. Dispatcher early-outs on     │
│     cheap state checks. Per-frame features and ALL battle-     │
│     adjacent logic live here (encounter substitution, roamer   │
│     battle-end tracking, gauntlet chaining, B-to-run, repel,   │
│     step counting, map-load detection → schedules L2).         │
├───────────────────────────────────────────────────────────────┤
│ L2  Main-thread routines, executing from the kernel WRAM bank  │
│     Invoked via `callasm` scripts (NPCs, PC menu, warps) or    │
│     scheduled by L1. Safe to OpenSRAM/CloseSRAM here. Menus,   │
│     relearner, map-header patching, table builders, gauntlet.  │
├───────────────────────────────────────────────────────────────┤
│ L3  Data                                                       │
│     Persistent image + settings + custom flags in SRAM.        │
│     Working tables (encounter, roamer shadows, event tables)   │
│     in the kernel WRAM bank, rebuilt from SRAM at reinstall.   │
└───────────────────────────────────────────────────────────────┘
```

### 4.2 The three primitives
1. **Per-frame WRAM watch-and-write** (L1): observe state, rewrite RAM at the right moment (text delay, encounter variables, roamer slots, repel counter).
2. **WRAM pointer repointing for map events** (L2): warp/coord/bg/scene tables are reached via `wCurMap*Pointer`; build custom tables in RAM and repoint. Object events are *copied* by `ReadObjectEvents` into `wMapObjects`, so inject NPCs by writing a 16-byte struct into a free slot.
3. **`callasm` scripts** (L2): script pointers may target WRAM; `callasm` jumps to arbitrary main-thread code, so NPCs, the PC menu and custom warps can use the game's own menu routines (`LoadMenuHeader`, `VerticalMenu`, `PlaceString`, `JoyWaitAorB`).

### 4.3 The WRAM bank swap (new, load-bearing)
The GBC has eight 4 KB WRAM banks; `$D000–$DFFF` shows bank 1–7 selected by `rWBK` (`$FF70`), which is **readable**. So L1 can `ldh a,[rWBK]; push; ld a,N; ldh [rWBK],a; call Kernel; pop; ldh [rWBK],a` with no write-only hazard. A free bank is 4 KB of VC-compatible execution + staging space — several times the SRAM budget. **Precedent:** TimoVM's own OAM DMA hook body reads `rWBK` and only calls into bank-1 WRAM when bank 1 is mapped (`docs/timovm-footprint.md`). Not battery-backed: the program persists in SRAM and is copied in at Special Call reinstall time. Fallback if no full bank is free: a small trampoline beside the hijack into a smaller free WRAM region.

**Survey complete (static, 2026-09-05, `docs/wram-banks.md`):** **bank 4 (`$D000–$DFFF`, 4096 B) is written only by `mobile/mobile_5f.asm`, and the only two paths into that code (a `special` no script calls, and the `<MOBILE>` text character no text uses) are unreachable in English Crystal. Adopt bank 4 as the kernel bank.** Second candidate: bank 2 tail `$D191–$DFFF` (3695 B; its five writers are all label-bounded). Bank 5 gaps (112/926/950 B) are reserve only. Two supporting facts: boot's `ClearWRAM` wipes bank 1 only (retail `jr nc` bug), so nothing in-game ever clears bank 4, though hardware power-on leaves it undefined and the SRAM→WRAM reinstall stays mandatory; and every VBlank handler calls `hTransferShadowOAM` before its `ei`, so L1's bank swap inside the hook is uninterruptible. Reinstall copy cost ≈ 13 M-cycles/byte (2831 B ≈ 35 ms, main thread). Remaining: BGB write-watch on `04:D000–DFFF` and confirming eight-bank WRAM on VC/Pocket/Chromatic.

### 4.4 Storage plan (Phase 0 produces the exact map)
- **Persistent image (SRAM):** kernel code + data tables + settings bits + custom flags. **Inventory (`docs/sram-map.md`):** the linker leaves **3020 bytes** unallocated in banks 0–3 (`00:AC6B–B1FF` 1429, `00:BF12–BFFF` 238, `01:BE57–BFFF` 425, `02:BE30–BFFF` 464, `03:BE30–BFFF` 464), none checksummed, and none written across a 13-Hall-of-Fame VC save or a fresh mGBA save. TimoVM's setup (installed on the complete VC save) does not occupy any gap. **Reserved: `03:BE2F–BEEB` (189 B) for TimoVM's RAM Writer** (optional but recommended for on-hardware debugging); allocate the other four gaps first. **Static audit complete (2026-09-04): all five gaps are free** — every SRAM write in the retail build is label- and constant-bounded; the only whole-bank write is the user-initiated delete-save, which erases the program (guide must say so). Sentinel play is optional. Available: 2831 B after the RAM Writer reservation. SRAM still bounds *total program size*, but the budget is ~3 KB, not ~1 KB.
- **Bootstrap/reinstall store:** none of ours — the loader at `$DA47`, reached from TimoVM's reinstall (two call-target bytes changed), copies the image from SRAM on the main thread (`docs/core-design.md`).
- **Runtime code + working data:** WRAM bank 4 (§4.3, `docs/wram-banks.md`); bank 2 tail as second choice. Fallback: the Mail Writer payload area from `wOtPartyCount` (≤428 B, clobbered by battles — install-time staging only).
- **Custom flags:** a small block in free SRAM; use unused `wEventFlags` bits only where a game mechanism *requires* an event-flag index (object visibility). **Finding (2026-09-04):** `constants/event_flags.asm` defines no flags in `$108–$257` (336 flags = `wEventFlags` bytes `$21–$4A` = `$DA93–$DABC`) — and that hole is exactly where TimoVM's constant-effect slots 2 and 3 live. The file has three more unused blocks that do **not** overlap his slots: flags 261–263 (3), **833–999 (167)** and **1484–1599 (116)**. Take object-visibility flags from 833–999 / 1484–1599 and leave 264–599 to his slots. Decide exact indices in Phase 1. Unused WRAM per Data Crystal: `$DFF5–$DFFF`, `$CFD8–$CFFF` — verify.
- **Never touch SRAM from the DMA hook.** All SRAM work happens in the kernel's Step context (main thread, inside TimoVM's reinstall, interrupts off, SRAM closed). Frame code touches WRAM only, via the WRAM0 accessors — never HRAM scratch (`hTempBank`/`hFarByte` are shared with the main thread's `GetFarByte`). Load cost ≈ one frame, once per power-on; measure in BGB.

### 4.5a Resilience — keeping the hook alive (`docs/resilience.md`)
The framework lives or dies on `wSpecialPhoneCallID` (`$DC31`, saved) holding `$9C`. Saving while a story call is queued, then resetting, leaves the hook down after that call fires. **Decision (2026-09-07): in scope — save-time parking.** Every save path calls `PauseGameLogic` (`wGameLogicPaused` = 1) before the "SAVING..." text, so the per-frame code sees a save coming; if a story ID is queued it parks it in one byte of saved WRAM and restores `$9C`; once the pause ends the same per-frame code puts the parked ID back so the vanilla path fires it on the next step. Story calls are never suppressed. A `core` Step hook (main thread, per step) replicates the bike-shop trigger TimoVM's arm byte suppresses (confirmed 2026-09-07). Cold case (hook already down at save time) is not coverable and keeps the repair paths: repair TM (Phase 1 research), TM15 → Mail Writer reactivate code, patcher one-click repair. **Future scope:** the Pokérus nurse branch (`checkphonecall` treats `$9C` as a pending call).

### 4.5 Special Call ACE interaction
Reinstall relies on the story-driven *special* call system (`wSpecialPhoneCallID`), not random calls. "Turn Off Phone" (§7.4) suppresses **random** calls only. Verify independence before shipping either.

---

## 5. Development environment

### 5.1 Setup (Phase 0)
1. ✅ pret/pokecrystal built for both revisions; hashes match `roms.sha1`. Symbol diff → `docs/facts.md` (in progress; `tools/symdiff.py`, user-written). Have the user archive cart ROM + save with FGBWEB and confirm which revision they hold.
2. ✅ RGBDS 1.0.3 (matches `INSTALL.md`).
3. Emulators: **BGB** (best debugger, GameShark entry; run under Wine — Wine Stable is installed) and **mGBA** (installed; Lua scripting for automated tests). SameBoy optional.
4. ✅ Repo layout (§5.3).
5. Build `patcher.py` (§5.2) before any feature.
6. **Prior-art reading (required before kernel design):** BBMenu / BBMenuSE README, `Features.md`, `Logic.pdf`, `Assembly/`, `Installation/`; cilerba's ACE script; QuickRGBDS.
7. **WRAM bank survey** (§4.3): enumerate `WRAMX` sections, write-watch candidates in BGB, audit `rWBK` writes. If a free bank exists, adopt the §4.3 design; measure the reinstall copy cost; confirm the Chromatic, Pocket and VC implement full GBC WRAM banking.
8. **SRAM-execution sanity test on VC** (4-byte routine in SRAM, called from WRAM, check the side effect) — outcome treated as known (cannot execute).
9. **VC save container format** research for the patcher.
10. Reproduce TimoVM's setup end to end in BGB, following his guides literally. Document the **divergence point** (first step where our install differs), not the steps.
11. Write the L1 stub + dispatcher skeleton; measure cycle cost; establish the per-frame budget empirically.
12. Decide web patcher implementation: JS/TS port vs Pyodide, by which is easier to keep byte-identical with `patcher.py`.

### 5.2 Save-file patcher (deliverable)
`tools/patcher.py <input.sav> <build/payload.bin> <output.sav>` is the reference implementation and dev tool; `web/` is a client-side static site (GitHub Pages, FGBWEB model) sharing its logic. Both:
- Detect a Crystal save (both USA revisions share the layout); detect and handle the VC container; refuse non-Crystal/corrupt saves with a clear message.
- Option (a) **TimoVM ACE setup only**: exactly the three persistent pieces of the Fast 0x1500 ACE v2 clean-up state (`docs/timovm-footprint.md`, ~57 bytes in `wPlayerData`), verified against the user's save. No box names or glitch Pokémon involved. RAM Writer / OAM DMA hook / Special Call are separate, later layers. Option (b) **Full SRAM hack**: (a) plus `core` and any selection of bundles (§2a); each bundle is a checkbox in the web patcher and a numbered code group in the guide.
- Byte-for-byte equivalence: (b) == following the hand-install guide to the end; (a) == completing TimoVM's guide. Guide, Python patcher and web patcher are all generated from the same build artifact; **CI asserts the three agree.**
- Recompute every checksum touched (`sChecksum` at `01:AD0D`, `sBackupChecksum` at `00:BF0D`, plus any box/region checksums found in Phase 0). Never overwrite the input; always a new download; show a summary of changes.
- Show the guide's warnings (back up first; VC write-back needs a modded 3DS + save manager, out of scope, link tools; Chromatic can write via FGBWEB).
- Preconditions per option (TimoVM's setup assumes certain progression/items): synthesize safely if possible, otherwise validate and report what's missing.
- Optional one-time test-state writes for dev (set `EVENT_BEAT_CHAMPION_LANCE`, give Park Balls, place the player).
- Stretch: FGBWEB is open source (WebUSB); evaluate a single read/patch/write flow via a Chromatic. Feasibility note only.

### 5.3 Repo layout
```
pokemon-crystal-sram-hack/
  README.md                      (this plan, kept current)
  docs/
    labels.txt                   (§8 label list → symdiff input)
    facts.md                     (verified addresses/labels, revision-tagged)
    sram-map.md                  (free-SRAM inventory + allocation ledger)
    wram-banks.md                (WRAM bank survey result)
    languages.md                 (FR/DE/IT/SP/JP port notes for `core`)
    install-guide/               (final deliverable, generated + hand-edited)
  pokecrystal/                   (git submodule, built)
  src/
    l1_dispatcher.asm
    l2/                          (one file per feature)
    tables/                      (encounter, roamer, event tables)
    bootstrap/                   (box-name / mail-writer stage code)
  tools/
    patcher.py                   (reference patcher)
    mailcode.py                  (write list → installer payload, hex for TimoVM's converter)
    encoders/                    (charset ↔ byte encoders)
    budget.py                    (SRAM + install-keystroke budget per feature)
    symdiff.py                   (resolve labels in both .sym files)
  web/                           (static client-side patcher, GitHub Pages)
  tests/
    bgb/                         (save states, cheat lists, manual scripts)
    mgba-lua/                    (automated checks)
    equivalence/                 (guide == patcher.py == web patcher)
  build/
```

### 5.4 Build pipeline
One build artifact (`build/payload.bin` + metadata) feeds: the install-guide generator (in-game action sequences, chunked, per-chunk checks; keystroke count is a first-class metric in `budget.py`), `patcher.py`, the web bundle, and premade saves. Encodings from the Glitch City Wiki (Mail Writer, Crystal box name codes, Big HEX List).

### 5.5 Verification protocol (every feature)
1. Prototype the RAM effect with GameShark codes in BGB.
2. Implement in assembly; load via the patcher; test in BGB with the debugger.
3. Hardware: FGBWEB archive (dated backup) → restore patched → play on the Chromatic → archive and diff.
4. Regression: full `tests/` checklist for earlier features.
5. **Both revisions**, every feature (`pokecrystal.gbc` and `pokecrystal11.gbc`).
6. Original GBC and 3DS VC for timing-sensitive per-frame code. VC doubles as the v1.1 hardware test.
7. Equivalence test: guide == `patcher.py` == web.

---

## 6. Build order

**Phase 0 — Foundations.** §5.1 items 1–12. Produces `docs/facts.md`, `docs/sram-map.md`, `docs/wram-banks.md`, `patcher.py`, `install_gen.py`, `budget.py`, the L1 stub/dispatcher skeleton, and the TimoVM divergence point. **Web patcher option (a) can ship as soon as TimoVM's setup is reproduced and the patcher emits it.**

**Phase 1 — `core` + one-time SRAM writes** (1, 11). Validates the SRAM-write path and the fixed address map. Option (b) starts here and grows one bundle at a time (§2a).
**Phase 2 — Encounter framework + first uses** (2, 3).
**Phase 3 — Radio** (4).
**Phase 4 — Custom Settings menu + simple toggles** (5-menu, 21). Establishes bg-event pointer swap + `callasm` + game-menu pattern reused by 8, 17, 9.
**Phase 5 — HM toggle, B to Run** (5-toggles).
**Phase 6 — Roaming framework** (6, 7).
**Phase 7 — Static encounters + NPC injection** (8). Reused by 17 and the map restorations.
**Phase 8 — Trainer House + gauntlet + rewards** (9, 10, 12).
**Phase 9 — Map-header hijack framework**, then 13, 14, 15, 16, 18.
**Phase 10 — Remaining** (17, 19, 20, 22).
**Phase 11 — Stretch** (23, 24, 25) if `budget.py` shows headroom.
**Phase 12 — Final install guide + web release** (§9). Draft incrementally from Phase 1.

---

## 7. Feature specifications
Labels from pret/pokecrystal; parenthesised addresses are research anchors to confirm in `docs/facts.md`. Anything battle-adjacent runs from the DMA hook (correction 10).

### 7.1 GS Ball after Elite Four (1)
- **Mechanism:** the Goldenrod Pokémon Center script checks the mobile-event byte for `GS_BALL_AVAILABLE` (`$0b`). The byte is `sGSBallFlag` (`01:BE3C`), outside the checksummed save block, mirrored to `sGSBallFlagBackup` (`01:BE44`) — **write both**. Code shape: `ld a, BANK(sGSBallFlag) / call OpenSRAM / ld a, GS_BALL_AVAILABLE / ld [sGSBallFlag], a / ld [sGSBallFlagBackup], a / jp CloseSRAM`. GameShark corroboration: `010B3CBE`. Verify how/when the game restores from the backup.
- **Hook:** L1 detects the 0→1 edge of `EVENT_BEAT_CHAMPION_LANCE` and schedules an L2 write (or perform during the Hall of Fame sequence when SRAM is idle).
- **Storage:** 1 custom flag bit. **VC:** already done by the emulator; idempotent no-op.
- **Acceptance:** after credits, leaving the Goldenrod Center triggers the GS Ball script; Kurt → one day → Ilex shrine → L30 Celebi.

### 7.2 Encounter framework (2) + Viridian Forest (3)
- **Mechanism (payload-owned):** on owned maps, L1 counts steps, rolls against a per-map rate, selects species/level from a custom table (pret's 47-byte `def_grass_wildmons` layout: 3 rates + 7 slots × 3 times of day), then sets `wTempWildMonSpecies`, `wCurPartyLevel`, `wBattleType = BATTLETYPE_NORMAL`, `wBattleMode = WILD_BATTLE` and lets the overworld loop start the battle. On maps with a vanilla table (G/S exclusives), substitute `wTempWildMonSpecies`/`wCurPartyLevel` during the battle transition — `LoadEnemyMon` reads them after `DoBattleTransition` (~60 frames), from the DMA hook. Prefer substitution on vanilla maps, payload-rolled on empty maps (Viridian Forest, cut maps, Safari).
- **Reference data:** `data/wild/johto_grass.asm`, `kanto_grass.asm`, `*_water.asm`, `data/wild/probabilities.asm`; G/S tables from pret/pokegold; orphaned `CERULEAN_CAVE_1F` water data for feature 13.
- **Storage:** 47 B per owned map; consider a 17-byte single-time-of-day variant for cut maps. Version exclusives (decided 2026-09-07): one substitution entry per family — map group, map number, species, level, chance — ~6 B each, five entries, no tables.
- **Risks:** only on walkable overworld tiles with no script running; respect Repel and the no-encounter status flag.
- **Acceptance:** Viridian Forest encounters at the configured rate from the custom table; Route 2/Ilex unchanged; Repel works.

### 7.3 Radio (4)
- **Mechanism:** `UpdateRadioStation` walks `RadioChannels` comparing each frequency byte (stations at 16, 28, 32, 40, 52, 64, 72, 78, 80) to `wRadioTuningKnob` (even 0–80); no match → `NoRadioStation`. Unused tracks: `$52`, `$53` (G/S opening demos), `$5E` (mobile menu), `$5F` (mobile connection), `$66` `MUSIC_MOBILE_CENTER` — confirm in `constants/music_constants.asm`.
- **Hook:** L1, only while the radio card is open: chosen dead-air value and marker clear → `call PlayMusic`, set the marker in `wPokegearRadioMusicPlaying`. Station name: `@`-terminated string into the name box respecting `hBGMapMode`; ship nameless if it tears.
- **Acceptance:** chosen frequencies play; vanilla stations unaffected; leaving the card restores map music.

### 7.4 Custom Settings menu (5-menu, 21)
- **Mechanism:** on load of `PLAYERS_HOUSE_2F`, copy the bg-event table to RAM, replace the PC entry's script pointer with a RAM script (`callasm <addr>` / `end`), repoint `wCurMapBGEventsPointer`. The target draws a menu with game routines. **PC** jumps to the vanilla PC script (ROM, map script bank); **SETTINGS** opens toggles, persisted as bits in the SRAM flag block.
- **Toggles:** Fast/Instant text (`wOptions` low 3 bits, `TEXT_DELAY_MASK`; instant = force `wTextDelayFrames = 0` per frame), Infinite TMs (snapshot counts; restore after teach, or set 99), Turn Off Phone (pin the random-call delay counter high — verify label; do **not** clear `wPhoneList`).
- **Acceptance:** vanilla PC works via submenu; settings survive reset; behaviors change as toggled; story calls still arrive.

### 7.5 HM without teaching and B to Run (5-toggles)
- **HM:** `TryCutOW` etc. call `CheckPartyMove` (input `d` = move; success = carry clear + `wCurPartyMon`) then `CheckEngineFlag` with the badge id. Keep the badge check. Replace the outcome with an eligibility loop: per non-egg member set `wCurPartySpecies`, `wPutativeTMHMMove`, predef `CanLearnTMHMMove` (`c` ≠ 0 eligible), first hit → `wCurPartyMon`. Object-path moves are on-demand; L1 detects the interaction frame (facing object type + A) and just-in-time writes the move into a genuinely empty slot, clearing it the same frame after the check. Fly/Flash: entries in Custom Settings running the loop then `FlyFunction`/`FlashFunction`. Prior art: Skeetendo "HM Moves Without Teaching" (7531).
- **B to Run:** `DoPlayerMovement.DoStep` picks `STEP_WALK`/`STEP_BIKE` from `wPlayerState`. Use the queued-step-byte rewrite, not `PLAYER_BIKE`: `wBikeStep` only advances while `wPlayerState == PLAYER_BIKE`, so the fallback would generate spurious bike-shop calls (now handled by park-and-replay, `docs/resilience.md`, but still unwanted) on top of the bike-music/tile side effects.
- **Risks:** an injected HM must never be present when a battle or link snapshot reads the party.
- **Acceptance:** Surf with untaught Lapras + badge works; fails without badge; Fly from menu; B doubles speed, no bike music.

### 7.6 Map-header hijack framework (13–16, 18)
- **Mechanism:** `CopyMapAttributes` copies the header into WRAM per map load: `wMapTileset` (`$D199`), `wEnvironment`, `wMapAttributesPointer`, `wMapBorderBlock`, `wMapHeight`, `wMapWidth`, `wMapBlocksBank`, `wMapBlocksPointer` (`$D1A1`), `wMapScriptsBank/Pointer`, `wMapEventsPointer`, `wMapConnections`. Event tables via `wCurMap*Pointer` (`$DBFB–$DC08`). A custom warp injected into a real map sets a **mode byte** (SRAM) and warps to a **host map**; on the host's load, *only if mode set*, L2 overwrites block pointer/dimensions/tileset/border/environment and repoints the warp table (entry + exit). Mode clear → host loads untouched.
- **Re-apply rule:** any full map load reverts the patch; L1 re-asserts every frame while on the host with mode ≠ 0 (idempotent). Re-assert on the first post-battle frame.
- **Cut-map data (bank:offset, TCRF; verify):** Test Cave `CAVE_TES` 2B:455F (entrance block 16); Unused Cave `ID0_01` 37:4000; Mt. Silver Exterior `FUJI` 2A:5A37 (blockset 01); Haunted House `YASHI_1` 2B:744D, `YASHI_2` 2B:755B, `YASHI_3` 2B:7669 (attic), `YASHI_B1` 2B:7777. Floors 1–3 are 270 B each → 15×18 or 18×15. Dimensions are inferred from length and confirmed by binary-searching the width in BGB.
- **Storage:** per map: mode logic + ~8 header bytes + 5 B/warp + optional encounter table.
- **Acceptance:** enters via custom warp, renders navigably, exits via custom warp, host unchanged when entered normally.

### 7.7 Roaming framework (6, 7)
- **Mechanism:** `wRoamMon1/2/3` (`$DFCF/$DFD6/$DFDD`), 7 B each: species, level, map group, map number, HP, DVs(2). `InitRoamMons` fills 1–2 (Burned Tower); Suicune is scripted so **slot 3 is free**. `_MoveRoamMons` uses the ROM `RoamMaps` table (Johto only); encounter check compares slot map to current map; battle end matches by species, zeros on catch/KO, saves HP on flee (DMA-hook territory).
- **Region swap:** Johto shadow (21 B) and Kanto shadow (21 B) in SRAM; on region change (`RegionCheck` / map group) swap slots ↔ shadows; copy pre-release slots (species 0) faithfully.
- **Kanto movement:** `RoamMaps` lacks Kanto; L1 re-asserts Kanto roamer maps from a payload-owned route list after each map load. Verify `_MoveRoamMons` behavior for absent maps.
- **Starter state machine (2 bits):** on starter choice, weak-vs-yours starter (L5, HP 0, seeded DVs) into slot 3; when slot 3 == 0 and `EVENT_BEAT_CHAMPION_LANCE`, strong-vs-yours starter (L40–50).
- **Acceptance:** Pokédex Area page shows each roamer in its region; flee/HP like the beasts; no cross-region appearances.

### 7.8 Static encounters + NPC injection (8, 14, 15, 17)
- **Object injection:** `ReadObjectEvents` copies 13-byte `object_event` entries into `wMapObjects` (`$D71E`; NPC slots from `wMap1Object` `$D72E`, 16 B each, 16 slots incl. player). Write a struct into a free slot after `ReadObjectEvents`, bump `wCurMapObjectEventCount`; `InitializeVisibleSprites` spawns it. Leave the last slot empty (overflow into `wObjectMasks`, documented bug). Sprite tiles must be in VRAM: use a sprite already in the host's `wUsedSprites` or add it and run the loader. Visibility flag must be a genuine unused `wEventFlags` index.
- **Battle trigger:** object script → `callasm` → set `wTempWildMonSpecies`, `wCurPartyLevel`, `wBattleType` (`BATTLETYPE_SHINY` = 7 or set DVs), `wBattleMode = WILD_BATTLE`, start; on catch/KO set the flag.
- **Sprites (existing only):** Suicune/Lugia for Mewtwo, Celebi for Mew; `SPRITE_GRAMPS`/`SAGE`/`FISHING_GURU`/`GENTLEMAN` for the relearner.
- **Move Relearner (17):** `callasm`: pick mon → species/level → `EvosAttacksPointers`/`EvosAttacks` (bank `$10`; evolutions 0-terminated, then `level, move` pairs 0-terminated) → filter ≤ level and not known → `VerticalMenu` → write move id to `wPartyMon1Moves` slot and base PP (`Moves` offset 5) to `wPartyMon1PP`. Charge via `TakeMoney`. Quiet Kanto interior. ~150–250 B.
- **Acceptance:** sprite visible, "!" interaction, one-time battle, object gone afterward; relearner offers only legal moves.

### 7.9 Trainer House + gauntlet + rewards (9–12)
- **Opponent (11):** write name + `TRAINERTYPE_*` + party (`db level, species[, item][, 4 moves]`, `db -1`) into `sMysteryGiftTrainer` (SRAM bank 0), set `sMysteryGiftTrainerHouseFlag`. Inside the checksummed block → let the game re-save. Malformed parties freeze the pre-battle sequence — validate.
- **Reward (12):** detect a win (`wBattleResult`) on the Trainer House basement; set Pikachu Bed ownership (saved WRAM decoration flags) and optionally its `sMysteryGiftDecorationsReceived` bit; once.
- **Gauntlet (9):** unused parties in `data/trainers/parties.asm`: SWIMMERF Lisa, Jill, Mary, Katie, Tara, Jody; SWIMMERM Hal, Paton, Daryl, Walter, Tony, Rick, James, Lewis (pret #819). Trigger: Battle Tower tile + A (coord-event injection). Set `wOtherTrainerClass`/`wOtherTrainerID`, `wBattleType = BATTLETYPE_CANLOSE`, `wBattleMode = TRAINER_BATTLE`; on win with gauntlet flag, queue the next from the DMA hook.
- **Rewards (10):** first win → Tentacool Doll; all 14 → Unown Doll.
- **Acceptance:** Cal replaced; gauntlet chains without healing; a loss exits cleanly; dolls listed.

### 7.10 Safari Zone (18) + contest rules (19)
- **Restore:** gate and zone have warp/event data. Inject an entry warp in the Fuchsia Safari building; exit warps at X:09/0A, Y:17; encounters via §7.2 (fishing `FISHGROUP_SHORE` works). Bottom-row cosmetic damage unavoidable.
- **Contest rules:** on the Safari map set `wStatusFlags` bit 7 and `wStatusFlags2` `STATUSFLAGS2_BUG_CONTEST_TIMER_F`, seed `wParkBallsRemaining`, force `wBattleType = BATTLETYPE_CONTEST` per battle. The end-of-contest warp is hardcoded to the National Park gate: detect it loading with the Safari flag set and re-warp to Fuchsia. **Never set `EVENT_LEFT_MONS_WITH_CONTEST_OFFICER`.** One-Pokémon rule: skip or emulate.
- **Acceptance:** clean enter/exit; Park Balls consumed; timer returns to Fuchsia; party intact.

### 7.11 Continuous Repel (20)
Watch `wRepelEffect` 1→0 with a Repel in the bag; auto-reapply (set duration, decrement bag) or a payload-drawn yes/no. Auto / prompt / off in Custom Settings.

### 7.12 Professor 251 → all Mystery Gifts (22)
Popcount `wPokedexCaught` ≥ 251; lab map + facing professor + A (fallback: any A in the lab when true); set all decoration ownership bits and `sMysteryGiftDecorationsReceived`. Unobtainables: Tentacool Doll, Pikachu Bed, Unown Doll.

### 7.13 Stretch: Trainer Rankings (24)
Payload-owned counters (steps, wild/trainer battles, HOF entries, whiteouts, eggs, evolutions, Magikarp length) in free SRAM, rendered via Custom Settings with `PrintNum`/`PlaceString`. Skip counters with no RAM signal.

---

## 8. Facts and labels to resolve (`docs/facts.md`)
Machine-readable list: `docs/labels.txt` (one label per line, §8 of the handoff verbatim). `tools/symdiff.py` resolves each in both `.sym` files, flags revision differences, and reports **unresolved names as stale** (see correction 11). Constants (`GS_BALL_AVAILABLE` `$0b`, `BATTLETYPE_*` NORMAL 0 / CANLOSE 1 / … / ROAMING 5 / CONTEST 6 / SHINY 7 / TREE 8 — confirm, `TEXT_DELAY_*`, `STEP_*`, `PLAYER_*`, `MUSIC_*`, `SPRITE_*`, `ENGINE_*BADGE`, `EVENT_*`, `STATUSFLAGS2_*`, `NUM_OBJECTS` 16, `MAPOBJECT_LENGTH` `$10`) come from `constants/*.asm`, not the `.sym`.

**Verified so far (commit `7a7881d0d`, both revisions unless noted):** `sGSBallFlag` `01:BE3C`; `sGSBallFlagBackup` `01:BE44`; `sChecksum` `01:AD0D`; `sBackupChecksum` `00:BF0D`; `wOptions` `00:CFCC`; `wBattleType` `01:D230`; `rWBK` = `$FF70`.

**GameShark prototyping triples (Crystal INT):** `010B3CBE` GS Ball; `010730D2` shiny battle type; `0100FAC2` walk through walls; `0160E4D4` warp tiles as holes; `010576CF` mobile menu (curiosity only).

---

## 9. Final deliverable: the install guide (+ web patcher)
Model: **BBMenuSE's numbered "parts"**, each with a verification check and an explicit note of which parts require saving afterward, so a crash localises the mistake. State the expected total install time honestly (BBMenuSE's Gen 1 equivalent is ~5 hours). Structure:
1. What this is / changes / cannot change (honest "not possible via ACE" list: phys/spec split, Gen 2 battle-bug fixes, animation speed, true Safari battles, mobile). Target: Crystal (USA) cartridge or 3DS VC. Mention the web patcher and premade saves as alternatives for users with a dumper.
2. Safety: back up (FGBWEB on a Chromatic or any dumper); soft-reset rules; freeze recovery.
3. Part 1 — ACE setup: "Follow **TimoVM's Fast 0x1500 ACE v2 guide** (Glitch City Wiki) through Step 7 (TM15 opens the Mail Writer), then return." Credit prominently. Expected state = the three persistent pieces in `docs/timovm-footprint.md` (Mail Writer at `$D9C0`, bootstrap at `$DA10`, TM15 in the main pocket). **Divergence point identified 2026-09-04.**
4. Part 2 — Installing the program: generated sequences, chunked into parts with per-part checks.
5. Part 3 — Activation and the reinstall step (Special Call: after any reset, take one step).
6. Part 4 — Feature reference (trigger, toggle, quirks, VC callouts).
7. Part 5 — Uninstall / revert.
8. Appendix: address table for both revisions; revision identification; troubleshooting; **credits**: TimoVM; M4n0zz and aestellic (BBMenu/BBMenuSE, architectural precedent); cilerba; the GCRI Gen 2 author (by their preferred name); GCRI; pret; TCRF; FGBWEB/FlashGBX authors.
Metrics: total bytes installed, estimated install time, per-feature SRAM cost.

---

## 10. Resources

**Prior art (primary) — read before kernel design:**
- M4n0zz, **BBMenu** — https://github.com/M4n0zz/BBMenu (Gen 1 kernel in the save: background effects, SELECT menu, shiny indicator, Pong/Snake; cart + 3DS VC).
- aestellic, **BBMenuSE** — https://github.com/aestellic/BBMenuSE (fork; documents no-exec-from-SRAM; numbered install parts).
- cilerba, shiny-indicator ACE script — https://github.com/cilerba/ace (lineage root).
- M4n0zz, **QuickRGBDS** — https://github.com/M4n0zz/QuickRGBDS (build wrapper; evaluate).
- Gen 2: private persistent event/GUI work on GCRI (unpublished).

**Disassembly:** https://github.com/pret/pokecrystal — `ram/wram.asm`, `ram/sram.asm`, `ram/hram.asm`, `layout.link`, `home/map.asm`, `home/sram.asm`, `engine/overworld/wildmons.asm`, `engine/overworld/events.asm`, `engine/overworld/player_movement.asm`, `engine/events/overworld.asm`, `engine/pokegear/pokegear.asm`, `engine/pokegear/radio.asm`, `engine/battle/core.asm`, `engine/items/tmhm2.asm`, `engine/rtc.asm`, `data/wild/*`, `data/radio/channel_music.asm`, `data/pokemon/evos_attacks.asm`, `data/trainers/parties.asm`, `macros/scripts/maps.asm`, `constants/*`, `docs/bugs_and_glitches.md`, `docs/map_event_scripts.md`, `docs/vc_patch.md`, `maps/unused/`. pret wiki: GameShark discovery, GS Ball restoration, unused data, new radio channel, new map, Move Relearner, Running Shoes, reusable TMs, auto Repel, tips, Trainer House self-battle. https://github.com/pret/pokegold (G/S tables). pret issue #819.

**ACE framework (glitchcity.wiki):** TimoVM's gen 2 ACE setups; Fast 0x1500 ACE v2; 0x1500 control code ACE; Mail writer; Mail Writer Codes; RAM Writer; Crystal box name codes; Big HEX List; OAM DMA hijacking; Arbitrary code execution; Unused music; Mystery Gift item corruption; Trainer House glitches.

**Cut content:** TCRF Pokémon Crystal (+ Mobile Content, Version Differences, Unused Text, Debugging Material); TCRF Gold/Silver (+ Unused Maps); Data Crystal RAM/ROM maps.

**Other:** Skeetendo threads 7531 (HM without teaching), 5066 (running shoes), 4619 (flee tables); Rangi42/polishedcrystal `FEATURES.md`; Dabomstew/pokecrystal-speedchoice; Bulbapedia (Mystery Gift, Trainer House, Roaming, Bug-Catching Contest, Gen II save structure, GS Ball); Glitch City Labs archives; FGBWEB + Lesserkuma/FlashGBX.

**Community:** GCRI Discord (TimoVM, M4n0zz, aestellic, CasualPokePlayer, the Gen 2 author). Thread open; ask there before burning days on a Phase 0 unknown.

---

## 11. Next actions
1. ✅ Toolchain, submodule, both builds, repo layout, `docs/labels.txt`.
2. `tools/symdiff.py` → `docs/facts.md` (user writes; teaches the symbol file and bank:address).
3. `tools/patcher.py`: parse a `.sav`, verify and recompute `sChecksum`/`sBackupChecksum` (user writes the checksum; teaches the save layout).
4. User: archive cart ROM + save via FGBWEB; confirm revision.
5. Read BBMenu/BBMenuSE before any kernel code. ✅ WRAM bank survey → `docs/wram-banks.md` (bank 4 adopted). ✅ `docs/sram-map.md`.
6. Reproduce TimoVM's setup in BGB (Wine); record the divergence point. ✅ Patcher option (a) writer (`install-timovm`): verified in mGBA 2026-09-07 — fresh save + patcher → TM15 from the pack opens the Mail Writer. ✅ Option (b) framework layer (`install-dma-hijack`): verified in mGBA 2026-09-07 — one step on the patched fresh save installs the OAM DMA hook (`$FF80`/`$C000`/`$DC31` as expected). Still open: BGB trace of the `$9C` → `$DA21` chain.
7. Feature 1 end to end as the pipeline proof, with its guide section and the equivalence test.
8. Report measured per-frame budget and confirmed free SRAM/WRAM before Phase 2; re-rank scope.
9. *Deferred (2026-09-07, feasible, out of scope for now):* a code-runner in the patcher — run any UI-less Mail Writer code against a save inside a headless emulator (PyBoy for CI, a wasm core for the web front end; player supplies the ROM; poke bytes at `$D280`, run to `ret`, trigger the game's save, extract SRAM). Same harness serves as the byte-equivalence CI. Revisit after the option (b) writer exists.

---

## Changelog
- **2026-09-10 (evening) —** `tools/mailcode.py`: `patcher.py` refactored around a shared write list (`uc_core_writes`, `patch_save`, `check_dma_hijack`); the mail-code generator emits the copier program from that list, packs it into ≤26-mail codes and round-trips it through a decoder. The `core` code (26 mails) was typed by hand and verified: bike call suppressed on `build/cartridge-test-hijack.sav`, replayed after installing. Found the Mail Writer's real payload limit (416 B: the 27th mail's compose buffer overwrites the script engine state).
- **2026-09-10 (later) —** language survey for `core` (`docs/languages.md`): the five Western releases share the RAM map; home-bank ROM routines shift by a constant per language (FR −$13, DE −$16, IT −$12, SP −$16, verified on four routines); IT has a different framework layout; JP is a separate port. Mail-code installer started.
- **2026-09-10 —** **`core` complete**: slot-4 glue added (Init copies the 917-byte window to `04:D200`; Frame and Step call into it when the `"U4"` signature is present); kernel split into stage 1 (header, step entry, Init — 70 B) and part B (hooks, 194 B) once stage 1 outgrew the loader's one-byte length; smoke-tested on the cartridge save with slot 4 empty. Image 313 B in a 512-byte region.
- **2026-09-10 —** **All three `core` fixes verified in-game on the user's cartridge save** (`tests/cartridge-test.sav` + full install chain): bike-shop call fires at 1024 bike steps; nurse gives the Pokérus line and Elm's call follows; parking verified earlier. Second carry bug found and fixed at the root: `UCFarCall` now always returns carry clear, so nothing returning into TimoVM's reinstall can trigger a garbage call. Nurse fix narrowed to the exact `checkphonecall` opcode (`2F:411F` during the script's `pause 10`). Test note: the game's Pokérus day-tick cures an infection injected into a cartridge dump on load; poke it in the emulator instead.
- **2026-09-10 —** `core` scope narrowed by the user to "fix TimoVM's special-call bugs + load from the new home", as a candidate updated base setup for TimoVM to publish; the registry/settings/repoint/repair pieces move to a proposed Tier 1b `uc` runtime (§2a). Nurse/Pokérus fix moved from future scope into `core` and designed (`docs/core-design.md` hook 3).
- **2026-09-10 —** **Save-time parking works in-game** (first Uncut Crystal feature): story ID 7 queued, save, reset, two steps → Mom's call fires and the framework survives (`$FF80` hooked, `wUCLoaded` set, arm byte back to `$9C`). Baseline without the hook reproduced the hook loss. Hook = 57 B in `UCFrame` (user-written), stage 1 = 112 B.
- **2026-09-09 —** **First in-game run of the kernel passed** (mGBA, `build/fresh-core.sav`): one step installs the hook, the loader copies stage 1 into bank 4, `UCInit` runs and sets `wUCLoaded`; no phone call, no crash. Found and fixed on the way: the reinstall must return with carry clear (`CheckSpecialPhoneCall` takes a call on carry set; `OpenSRAM` leaves it set), so `UCFarCall` now passes the callee's flags through and `UCInit` clears carry; the reinstall diversion is at `$DA37–$DA38` (was mis-stated as `$DA35`). `patcher.py install-uc-core` written.
- **2026-09-09 —** Named: **Pokémon - Uncut Crystal**; `UC`/`uc` prefix convention. `src/uc/` holds the first assembly (WRAM0 stubs, loader, kernel stage 1, all user-written); `make` → `build/uc.bin` + `uc.sym`. Code comments stripped to a terse pokecrystal style.
- **2026-09-07 —** `core` design v3 (`docs/core-design.md`), after the user's decisions (four bytes of TimoVM's framework may change; no constant-effect slot is used; bike-shop replay in scope): his reinstall's `call CopyBytes` → our loader (main thread, per step, loads SRAM → bank 4 via `FarCopyWRAM`, then a per-step kernel pass); his hook template's `call` dispatcher → our WRAM0 stub (his dispatcher, then a per-frame kernel pass). Two kernel contexts, Frame (WRAM only) and Step (anything). WRAM0 holes `$CFD8`/`$CD14` hold marker, stubs, accessors. v1/v2 (slot-3 tenant, idle predicate) superseded. §2a core row, §4.4 rule and §4.5a wording updated.
- **2026-09-07 —** `patcher.py install-dma-hijack`: writes the Special Call ACE + OAM DMA hijack framework (hook, reinstall, dispatcher, slot 1 and slots 2–3 with `ret`s, arm byte) into both blocks; byte-identical to the VC save's framework and verified in-game in mGBA (hook live after one step). Save-time parking adopted into scope (§4.5a, `docs/resilience.md`); install bundles approved (§2a); §1.1 install-path positioning (hand install recommended, patcher expected).
- **2026-09-07 —** `patcher.py install-timovm` (option (a)): writes the Mail Writer, TM15 bootstrap and TM15 item into both save blocks; byte-identical to the VC save's setup and verified in-game in mGBA (Mail Writer opens on a patched fresh save). Fetched wiki pages now kept in `.research/` (gitignored).
- **2026-09-05 —** WRAM bank survey complete (`docs/wram-banks.md`): bank 4 unreachable by any non-mobile code, adopted as kernel bank; §4.3/§4.4 updated.
- **2026-09-07 —** resilience decision reversed: save-time parking adopted (`docs/resilience.md`); Pokérus nurse branch logged as future scope; **modular install bundles adopted (§2a)**: fixed SRAM address map, one version-exclusives bundle, legendaries as separate codes from their maps.
- **2026-09-04 (later) —** symbol + ROM byte diff complete; four source-level revision differences recorded in `docs/revision-diff.md`; indirection table not needed.
- **2026-09-04 — plan update folded in.** Added: prior art (BBMenu/BBMenuSE/cilerba/QuickRGBDS) as required reading; "SRAM hack" term and positioning; hard constraint 6 (no execution from SRAM) and correction 9; OAM DMA hijack as the sole per-frame hook, scene scripts demoted (correction 10); WRAM bank swap via readable `rWBK` as the runtime execution model (§4.3), with the initial bank survey (bank 4 mobile-news buffer and bank 2 tail as candidates); storage plan reframed (SRAM = persistent image); Phase 0 items 6–12; patcher promoted to deliverable with client-side web front end, options (a)/(b), VC container handling, byte-equivalence CI, premade saves, `web/` and `tests/equivalence/` in the layout; install guide restructured on BBMenuSE's numbered-parts model with honest time estimate and expanded credits; GCRI community note. Recorded stale label names (correction 11) and the first verified addresses. Sanity-check items (dual revision, GS Ball dual write, both-revision testing) were already present and are retained.
- **2026-09-03 — original handoff document** (seven research rounds).
