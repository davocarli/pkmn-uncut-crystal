# SRAM map — free-space inventory (2026-09-04, pokecrystal 7a7881d0d)

International Crystal: MBC3, 4 × 8 KB SRAM banks. `.sav` offset = `bank * 0x2000 + addr - 0xA000`.
Banks 4–7 are declared in `ram/sram.asm` (Japanese mobile layout) but do not exist on the cart, and `OpenSRAM` rejects any bank ≥ `NUM_SRAM_BANKS` (4), so dead mobile code can never alias onto bank 0.

## Allocation per the linker (`pokecrystal/pokecrystal.map`)

| Bank | Range | Section | Notes |
|---|---|---|---|
| 0 | `$A000–$A5FF` | Scratch | `sScratch`; game-written (identical content across saves) |
| 0 | `$A600–$AC6A` | SRAM Bank 0 | party mail, Mystery Gift data (`sMysteryGiftItem` `$ABE2` …), lucky number, RTC status |
| 0 | **`$AC30–$AC5F`** | **padding** (`ds $30` after `sMysteryGiftTrainer`) | **48 B**, unlabeled → **window 6** (2026-09-21) |
| 0 | **`$AC61–$AC67`** | **padding** (`ds 7` after `sRTCStatusFlags`) | **7 B**, unlabeled; too small for a window |
| 0 | **`$AC6B–$B1FF`** | **EMPTY** | **1429 B** |
| 0 | `$B200–$BF11` | Backup Save | checksummed `$B209–$BD82`, `sBackupChecksum` `$BF0D` |
| 0 | **`$BD83–$BF0C`** | **padding** (`ds $18a` before `sBackupChecksum`) | **394 B**, unlabeled → **window 8** (2026-09-21) |
| 0 | **`$BF12–$BFFF`** | **EMPTY** | **238 B** |
| 1 | `$A000–$AD0F` | Save | checksummed `$A009–$AB82`, `sChecksum` `$AD0D` |
| 1 | **`$AB83–$AD0C`** | **padding** (`ds $18a` before `sChecksum`) | **394 B**, unlabeled → **window 7** (2026-09-21) |
| 1 | `$AD10–$B15F` | Active Box | `sBox`, `BOX_LENGTH` `$450` |
| 1 | **`$B160–$B25F`** | **padding** (`ds $100` after `sBox`) | **256 B**, unlabeled → **window 9** (2026-09-21) |
| 1 | `$B260–$B2BF` | Link Battle Data | |
| 1 | `$B2C0–$BE3B` | SRAM Hall of Fame | 30 entries |
| 1 | `$BE3C–$BE44` | SRAM Crystal Data | `sGSBallFlag` `$BE3C`, `sGSBallFlagBackup` `$BE44` |
| 1 | `$BE45–$BE56` | SRAM Battle Tower | |
| 1 | **`$BE57–$BFFF`** | **EMPTY** | **425 B** |
| 2 | `$A000–$BE2F` | Boxes 1–7 | 7 × 1104 B |
| 2 | **`$BE30–$BFFF`** | **EMPTY** | **464 B** |
| 3 | `$A000–$BE2F` | Boxes 8–14 | |
| 3 | **`$BE30–$BFFF`** | **EMPTY** | **464 B** |

**Total unallocated in banks 0–3: 3020 bytes** (the handoff estimated ~1 KB). None of it is covered by either checksum.

**Plus 1099 bytes of unlabeled `ds` padding inside allocated sections (found 2026-09-21, the space audit):** the linker counts these as allocated, but no label names them, so no code can address them; every neighbouring write is label-bounded (both checksums run `sGameData..sGameDataEnd`; `sChecksum`, `sCheckValue2` and `sStackTop` are 1–2 byte stores; every box copy uses `sBoxEnd`-derived sizes; the Mystery Gift copy is `sBackupMysteryGiftItemEnd - sBackupMysteryGiftItem`). Uniform fill in all six saves below (two cartridge dumps and `build/vccomplete-runtime.sav` added). Evidence level: grep of every reference near the ranges + the empirical check, not the 2026-09-04 script inventory — the ranges are in `GAPS` now, so `sram_map.py` and `sentinel` cover them; re-audit to that standard before release. Same residual risk as the gaps (a write through a corrupted pointer). **4119 B in all.**

## Empirical check (`tools/sram_map.py`)

