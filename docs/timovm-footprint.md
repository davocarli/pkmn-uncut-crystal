# TimoVM ACE setup — persistent footprint in an English Crystal save (verified 2026-09-04)

Source: Glitch City Wiki pages "Guides:Fast 0x1500 ACE v2", "Mail writer", "Guides:RAM Writer"; verified byte-for-byte against the user's complete VC save.

## What "the setup" is, after clean-up
The 0x1500 control-code ACE (bad clone + box-name code) is only the *installer*. The v2 guide's clean-up step moves everything into three persistent pieces, all inside the checksummed `wPlayerData` block (so they survive saving and are covered by `sChecksum`):

| Piece | WRAM address | `.sav` offset (main block) | Size | Content |
|---|---|---|---|---|
| Mail Writer program | `$D9C0–$D9F1` (`wMobileBattleRoomSceneID` + unused mobile scene bytes) | `0x254E–0x257F` | 50 B | `11 80 D2 D5 D5 D5 21 75 5E CF E1 D1 2A FE 50 38 FB 28 0A 87 86 12 13 23 81 4F 12 18 EF 21 01 C5 4D CD CC 38 1B CD 4B 35 BD 28 D9 38 F0 FE 08 C8 18 F2` (the "general assembly" EN/FR/DE/IT/SP version; expects `a = $04` from the caller) |
| TM15 bootstrap | `$DA10–$DA14` (phone fight counters) | `0x259E–0x25A2` | 5 B | `3E 04 C3 C0 D9` = `ld a, $04 ; jp $D9C0`. `$DA10` is where the game lands when a TM15 is used from the *main* item pocket (wrong-pocket TM effect). |
| Trigger item | `wItems` (`$D893`) | `0x2421…` | 2 B | item `$CE` (TM15) ×1 in any slot of the main pocket. The user's save has it in slot 2. |

## Also installed on the user's save: the Special Call ACE + OAM DMA hijack framework (Mail Writer Codes page, "Setting up an OAM DMA hijack", EN Crystal, 2024-07-29 revision)

| Piece | WRAM | Content / role |
|---|---|---|
| Per-frame hook body (template) | `$DA15–$DA20` (12 B) | `F0 70 D6 F9 CC 3A DA 3E C4 0E 46 C9` = `ldh a,[rWBK] ; sub $F9 ; call z,$DA3A ; ld a,$C4 ; ld c,$46 ; ret`. **Only calls into bank-1 WRAM when `rWBK` says bank 1 is mapped** — TimoVM already uses the readable-`rWBK` guard our §4.3 relies on. Copied to `$C000` (bottom of the "Stack" section, WRAM0) at reinstall. |
| Reinstall routine (Special Call target) | `$DA21–$DA39` (25 B) | `di ; write CD 00 C0 E2 at $FF80` (= `call $C000 ; ldh [c],a`, same length as the original `ld a,$C4 ; ldh [$46],a`, DMA still started via `c=$46`) `; copy 12 B $DA15→$C000 ; reti` |
| Per-frame dispatcher | `$DA3A–$DA46` (13 B) | `ld hl,wSpecialPhoneCallID ; or [hl] ; jr nz,+2 ; ld [hl],$9C ; call $D6F6 ; jr $DA93` — re-arms the invalid special-call ID `$9C` every frame it is zero (so the next step re-runs the reinstall), then runs the three constant-effect slots. |
| Constant-effect slot 1 | `$D6F6–$D71D` (40 B = the `ds 40` before `wMapObjects`; codes are 26 B; `ret` at `$D71D`) | just before `wMapObjects`. User's save holds a 26-byte code here (reads `wBattleMode`, checks SELECT in `hJoypad`, copies party data) — matches the "Catch a trainer's pokémon" constant-effect code. |
| Slot 2 | `$DA93–$DAA3` (17 B) | zero on the user's save. Shipped codes: shiny wild (keep gender), shiny/DVs, force a specific encounter. |
| Slot 3 | `$DAAB–$DABB` (17 B), `ret` at `$DABC` | zero on the user's save. Shipped code: RAM Writer usable in battle. |
| Control codes | — | Reactivate = `ld a,$9C ; ld [wSpecialPhoneCallID],a`. Slot installers write exactly 26/17/17 bytes to the fixed slot addresses and nothing else. |
| Arm byte | `wSpecialPhoneCallID` `$DC31` | must be `$9C` in the save for "one step after reset re-installs the hook" to work. **It is `$00` in the user's complete save**, so on this file the hook is dormant after load until re-armed (the Mail Writer Codes page has a "Manually activate the setup" code). Verify in play: SELECT in a trainer battle does nothing if dormant. |

**WRAM his framework occupies (all inside saved `wPlayerData`):** the `ds 100` padding after `wErinFightCount` (`$DA0E–$DA71`) holds the bootstrap + framework at `$DA10–$DA46`, leaving **`$DA47–$DA71` (43 B) unused and saved** — natural home for our main-thread reinstall extension. Slots 2–3 (`$DA93–$DABC`) are *inside `wEventFlags`* (flags `$108–$257`); see the flag-usage note in the README before allocating custom flags there.

Optional leftover: the unterminated-name ("bad clone") Pokémon, kept in **box 14** on the user's save for reinstalls. Not required once the three pieces exist. Box names are restored to defaults by the clean-up and are not part of the setup.

The user's save does **not** have the RAM Writer installed (no TM17 `$D0` in the main pocket, bank 3 gap untouched).

## Where TimoVM's RAM Writer would go (from the Crystal installer code on the wiki)
`ld a, 3 / ld bc, $00BD / ld de, $BE2F / ld hl, $D29C / call …` — it copies **189 bytes into SRAM bank 3 at `$BE2F–$BEEB`**, i.e. the last padding byte of box 14 plus the start of our bank 3 gap, and makes the first main-pocket item a TM17 (`$D0`) as its trigger. Independent confirmation that the box-bank tail is free space, and a constraint: **if the RAM Writer is to coexist with our program, `03:BE2F–BEEB` is his.** Its installer is also the template for our own install primitive: "copy N bytes from the Mail Writer payload buffer (`$D280+`) into SRAM bank X at Y".

## Consequences for the patcher and the guide
- **Patcher option (a) = exactly the three pieces above** (plus re-checksum). No box names, no glitch Pokémon needed. ~57 bytes. **Implemented as `patcher.py install-timovm` and verified in mGBA 2026-09-07:** patching the fresh save and using TM15 from the pack opens the Mail Writer.
- **Guide divergence point:** end of "Guides:Fast 0x1500 ACE v2" Step 7 (TM15 opens the Mail Writer). Everything before it is TimoVM's; everything after is ours.
- The Mail Writer writes payloads from `$D280` (`wOTPartyCount`), max 428 B, volatile. Our installer payloads copy from there into SRAM.
- **Special Call ACE + OAM DMA hijack = patcher option (b) framework layer.** Source: Mail Writer Codes page, "Setting up an OAM DMA hijack" (EN Crystal). **Implemented as `patcher.py install-dma-hijack` (50 B framework at `$DA15`, 39+41 zeroed slot bytes with `ret`s, arm byte `$9C` at `$DC31`) and verified in mGBA 2026-09-07:** on `build/fresh-hijack.sav` one step installs the hook — `$FF80` = `CD 00 C0 E2 …`, `$C000` = the 12 B hook body, `$DC31` stays `$9C`. Not yet traced: the ROM chain from the `$9C` table entry (`36:$49C9` → `$49DC`, weekday string data) to `$DA21` (BGB exercise).
