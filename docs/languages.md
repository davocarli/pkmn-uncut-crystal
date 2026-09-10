# `core` across Crystal releases (researched 2026-09-10)

Sources: TimoVM's per-language codes on the Glitch City wiki (Mail Writer, Mail Writer Codes "Setting up an OAM DMA hijack", RAM Writer), cached in `.research/wiki/`; pokecrystal for EN. Nothing here was run on a non-English ROM — every non-EN value below is read off TimoVM's published byte codes, and the "inferred" rows still need a look at the actual ROM.

## Verdict

| Release | WRAM map | SRAM map | ROM addresses | TimoVM layout | Port cost |
|---|---|---|---|---|---|
| EN v1.0 / v1.1 | same | same | same | same | done (`docs/revision-diff.md`) |
| FR, DE, SP | same as EN | same as EN (inferred) | home bank shifted by a constant; nurse script likely same | same bytes as EN except `CopyBytes` and the call ID; extra bootstrap jump | rebuild with a per-language include; patch the same four offsets |
| IT | same as EN | same as EN (inferred) | shifted by a constant | **different layout** (see below) | rebuild + different patch offsets; Step runs with interrupts on |
| JP | different | different (8 banks) | different | different | full re-port; needs the JP RAM map and a new WRAM-bank survey |
| KOR | — | — | — | — | no Korean Crystal exists |

3DS VC is v1.1 of the same language, so it needs nothing extra.

## The five Western releases share the RAM layout

Evidence, all from codes that TimoVM publishes as one column for EN/FR/DE/IT/SP:
- Mail Writer: "Crystal: installed at `$D852`, writes bytes from `$D280`" for all five.
- DMA hijack setup: framework at `$DA15`, `wSpecialPhoneCallID` `$DC31`, slot 1 `$D6F6`, slot 2 `$DA93` in every Western code.
- RAM Writer installer: `ld a,3 / ld bc,$BD / ld de,$BE2F` in all five, so SRAM bank 3 ends at the same place (same box size), which is the strongest hint that bank 0 matches too.

So every `w*` and `s*` address in `src/uc/` carries over to FR/DE/IT/SP unchanged. Only ROM addresses, the call ID, and the framework patch offsets change.

## ROM: the home bank is shifted by a constant per language

Read off the RAM Writer body (same program, five columns):

| Routine | EN | FR | DE | IT | SP |
|---|---|---|---|---|---|
| `OpenSRAM` | `$2FCB` | `$2FB8` | `$2FB5` | `$2FB9` | `$2FB5` |
| `CloseSRAM` | `$2FE1` | `$2FCE` | `$2FCB` | `$2FCF` | `$2FCB` |
| `CopyBytes` | `$3026` | `$3013` | `$3010` | `$3014` | `$3010` |
| `ByteFill` | `$3041` | `$302E` | `$302B` | `$302F` | `$302B` |
| `JoyTextDelay_ForcehJoyDown` | `$354B` | `$3538` | `$3535` | `$3539` | `$3535` |
| **delta** | 0 | **−$13** | **−$16** | **−$12** | **−$16** |

The delta is identical for all five routines, so everything between `$2FCB` and `$354B` moves together. That covers `_hl_` (`$2FEC`) and `FarCopyWRAM` (`$306B`): inferred, not verified. Two things we use sit outside the range:
- `GetMapPhoneService` `$2D05`: below the verified range. The shift most likely starts in `home/text.asm` (localised control characters), well before `$2D05`, but confirm in each ROM.
- `PrintBCDNumber` (`$38CC`, used by the Mail Writer, not by us) shifts by −$1D in FR and −$20 in SP, so a second shift point exists between `$354B` and `$38CC`. Nothing of ours lives there.

Nurse hook: bank `$2F` opens with `StdScripts` at `$4000` and `PokecenterNurseScript` follows shortly after; scripts hold no text, so `2F:411F` is probably the same in the four Western localisations. Verify per ROM; it is one byte compare in `UCFrame`.

## Special Call ID per language

The garbage-table landing differs per ROM, so the ID and where it lands differ too:

