# Install modules (2026-09-21)

The program is installed as **units** (one image at a fixed address, delivered by one mail-code
group) grouped into **modules** the player picks. Two mechanisms, deliberately separate:

- **Signatures say what is installed.** Every image starts with `"UC"`; the runtime's walker skips a
  feature whose signature is missing. Frameworks never check that a dependency is present: the guide
  says to install dependencies first, and skipping that is user error.
- **`UCModules` (slot4.asm) says what is enabled.** One bit per module, starts at 0. A module's
  install ends with a one-mail code that sets its bit; `mailcode.py enable|disable <module>` toggles
  it later. Features and tables tagged with a bit are skipped while it is clear; tag 0 means always on.

## Where the bits are checked (three places, nothing else)

| Where | What is gated | Cost |
|---|---|---|
| `RunFeatures` in slot4.asm | each feature table entry is `dw address, db module` | 13 B + 1 B/feature |
| `encounters.asm` `.tables` | list of `db module, dw table`, ended by `TABLE_END`; each table is a module's own image | ~26 B |
| `zones.asm` `.tables` | same | ~26 B |

## Modules

| Module | Bit | Own units | Depends on |
|---|---|---|---|
| base | – | core, runtime (slot4), GS Ball, Trainer House; also zeroes `UCZoneCurrent` | – |
| encounters | – | `UCEncounters` (shared framework) | base |
| zones | – | `UCZones` (shared framework) | base |
| exclusives | 0 | `UCExclusivesTable` | encounters |
| kanto | 1 | `UCKantoZones`, `UCKantoEncounters` | encounters, zones |
| cut | 2 | (radio, map instances, tables, roamer data — to come) | encounters, zones, map, roam |
| 251 | 3 | (caves, Mew/Mewtwo, starter roamers, tables — to come) | encounters, zones, map, npc, roam |
| qol | 4 | (to come) | – |

Definitions live in `tools/patcher.py` `UC_MODULES` and `src/uc/module_constants.asm`; keep them in step.

## Guide flow

1. TimoVM's Mail Writer bootstrap (his guide).
2. `core`, then `base`.
3. The union of the dependencies of the modules you want, e.g. `encounters` and `zones`.
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
