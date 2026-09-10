# v1.0 vs v1.1 — what actually differs (verified 2026-09-04, pokecrystal 7a7881d0d)

Method: `tools/symdiff.py` (labels) + `cmp -l` of the two built ROMs (bytes), each difference attributed to the nearest preceding symbol.

## Source-level differences (`if DEF(_CRYSTAL11)` blocks — the authoritative list; there are FOUR, not three)
| # | File | Change | Where in ROM |
|---|---|---|---|
| 1 | `mobile/mobile_5c.asm` | Unused Mobile Stadium tilemap corrupted by LF→CRLF (`$0a` → `$0d $0a`), grows 13 bytes | `5c:73af–5c:768b`; shifts `Stadium2N64Attrmap` `5c:7517` → `5c:7524` |
| 2 | `engine/events/battle_tower/trainer_text.asm` | Loads `wBT_OTTrainerClass` instead of the 6th name char | one operand byte at `5c:6ead` (+ text data at `47:4008`) |
| 3 | `engine/events/battle_tower/load_trainer.asm` | v1.0 masks the trainer roll with `BATTLETOWER_NUM_UNIQUE_MON` (21) instead of `..._TRAINERS` (70), so only 21 BT trainers are ever sampled. **Not in the handoff's TCRF list.** | `7e:402a–7e:402c` |
| 4 | `ram/wram.asm` | `wPokedexStatus` moves `00:cf65` → `00:c7e5` (v1.0 shared the byte with `wPrevDexEntryBackup`); `wPokedexDataEnd` `00:c7e5` → `00:c7e6` | operand bytes `65 cf` → `e5 c7` in banks `$10`, `$11`, `$3e`; clear-count `+1` at `InitPokedex+0x10` |

Derived, not independent: header revision byte and checksums `00:014c–014f`; Pokémon Stadium 2 per-bank checksums at the tail of bank `$7f` (`7f:7dfe–7f:7fff`, written by `tools/stadium`).

Total differing bytes: 584. Differing labels: 3 (`wPokedexStatus`, `wPokedexDataEnd`, `Stadium2N64Attrmap`).

## Consequences for this project
- **No label used by this project differs → the indirection table costs 0 bytes.** Home bank, banks `$03 $05 $0a $0f $10 $24 $5c(BattleTowerAction) $72` are position-identical for everything we call.
- **The WRAM/SRAM layout differs by exactly one byte** (`wPokedexStatus`), which we do not touch. `.sav` layout is identical.
- **Risk to TimoVM's ACE setup** is confined to payloads that read/execute ROM bytes inside the ranges above. Check his box-name / Mail Writer sequences against those ranges before assuming the install guide does not branch.
- Feature 9 (gauntlet) uses `data/trainers/parties.asm` parties, not Battle Tower trainers, so difference 3 does not affect it.
