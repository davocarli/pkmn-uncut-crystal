# Setup resilience: keeping the OAM DMA hook alive (2026-09-05)

## The single point of failure
The entire persistent framework depends on `wSpecialPhoneCallID` (`$DC31`, **inside saved `wPlayerData`**) holding the invalid ID `$9C`. `CheckSpecialPhoneCall` (engine/phone/phone.asm) runs once per overworld step, indexes `SpecialPhoneCallList` by `(ID-1)*6`, and `call _hl_`s the result; an invalid ID indexes past the table into bytes that jump to TimoVM's reinstall routine, which re-plants the `$FF80` hook and re-arms `$9C`.

TimoVM's dispatcher only re-arms when the byte is **zero** (`or [hl] / jr nz`), so a queued *legitimate* call ID (small, nonzero) is left intact to run. Normally the running hook re-applies `$9C` after the call resolves. **Failure:** save + reset while a legit ID is queued → the legit ID persists in the save → after it runs, the byte is 0 and nothing re-arms → hook dead → all features gone.

## Which legit calls can fire (data/phone/special_calls.asm, queued via `specialphonecall`)
| Trigger | Where | Post-E4 reachable? |
|---|---|---|
| SPECIALCALL_ASSISTANT / MASTERBALL / SSTICKET / WORRIED / ROBBED / WEIRDBROADCAST | story maps (Violet Gym, Dragon Shrine, Hall of Fame, Route 31, Mr Pokémon's, Radio Tower) | one-time story only |
| **SPECIALCALL_POKERUS** | Pokémon Center nurse when a party mon has Pokérus | **yes** — Pokérus is still rolled in battle post-game |
| **SPECIALCALL_BIKESHOP** | `wBikeStep` reaches 1024 (events.asm), only while `wPlayerState == PLAYER_BIKE` | **yes**, and *we can trigger it ourselves* via a naive B-to-Run |

## Why there is no automatic, hook-independent backstop
The special call is the **only** per-step ROM `call` that dispatches through a saved-WRAM byte. Every other candidate the player suggested (scene scripts `wCurMapSceneScriptsPointer`, map callbacks, map scripts) is reloaded from the **ROM map header on every map load** (`CopyMapAttributes`), so a repoint into saved WRAM cannot survive one map transition without the per-frame hook maintaining it — i.e. it needs the very hook we are trying to recover. (The earlier "doesn't fire every frame" objection was real but secondary; ROM-sourced reload is the disqualifier.)

## Decision (2026-09-07, supersedes 2026-09-05): adopt save-time parking. IN SCOPE.

**Implemented and verified in mGBA 2026-09-10** (`UCFrame` in `src/uc/kernel.asm`, 57 B): with ID 7 queued at save time, reset + two steps fires Mom's call and the framework survives; the same sequence without the hook loses it (baseline reproduced the same day). Bike-shop replay and nurse fix: written and verified on the cartridge save 2026-09-10.
The user reopened this after reading the framework: the failure is a *reset while a story ID is queued at save time*, and the game announces every save in advance — every save path in `engine/menus/save.asm` calls `PauseGameLogic` (sets `wGameLogicPaused` = 1) **before** printing "SAVING... DON'T TURN OFF THE POWER", i.e. dozens of frames before `SavePlayerData` copies WRAM. That is the "hook into the save function": a per-frame check of one byte.

Mechanism (park at save, replay at reinstall):
```
per frame (dispatcher / kernel):
    if wGameLogicPaused != 0 and ID not in {0, $9C}:
        wParkedCall = ID          # 1 byte of saved WRAM (TimoVM's free padding $DA47-$DA71)
        ID = $9C
per frame, once wGameLogicPaused is 0 again (v2, 2026-09-07 — no reinstall extension, TimoVM's bytes are untouched):
    if wParkedCall != 0:
        ID = wParkedCall
        wParkedCall = 0           # the NEXT step evaluates the story call via the vanilla path/gate
```
Both halves are kernel hook 1 in `docs/core-design.md`, running from WRAM bank 4 through the
bank-1 accessors. Restoring on un-pause covers "saved and kept playing" (fires next step) and
"answered NO" (byte goes back) as well as reload-after-reset (hook up after one step, kernel
loads on the next idle frame, restore follows).
- Every story call still fires, one step later than vanilla at most. No location-gate logic of ours: the vanilla `CheckSpecialPhoneCall` does it on the following step.
- Both halves live in the kernel (WRAM bank 4). Saved-WRAM cost: 1 parked byte at `$DA0E`, which the installer zeroes. ~40 B of kernel.
- **Bike-shop trigger replay — CONFIRMED by the user 2026-09-07, in `core`** (kernel hook 2, `docs/core-design.md`): replicate every vanilla condition (flag set, on the bike, map has phone service, `wBikeStep ≥ 1024`) with "ID == `$9C`" standing in for vanilla's "ID == 0", then write `SPECIALCALL_BIKESHOP` and clear the flag. ~35 B; a Step hook (main thread, per step), so calling the ROM helper `GetMapPhoneService` is safe.
- Not covered, so the **repair item stays**: the cold case (hook already down when the save was made: first install, post-crash). Repair paths unchanged: repair TM (Phase 1 research), TM15 → Mail Writer reactivate code, patcher one-click repair.
- **Pokérus nurse branch — IN `core` (user, 2026-09-10), designed:** present 0 to scripts (zero the byte every frame while `wScriptRunning` ≠ 0 and it reads `$9C`; his dispatcher re-arms, we re-zero, the main thread only sees 0). `docs/core-design.md` hook 3.
- B-to-Run still uses the step-byte rewrite.

### Superseded decision (2026-09-05): document + repair only
---
### Earlier variant (2026-09-05): park whenever queued, replay mid-step with our own location gate — superseded by the simpler save-time variant above

### "Park and replay": keep the saved byte at `$9C` without losing a single legit call
Facts this rests on (verified in the disassembly):
- `CheckSpecialPhoneCall` is only evaluated from `CountStep`, i.e. once per **completed step**. The player cannot open the start menu (and therefore cannot save) while a step is in progress.
- Legit caller scripts end with `specialphonecall SPECIALCALL_NONE` (byte → 0), after which TimoVM's dispatcher re-arms `$9C` on the next frame.
- The location gate is a fixed 8-entry ROM table: IDs 1–4 and 8 are `SpecialCallOnlyWhenOutside` (`wEnvironment` ∈ {TOWN, ROUTE}); 5–7 (SSTICKET, BIKESHOP, WORRIED) are `WhereverYouAre`. Identical in both revisions.

L1, every frame:
1. Read `wSpecialPhoneCallID`. If it is `$9C` or `0` → nothing (0 is re-armed by TimoVM's dispatcher).
2. Otherwise a story script has just queued a legit ID **L**: copy L (2 bytes) into `wParkedCall` (2 bytes of saved WRAM in TimoVM's free padding, e.g. `$DA70–$DA71`), and write `$9C` back. From this frame on, the byte the save routine copies is `$9C`. **This is the whole fix.**
3. If `wParkedCall ≠ 0` **and** a step is in progress (`wPlayerStepFlags`) **and** `wLinkMode == 0` **and** L's location gate passes (1-byte bitmap of "outside-only" IDs, evaluated against `wEnvironment`): write L back into `wSpecialPhoneCallID` and clear `wParkedCall`. `CountStep` consumes it at the end of *this* step — no menu can open in between — the vanilla caller script runs, clears the byte, and the dispatcher re-arms `$9C`. If for any reason it is not consumed, step 2 parks it again next frame.

Net behaviour: every story call fires exactly as in vanilla (same location semantics, delayed at most one step), and the saved value of the arm byte is `$9C` at every moment a save is possible. Cost ≈ 35–45 B of L1, 2 B saved WRAM, 1 B bitmap. `wParkedCall` must be zeroed by the installer/patcher.

### Also restores content TimoVM's framework silently loses
Because his arm byte is never 0, two vanilla triggers never fire under his setup today:
- **Bike-shop call**: `events.asm` queues `SPECIALCALL_BIKESHOP` only if the byte is 0. Fix: L1 replicates the trigger (`STATUSFLAGS2_BIKE_SHOP_CALL_F` set and `wBikeStep ≥ 1024` → park BIKESHOP, clear the flag). ~15 B.
- **Pokérus nurse dialogue / Elm's Pokérus call**: `std_scripts.asm:127` uses `checkphonecall` ("is a call already stored?") which returns TRUE for `$9C`, so the branch is skipped. Restoring this needs the byte to read 0 during that script; candidate refinement: present 0 while `wScriptRunning` is set inside a Pokémon Center and re-arm on exit. **Deferred; flagged as a known inherited limitation until designed.**

### B-to-Run
Use the queued-step-byte rewrite, never `PLAYER_BIKE` (`wBikeStep` only advances while `wPlayerState == PLAYER_BIKE`). With park-and-replay this is no longer load-bearing for resilience, but it still avoids spurious bike-shop calls and the bike-tile/music side effects.

### Cold case (hook already down when the game was saved: first install, or a prior crash)
Nothing can park the ID, so the legit call fires after reset (content preserved), the byte goes to 0, and the hook stays down. Recovery: TM15 → Mail Writer → reactivate code `3E 9C EA 31 DC C9` (`ld a,$9C ; ld [wSpecialPhoneCallID],a ; ret`), hook-independent; and a one-click **repair** in the patcher. No automatic hook-independent backstop exists — every map-event vector is reloaded from ROM per map load.