| | EN | FR | DE | IT | SP | JP |
|---|---|---|---|---|---|---|
| ID | `$9C` | `$ED` | `$ED` | `$EB` | `$A5` | `$68` |
| lands at | `$DA21` (reinstall) | `$DA0A` | `$DA0A` | `$DAAA` | `$DAE5` | `$DEBA` |
| bootstrap | none | `jr +$15` in `wWiltonFightCount`/`wKenjiFightCount` | same | `jr $DA93` | `jp $DA21` inside `wEventFlags` | `jp $DA21` inside a Day-Care nickname |

`SPECIALCALL_ACE` is hard-coded three times in `kernel.asm` (bike replay, parking, nurse). It becomes a per-language constant. FR/DE forbid refighting Wilton and Kenji because their fight counters are the bootstrap; `core` adds no new restriction of that kind.

## TimoVM's framework layout

**EN, FR, DE, SP:** byte-identical except the `CopyBytes` operand and the ID. Our four patched bytes sit at the same offsets:

| Site | EN old | FR old | DE/SP old | new |
|---|---|---|---|---|
| `$DA1A` hook `call z, $DA3A` | `3A DA` | `3A DA` | `3A DA` | `DA CF` |
| `$DA37` reinstall `call CopyBytes` | `26 30` | `13 30` | `10 30` | `47 DA` |

`patcher.py` currently accepts only the EN old bytes; a language parameter fixes that.

**IT** is a different program in the same addresses:
- `$DA15`: dispatcher only (`ld hl,$DC31 / or [hl] / jr nz / ld [hl],$EB`, 8 B), then `nop`s to a `ret` at `$DA46`.
- `$DA93`: reinstall, **no `di`/`reti`**, ends in `jp CopyBytes` (copies 17 B from `$DAAC` to `$C000`).
- `$DAAA`: `jr $DA93` (the landing). `$DAAC–$DABC`: the hook template, which calls `$DA15` and slot 1 (`$D6F6`) directly. No slots 2 and 3.

The `core` idea still fits: divert the template's `call $DA15` to `UCFrameStub` (which calls the dispatcher itself), and the reinstall's `jp CopyBytes` to `jp UCLoader` (the loader starts with `call CopyBytes` and ends by returning to the ROM caller). Two consequences: the offsets to patch are different, and the Step context runs with interrupts enabled, so nothing in `UCStep` may assume otherwise. `$DA47–$DA71` is still free.

## Japanese Crystal is a separate port

- WRAM differs: `wSpecialPhoneCallID` `$DBF7`, slot 1 `$D6E9`, slot 2 `$DA86`, Mail Writer buffer `$D2B1`, wrong-pocket TM lands on box names (`$DB68`).
- ROM differs: `CopyBytes` `$2FF2`, `ByteFill` `$300D` (delta −$34 from EN, and the rest of the bank differs by more than a shift).
- SRAM differs: 30-Pokémon boxes with 5-character names change every bank-0 offset, and the cart has 8 banks. Mobile data (`SRAM Mobile 1–4` in pokecrystal's `sram.asm`) lives in banks 4–7, **not** in bank 0, so slot 4's window is not "mobile space"; it just has no meaning on the JP map until someone builds one.
- WRAM bank 4, the kernel bank, is written by `mobile_5f.asm` (News script RAM). That code is unreachable in EN (`docs/wram-banks.md`) but the mobile menus are live in JP, so the bank survey must be redone there.

## What a multi-language build needs

1. `src/uc/lang/<xx>.inc` holding: `OpenSRAM`, `CloseSRAM`, `CopyBytes`, `FarCopyWRAM`, `_hl_`, `GetMapPhoneService`, `NURSE_CHECKPHONECALL_BANK/ADDR`, `SPECIALCALL_ACE`, `TIMOVM_DISPATCHER`; the `.asm` files `INCLUDE` it instead of their own `DEF`s. Makefile builds `build/uc-<xx>.bin`.
2. `patcher.py` and the mail-code generator take a language and pick the old bytes and patch offsets (EN/FR/DE/SP one table, IT another).
3. For the TimoVM proposal: ship EN, and send the list in item 1 as "the nine values I need per language". He has the ROMs.