| Bank | Range | Size | .sav offsets | fresh mGBA | VC early | VC complete | Identical |
|---|---|---|---|---|---|---|---|
| 0 | `$AC6B-$B1FF` | 1429 | `0x0c6b-0x11ff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 0 | `$BF12-$BFFF` | 238 | `0x1f12-0x1fff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 1 | `$BE57-$BFFF` | 425 | `0x3e57-0x3fff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 2 | `$BE30-$BFFF` | 464 | `0x5e30-0x5fff` | all `0xff` | mixed(10) | all `0xff` | NO |
| 3 | `$BE30-$BFFF` | 464 | `0x7e30-0x7fff` | all `0xff` | mixed(3) | all `0xff` | NO |
| 0 | `$AC30-$AC5F` | 48 | `0x0c30-0x0c5f` | all `0xff` | all `0x00` | all `0xff` | NO (fill) |
| 0 | `$BD83-$BF0C` | 394 | `0x1d83-0x1f0c` | all `0xff` | all `0x00` | all `0xff` | NO (fill) |
| 1 | `$AB83-$AD0C` | 394 | `0x2b83-0x2d0c` | all `0xff` | all `0x00` | all `0xff` | NO (fill) |
| 1 | `$B160-$B25F` | 256 | `0x3160-0x325f` | all `0xff` | all `0x00` | all `0xff` | NO (fill) |

Reading:
- **Fresh mGBA** (minutes) and **VC complete** (16 badges, 13 Hall of Fame entries, heavy box use): every gap still holds the uninitialised fill (`0xFF`). No byte of any gap was written in either session. This is the strong result.
- **VC complete also has TimoVM's full ACE setup installed** (per the user: an item in the bag starts the 'nickname writer'; box names are *not* part of the persistent setup — all boxes have been renamed and it still works) and its gaps are still untouched, so **TimoVM's setup does not occupy any gap** — one of the owed questions, answered. Caveat for the sentinel run on this save: PC box and mail operations are the setup's own trigger surface, so those paths are covered by the static audit rather than by play on this file.
- **VC early**: different fill (`0x00`), so it did not originate on the same device/emulator as the complete save, plus 9 + 2 stray non-zero bytes in the box-bank gaps (bank 2 at `$BFC0` `e1 5a 5b`, `$BFE8` `0e`, `$BFEC` `0f`; bank 3 at `$BF0D` `4e df`). Provenance unknown; the user ran TimoVM ACE experiments on that 3DS, so these may be ACE residue. **Excluded as evidence** rather than explained.

## Static audit of every SRAM write (2026-09-04) — verdict: all five gaps are free

Method: every SRAM write in the retail build happens between `OpenSRAM` and `CloseSRAM`. All 115 block operations (`CopyBytes`/`ByteFill`/`Checksum`) inside those windows in non-mobile code were inventoried by script and every single-byte write to a section adjacent to a gap was read by hand. Findings:

| Gap | Neighbour and how it is written | Verdict |
|---|---|---|
| `00:AC6B–B1FF` (1429) | "SRAM Bank 0" ends with `sMysteryGiftTrainer` (38 B copy, `wMysteryGiftTrainerEnd - wMysteryGiftTrainer`), unlabeled padding `$AC30–$AC5F`, `sRTCStatusFlags` (1 B), `sLuckyNumberDay` (1 B), `sLuckyIDNumber` (2 B). Mail backups (`sPartyMailBackup` `$A71A`, `sMailboxCountBackup` `$AA0B`) end at `$ABE2`. All fixed-size. | **free** |
| `00:BF12–BFFF` (238) → **window 5**, loaded to `04:D108` (after the kernel; was `04:DB20` until 2026-09-21) by `UCWindows`; empty. **Usable since 2026-09-23:** images here assemble at `SECTION ROM0[$1108]` (address + `$1000`) because the kernel's ROM0 section occupies the mirror offsets `$0080–$0187`; the patcher's window table carries the bin offset per window. |
| `01:BE57–BFFF` (425) → **slot 4 window 2**, loaded to `04:D600` by `UCWindows` (`core/windows.asm`) on the first runtime step; zones framework `$D600` (193 B), Kanto zone table `$D6D0` (9 B), Kanto encounter table `$D6E0` (41 B), Radio `$D720` (130 B) as of 2026-09-22; 373 of 425 used, crumbs `$D6C1` 15, `$D6D9` 7, `$D709` 23, `$D7A2` 7. Loaded on the second step after power-on (the first runs Init). **Same loader, since 2026-09-21:** window 6 `00:AC30` (48) → `$D9D0`, window 7 `01:AB83` (394) → `$DB14`, window 8 `00:BD83` (394) → `$DCA2`, window 9 `01:B160` (256) → `$DE30`, window 10 `00:ADA4` (199, the slack after the core image) → `$DF30`; bank 4 is packed tight from `$DB14` to `$DFF6` | "SRAM Battle Tower": `sBTTrainers` filled with `BATTLETOWER_STREAK_LENGTH` (7) bytes, the rest single-byte stores; last byte `sBTMonPrevPrevTrainer3` `$BE56`. Hall of Fame is a fixed 30-entry FIFO: `AddHallOfFameEntry` shifts entries 0–28 down and writes entry 0; it never grows past `sHallOfFameEnd` `$BE3C`. | **free** |
| `02:BE30–BFFF` (464) → **window 3**, loaded to `04:D800` by `UCWindows`; roaming framework + Kanto roamers, cut encounter table `$D9A0` (21 B) as of 2026-09-22 (27 B free at `$D9B5`) | Box 7 occupies `sBox7` `$B9E0` + `BOX_LENGTH` `$450` = up to `$BE2F`; every box copy uses `sBoxEnd - sBox`-derived sizes (`$44E`), so `$BE2E–$BE2F` are never written either. `CopyBoxmonToTempMon` and the printer's box listing are reads. | **free** (+2 B padding at `$BE2E–2F`) |
| `03:BE30–BFFF` (464) → **window 4** = `$BEEC–$BFFF` (276 B, after the RAM Writer reservation), loaded to `04:DA00` by `UCWindows`; starter roamer, Safari Zone `$DA70` (109 B) as of 2026-09-22 (55 B free at `$DADD`) | Same as bank 2 for box 14. TimoVM's RAM Writer, when installed, uses `$BE2F–$BEEB` (reserved). | **free** (+2 B padding) |

Other facts from the sweep:
- **Delete save (SELECT+UP+B on the title screen)** runs `EmptyAllSRAMBanks`: `ByteFill` of all `$2000` bytes in each of the 4 banks with `$00`. This is the only whole-bank write, it is user-initiated, and **it erases our program** — the guide must say so. It also explains fills: a save created after delete-save shows `00` in the gaps; one created on fresh SRAM shows the power-on `FF`.
- Several Battle Tower and Mystery Gift routines write to `s5_*` / `s4_*` labels (SRAM banks 4–5, Japanese mobile). `OpenSRAM` rejects banks ≥ 4 and leaves SRAM disabled, so those stores hit nothing on a 32 KB cart.
- `sScratch` (`$A000–$A5FF`) is a real scratch buffer (tilemap/printer/decompression copies up to 784 B) — not free.
- The debug room (`engine/debug/`) is compiled only with `_DEBUG`; not in retail.
- The early VC save's stray gap bytes are consistent with ACE-setup code running while box 14's bank (3) was open (`4E DF` at `03:BF0D` is exactly where the *bank 0* backup checksum would be written). Not a game path.

Residual risk: a game-code write through a corrupted pointer (a glitch, not normal play). Accepted.

**Sentinel play on the 3DS is now optional** — it would only re-confirm the static result.

## Allocation ledger
| Range | Size | Owner |
|---|---|---|
| `03:BE2F–BEEB` | 189 | reserved: TimoVM RAM Writer (optional) |
| `00:AC6B–AE6A` | 512 | `core` image (stage 1 + WRAM0 stubs + PokeB1), loaded to `04:D000` by the loader/Init |
| `00:AE6B–B1FF` | 917 | slot 4 image (UC Runtime), loaded to `04:D200` by `core`'s Init; runtime `$D200` (202 B), GS Ball `$D300` (38 B), Trainer House `$D340` (208 B, frame half then `UCTrainerHouseStep`), Encounters `$D420` (248 B, +3 for the 251 table's list row 2026-09-24), window loader `UCWindows` `$D520` (108 B, 9 rows) as of 2026-09-22; 813 of 917 used, free in crumbs only (`$D2D3` 45, `$D326` 26, `$D410` 16, `$D518` 8, `$D58C` 9). **2026-09-22:** feature images are `"UC"` + code (no `jp` header) and encounter tables carry the method once per map block; 99 B returned across the 15 images. The Version Exclusives table moved to window 6 (`$D9D0`) to make room for the loader table. Options menu (268 B at `$D480` + 420 B blob in window 2) shelved 2026-09-20: `src/uc/shelved/ucoptions.asm` |
| `02:BE30–BFFF`, `03:BEEC–BFFF`, `00:BF12–BFFF` | 464 + 276 + 238 | windows 3, 4, 5 → `04:D800`, `04:DA00`, `04:D108`, loaded by `UCWindows` (2026-09-21). Window 3: Kanto birds `UCKantoRoamers` `$D800` (396 B, one image since 2026-09-25: `.track` is the old `UCRoam`, the two 21 B region sets live in SRAM at `02:BF8C–BFB5` and are written in place, the bank-4 copy is stale; the state bytes `UCRoamMap`/`UCRoamPrevMap`/`UCRoamRegion`/`UCRoamMapChanged` at `$D986–$D98B`); 396 of 464 used, 68 B free at `$D98C`. Window 4 (repacked 2026-09-25, the starter roamer shelved): cut encounter table `UCCutEncounters` `$DA00` (49 B, three blocks), shared map lookup `UCFindMap` `$DA31` (63 B, base, 2026-09-23); 112 of 276 used, **164 B free at `$DA70`** in one run. `UCSafari` is gone (2026-09-24): its roll is a row of the encounter roller. `UCStarterRoamer` is gone (2026-09-25): `src/uc/shelved/starter_roamer.asm`. Window 5 empty (unusable until the bin-offset rule, see above). Skipped units leave holes by design. |
| `00:AC30–AC5F` | 48 | window 6 → `04:D9D0` (2026-09-21): Version Exclusives table `UCExclusivesTable` `$D9D0` (27 B), 21 B free |
| `01:AB83–AD0C`, `00:BD83–BF0C`, `01:B160–B25F`, `00:ADA4–AE6A` | 394 + 394 + 256 + 199 | windows 7, 8, 9, 10 → `04:DB14`, `04:DCA2`, `04:DE30`, `04:DF30` (2026-09-21). Window 7: block override `UCBlocks` `$DB14` (186 B since the shared lookup, 2026-09-23; 240 before), cut block table `UCCutBlocks` `$DC10` (60 B: Fuchsia door + the Safari entrance, 17 cells, size bytes for `UCFindMap`); 82 B free at `$DC4C` plus 12 at `$DC04`. Window 8 (repacked 2026-09-25, no gaps): NPC injection `UCNpcInject` `$DCA2` (112 B), cut inject table `UCCutInjects` `$DD12` (1 B, empty), map-header hijack `UCMapHijack` `$DD13` (171 B, frame + step halves), cut hijack table `UCCutMaps` `$DDBE` (55 B: Mt. Silver exterior + Unused Cave); 339 of 394 used, **55 B free at `$DDF5`**. `UCNpcSwap` is gone (2026-09-25): `src/uc/shelved/npcswap.asm`. Window 9: **empty again (256 B free at `$DE30`)** — `UCCutNpcs` and its `npcs/*.asm` fragments are shelved (2026-09-25); the next NPC scripts land here. Window 10 (2026-09-24): encounter roller `UCRoller` `$DF30` (135 B: step half, then the Unown frame half `UCRollerFrame` `$DF91` and its state byte `$DFB6`), cut roller table `UCCutRoller` `$DFC0` (25 B: Safari Zone, Mt. Silver exterior, Unused Cave; 8 B per row = map_id, size, then where/rate/level/mask/species), 251 encounter table `UC251Encounters` `$DFE0` (11 B: the Kanto starters on the exterior); 12 B free at `$DFEB` plus 9 at `$DFB7` and 7 at `$DFD9`. Window 10 is the slack after the 313 B core image; the patcher refuses a core image that reaches it. **Every registered window costs 7 B in the loader table and 7 B of mail code: remove the ones still empty when the feature work is done and the documentation is being finished.** |

**Save-side bits and wram scratch (2026-09-24, updated 2026-09-25):** the Old Sea Map is event flag 300 (`EVENT_UC_OLD_SEA_MAP`, unused range 261–599), byte `01:DA97` bit 4; still defined for the NPCs to come, nothing sets it since the sailor and Oak were shelved. Injected NPC scripts are copied to `01:D2C0` (`UC_NPC_SCRIPT`), queued scripts to `01:D280` (`UC_MSG_SCRIPT`): both inside the 451-byte enemy-party/link union at `$D26B–$D42D`, which the game only uses in battle and link, never while a script can run. The harness parks its own scripts at `$D420`, above the longest fragment the buffer can hold.

**Save-side byte (2026-09-21):** the roaming framework uses `01:DCAF`, the first byte of the `ds 3` padding after `wBackupMapNumber` inside `wCurMapData`, as "which region's set the roamer slots hold". It is copied with the save (both checksummed blocks) and nothing in the game writes it. `wUnusedDailyFlag` was rejected: `time.asm` writes it.
