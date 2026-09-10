# SRAM map — free-space inventory (2026-09-04, pokecrystal 7a7881d0d)

International Crystal: MBC3, 4 × 8 KB SRAM banks. `.sav` offset = `bank * 0x2000 + addr - 0xA000`.
Banks 4–7 are declared in `ram/sram.asm` (Japanese mobile layout) but do not exist on the cart, and `OpenSRAM` rejects any bank ≥ `NUM_SRAM_BANKS` (4), so dead mobile code can never alias onto bank 0.

## Allocation per the linker (`pokecrystal/pokecrystal.map`)

| Bank | Range | Section | Notes |
|---|---|---|---|
| 0 | `$A000–$A5FF` | Scratch | `sScratch`; game-written (identical content across saves) |
| 0 | `$A600–$AC6A` | SRAM Bank 0 | party mail, Mystery Gift data (`sMysteryGiftItem` `$ABE2` …), lucky number, RTC status |
| 0 | **`$AC6B–$B1FF`** | **EMPTY** | **1429 B** |
| 0 | `$B200–$BF11` | Backup Save | checksummed `$B209–$BD82`, `sBackupChecksum` `$BF0D` |
| 0 | **`$BF12–$BFFF`** | **EMPTY** | **238 B** |
| 1 | `$A000–$AD0F` | Save | checksummed `$A009–$AB82`, `sChecksum` `$AD0D` |
| 1 | `$AD10–$B25F` | Active Box | `sBox` |
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

## Empirical check (`tools/sram_map.py`)

| Bank | Range | Size | .sav offsets | fresh mGBA | VC early | VC complete | Identical |
|---|---|---|---|---|---|---|---|
| 0 | `$AC6B-$B1FF` | 1429 | `0x0c6b-0x11ff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 0 | `$BF12-$BFFF` | 238 | `0x1f12-0x1fff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 1 | `$BE57-$BFFF` | 425 | `0x3e57-0x3fff` | all `0xff` | all `0x00` | all `0xff` | NO |
| 2 | `$BE30-$BFFF` | 464 | `0x5e30-0x5fff` | all `0xff` | mixed(10) | all `0xff` | NO |
| 3 | `$BE30-$BFFF` | 464 | `0x7e30-0x7fff` | all `0xff` | mixed(3) | all `0xff` | NO |

Reading:
- **Fresh mGBA** (minutes) and **VC complete** (16 badges, 13 Hall of Fame entries, heavy box use): every gap still holds the uninitialised fill (`0xFF`). No byte of any gap was written in either session. This is the strong result.
- **VC complete also has TimoVM's full ACE setup installed** (per the user: an item in the bag starts the 'nickname writer'; box names are *not* part of the persistent setup — all boxes have been renamed and it still works) and its gaps are still untouched, so **TimoVM's setup does not occupy any gap** — one of the owed questions, answered. Caveat for the sentinel run on this save: PC box and mail operations are the setup's own trigger surface, so those paths are covered by the static audit rather than by play on this file.
- **VC early**: different fill (`0x00`), so it did not originate on the same device/emulator as the complete save, plus 9 + 2 stray non-zero bytes in the box-bank gaps (bank 2 at `$BFC0` `e1 5a 5b`, `$BFE8` `0e`, `$BFEC` `0f`; bank 3 at `$BF0D` `4e df`). Provenance unknown; the user ran TimoVM ACE experiments on that 3DS, so these may be ACE residue. **Excluded as evidence** rather than explained.

## Static audit of every SRAM write (2026-09-04) — verdict: all five gaps are free

Method: every SRAM write in the retail build happens between `OpenSRAM` and `CloseSRAM`. All 115 block operations (`CopyBytes`/`ByteFill`/`Checksum`) inside those windows in non-mobile code were inventoried by script and every single-byte write to a section adjacent to a gap was read by hand. Findings:

| Gap | Neighbour and how it is written | Verdict |
|---|---|---|
| `00:AC6B–B1FF` (1429) | "SRAM Bank 0" ends with `sMysteryGiftTrainer` (38 B copy, `wMysteryGiftTrainerEnd - wMysteryGiftTrainer`), unlabeled padding `$AC30–$AC5F`, `sRTCStatusFlags` (1 B), `sLuckyNumberDay` (1 B), `sLuckyIDNumber` (2 B). Mail backups (`sPartyMailBackup` `$A71A`, `sMailboxCountBackup` `$AA0B`) end at `$ABE2`. All fixed-size. | **free** |
| `00:BF12–BFFF` (238) | "Backup Save" ends with `sBackupChecksum` (2 B), `sBackupCheckValue2` (1 B), `sStackTop` (2 B, `$BF10–11`, "appears to be unused"). | **free** |
| `01:BE57–BFFF` (425) | "SRAM Battle Tower": `sBTTrainers` filled with `BATTLETOWER_STREAK_LENGTH` (7) bytes, the rest single-byte stores; last byte `sBTMonPrevPrevTrainer3` `$BE56`. Hall of Fame is a fixed 30-entry FIFO: `AddHallOfFameEntry` shifts entries 0–28 down and writes entry 0; it never grows past `sHallOfFameEnd` `$BE3C`. | **free** |
| `02:BE30–BFFF` (464) | Box 7 occupies `sBox7` `$B9E0` + `BOX_LENGTH` `$450` = up to `$BE2F`; every box copy uses `sBoxEnd - sBox`-derived sizes (`$44E`), so `$BE2E–$BE2F` are never written either. `CopyBoxmonToTempMon` and the printer's box listing are reads. | **free** (+2 B padding at `$BE2E–2F`) |
| `03:BE30–BFFF` (464) | Same as bank 2 for box 14. TimoVM's RAM Writer, when installed, uses `$BE2F–$BEEB` (reserved). | **free** (+2 B padding) |

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
| `00:AE6B–B1FF` | 917 | slot 4 image (UC Runtime), loaded to `04:D200` by `core`'s Init |
| everything else in the five gaps | 1402 | available to the UC Runtime — to be carved into **fixed per-bundle slots** (README §2a). Skipped bundles leave holes by design. |
