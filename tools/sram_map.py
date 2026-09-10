"""Empirical free-SRAM check.

The linker map (pokecrystal/pokecrystal.map) lists gaps in SRAM banks 0-3 that no
section claims.  "Unallocated" is not "unused": code can still write there through a
pointer.  This script compares those gaps across several saves with different amounts
of play.  A gap that is uniform in every file and identical between them was never
written in any of those sessions.

Usage: python3 tools/sram_map.py [save ...]   (defaults to the three saves in tests/)
"""
import sys

from patcher import GAPS, load_sav, sav_offset

DEFAULT_SAVES = [
    "tests/fresh-mgba-2026-09-04.sav",     # minutes of play, mGBA
    "tests/vc-2026-09-04.sav",             # early game, 3DS VC export
    "tests/vccomplete-2026-09-04.sav",     # 13 Hall of Fame entries, 3DS VC export
]


def summarize(chunk: bytes) -> str:
    """'all 0xNN' if every byte is the same value, else 'mixed(N)' with N distinct values."""
    values = set(chunk)
    if len(values) == 1:
        return f"all 0x{next(iter(values)):02x}"
    return f"mixed({len(values)})"


def main(paths: list[str]) -> int:
    saves = {path: load_sav(path) for path in paths}
    names = [path.split("/")[-1] for path in paths]

    print("| Bank | Range | Size | .sav offsets | " + " | ".join(names) + " | Identical |")
    print("|---|---|---|---|" + "---|" * len(names) + "---|")
    for bank, start, end in GAPS:
        lo, hi = sav_offset(bank, start), sav_offset(bank, end) + 1   # hi is exclusive
        chunks = [sav[lo:hi] for sav in saves.values()]
        identical = all(chunk == chunks[0] for chunk in chunks)
        cells = " | ".join(summarize(chunk) for chunk in chunks)
        print(f"| {bank} | ${start:04X}-${end:04X} | {hi - lo} | {lo:#06x}-{hi - 1:#06x} | {cells} | "
              f"{'yes' if identical else 'NO'} |")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or DEFAULT_SAVES))
