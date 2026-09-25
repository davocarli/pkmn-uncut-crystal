# Install modules (2026-09-21)

The program is installed as **units** (one image at a fixed address, delivered by one mail-code
group) grouped into **modules** the player picks. Two mechanisms, deliberately separate:

- **Signatures say what is installed.** Every feature image starts with `"UC"` and its code follows
  directly (since 2026-09-22; no `jp` header). A feature with both hooks carries a second `"UC"` in
  front of its step code (`UCTrainerHouseStep`) and the step table lists that
  address; shared state is named in full across the two label scopes. The runtime's walker skips a
  feature whose signature is missing. Frameworks never check that a dependency is present: the guide
  says to install dependencies first, and skipping that is user error.
- **`UCModules` (slot4.asm) says what is enabled.** One bit per module, starts at 0. A module's
  install ends with a one-mail code that sets its bit; `mailcode.py enable|disable <module>` toggles
  it later. Features and tables tagged with a bit are skipped while it is clear; tag 0 means always on.

## Where the bits are checked (the walker, then one list per framework)

| Where | What is gated | Cost |
|---|---|---|
| `RunFeatures` in slot4.asm | each feature table entry is `dw address, db module` | 13 B + 1 B/feature |
| `encounters.asm` `.tables` | list of `db module, dw table`, ended by `TABLE_END`; each table is a module's own image | ~26 B |
| `zones.asm` `.tables` | same | ~26 B |
| `blocks.asm` `.tables` | same | ~26 B |
| `npcinject.asm` `.tables` | same | ~26 B |
| `maphijack.asm` `.tables` | same | ~26 B |
| `roller.asm` `.tables` | same | ~26 B |

## Modules

| Module | Bit | Own units | Depends on |
|---|---|---|---|
| base | – | core, runtime (slot4), window loader (`UCWindows`), GS Ball, Trainer House, shared map lookup (`UCFindMap`, 2026-09-23: map-keyed tables carry a size byte per map for it); also zeroes `UCZoneCurrent` | – |
| encounters | – | `UCEncounters` (shared framework) | base; reads `UCZoneCurrent` (zones), which base zeroes when zones is absent |
| zones | – | `UCZones` (shared framework) | base |
| blocks | – | `UCBlocks` (shared framework, 2026-09-22: writes a module's block ids into the loaded map) | base (`UCFindMap`) |
| inject | – | `UCNpcInject` (shared framework, 2026-09-25: writes a whole `wMapObjects` record from a table row — an empty slot becomes a new NPC, a used slot is replaced — copies the script to `$D2C0` in parts and queues a spawn script; replaces the 2026-09-23 script swap `UCNpcSwap`, now shelved) | base (`UCFindMap`) |
| maps | – | `UCMapHijack` (shared framework, 2026-09-24: rewrites the wram map header of a host map to a cut map's data, exits by table) | base (`UCFindMap`) |
| roller | – | `UCRoller` (shared framework, 2026-09-24: rolls a wild battle from a table row on maps with no wild table of their own — the row says where (`UC_ROLL_GRASS`/`UC_ROLL_ANY`), the rate, the level and the placeholder species; listed after `UCMapHijack`'s step half, so an exit warp queues first; its frame half `UCRollerFrame` restores the Unown letter sets the roll unlocked for the battle) | base (`UCFindMap`); listed after maps in the step table |
| exclusives | 0 | `UCExclusivesTable` | encounters |
| kanto | 1 | `UCKantoZones`, `UCKantoEncounters` | encounters, zones |
| cut | 2 | `UCRadio`, `UCKantoRoamers` (one image since 2026-09-25, the map/region tracking and the set swap inside it; owns the save byte `01:DCAF`), `UCCutEncounters` + `UCCutBlocks` (Safari Zone, 2026-09-22; its roll is a `UCCutRoller` row since 2026-09-24, `UCSafari` gone); `UCCutInjects` (empty since 2026-09-25: the sailor and Oak were shelved, injected NPCs to come) + `UCCutMaps` (Mt. Silver exterior, Unused Cave) + `UCCutRoller` (2026-09-24) | encounters, blocks, inject, maps, roller |
| 251 | 3 | `UC251Encounters` (2026-09-24: the Kanto starters as the band the cut blocks leave on the two hijacked maps); (caves, Mew/Mewtwo, starter gifts — to come) | encounters; its maps are only reached with cut installed (maps) |
| qol | 4 | (to come) | – |

Definitions live in `tools/patcher.py` `UC_MODULES` and `src/uc/core/module_constants.asm`; keep them in step.

## Dependencies (2026-09-25)

A module depends on the frameworks its feature files use, nothing else. Every file in
`src/uc/features/` starts with a `; Requires:` line naming those frameworks (`none` when the
feature only needs core and base); the module rows above and `UC_MODULES` in `tools/patcher.py` are the union of their files' lines.
Frameworks live in `src/uc/frameworks/` and are always-on units; core (`src/uc/core/`) and base are
required by everything and are not listed.

| Framework (file) | Install name | Unit | Needs |
|---|---|---|---|
| encounters | encounters | `UCEncounters` | zones' `UCZoneCurrent`, zeroed by base when zones is absent |
| zones | zones | `UCZones` | – |
| blocks | blocks | `UCBlocks` | `UCFindMap` (base) |
| npcinject | inject | `UCNpcInject` | `UCFindMap` (base) |
| maphijack | maps | `UCMapHijack` | `UCFindMap` (base) |
| roller | roller | `UCRoller` | `UCFindMap` (base); steps after maphijack so an exit warp queues first |

`; Requires:` lines use the file names; the module table, `UC_MODULES` and the guide use the install names.

Feature files and what each needs:

| File | Requires |
|---|---|
| `base_gsball`, `base_trainerhouse` | none |
| `exclusives_encounters` | encounters |
| `kanto_encounters` | encounters, zones |
| `kanto_zones` | zones |
| `cut_blocks` | blocks |
| `cut_encounters` | encounters, roller (maps reached through maphijack) |
| `cut_injects` | npcinject |
| `cut_maps` | maphijack |
| `cut_radio`, `cut_roamers` | none |
| `cut_roller` | roller |
| `251_encounters` | encounters (maps reached through cut's maphijack) |

Nothing checks any of this at runtime: a table for a framework that is not installed is never
walked, and a feature that calls a missing framework misbehaves. Install dependencies first.

## Guide flow

1. TimoVM's Mail Writer bootstrap (his guide).
2. `core`, then `base`.
3. The union of the dependencies of the modules you want, e.g. `encounters`, `zones`, `blocks` and `roller`.
4. Each module: its unit codes, the last of which is the enable code.
5. Later: `enable <module>` / `disable <module>`, 1 mail each.

`mailcode.py <module>` prints exactly that module's codes (own units + enable). `patcher.py
install-uc-runtime` installs everything and sets every implemented module's bit.

## Conventions for new units

- A shared framework is tagged 0 and lives in Base or as its own dependency unit.
- A module's data is a separate image with **no header**: just the maps and entries and the framework's
  terminator. Add it to the framework's `.tables` list with the module's bit.
- A module's code features are normal feature images; add them to the walker tables with the bit.
- Every unit has a fixed address recorded in `docs/sram-map.md`; uninstalled units leave holes.
