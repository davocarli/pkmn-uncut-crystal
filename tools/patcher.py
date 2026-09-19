"""Crystal .sav patcher. Offsets: bank * 0x2000 + addr - 0xA000 (docs/facts.md)."""

import os
import sys

SAV_SIZE = 0x8000  # 4 SRAM banks x 8 KB
SAVE_CHECK_VALUE_1 = 99  # pokecrystal/constants/misc_constants.asm
SAVE_CHECK_VALUE_2 = 127

# Save blocks: checksum range (engine/menus/save.asm), where it's stored, magic bytes
BLOCKS = {
    "main": {  # SRAM bank 1
        "sum_start": 0x2009,  # sGameData
        "sum_end": 0x2B83,  # sGameDataEnd (exclusive)
        "checksum": 0x2D0D,  # sChecksum, 2 bytes LE
        "check1": 0x2008,  # sCheckValue1 == 99
        "check2": 0x2D0F,  # sCheckValue2 == 127
    },
    "backup": {  # SRAM bank 0
        "sum_start": 0x1209,  # sBackupGameData
        "sum_end": 0x1D83,  # sBackupGameDataEnd (exclusive)
        "checksum": 0x1F0D,  # sBackupChecksum, 2 bytes LE
        "check1": 0x1208,
        "check2": 0x1F0F,
    },
}


# Unused SRAM (bank, start, end), see docs/sram-map.md. not checksummed
GAPS = [
    (0, 0xAC6B, 0xB1FF),
    (0, 0xBF12, 0xBFFF),
    (1, 0xBE57, 0xBFFF),
    (2, 0xBE30, 0xBFFF),
    (3, 0xBE30, 0xBFFF),
]


# TimoVM setup, see docs/timovm-footprint.md. all of this is in wPlayerData,
# which the game copies into both save blocks
W_PLAYER_DATA = 0xD47B  # wPlayerData / wGameData
W_PLAYER_DATA_END = 0xDCA5  # wPlayerDataEnd (exclusive)
PLAYER_DATA_IN_BLOCK = {
    "main": 0x2009,
    "backup": 0x1209,
}  # sPlayerData, sBackupPlayerData

W_NUM_ITEMS = 0xD892  # wNumItems; wItems follows: MAX_ITEMS*2 pairs + $FF terminator
MAX_ITEMS = 20
ITEM_TM15 = 0xCE
ITEM_TM17 = 0xD0

# Mail writer, expects a = 4
W_MAIL_WRITER = 0xD9C0
MAIL_WRITER = bytes.fromhex(
    "11 80 D2 D5 D5 D5 21 75 5E CF E1 D1 2A FE 50 38 FB 28 0A 87 86 12 13 23 81"
    "4F 12 18 EF 21 01 C5 4D CD CC 38 1B CD 4B 35 BD 28 D9 38 F0 FE 08 C8 18 F2"
)
# TM15 bootstrap: ld a, 4 / jp $D9C0
W_BOOTSTRAP = 0xDA10
BOOTSTRAP = bytes.fromhex("3E 04 C3 C0 D9")


# OAM DMA hijack framework (wiki: Mail Writer Codes), $DA15-$DA46
W_DMA_HOOK = 0xDA15  # copied to $C000 every step
DMA_HOOK = bytes.fromhex("F0 70 D6 F9 CC 3A DA 3E C4 0E 46 C9")
W_REINSTALL = 0xDA21  # special call target
REINSTALL = bytes.fromhex(
    "F3 0E 0C 11 00 C0 21 80 FF 3E CD 22 7B 22 7A 22 36 E2 21 15 DA CD 26 30 D9"
)
W_DISPATCHER = 0xDA3A
DISPATCHER = bytes.fromhex("21 31 DC B6 20 02 36 9C CD F6 D6 18 4C")
assert W_REINSTALL == W_DMA_HOOK + len(DMA_HOOK)
assert W_DISPATCHER == W_REINSTALL + len(REINSTALL)

# Constant effect slots, nop filled + ret
W_SLOT1, SLOT1_SIZE = 0xD6F6, 39
W_SLOT23, SLOT23_SIZE = (
    0xDA93,
    41,
)
RET = 0xC9

# Invalid special call id, ends up at $DA21 every step
W_SPECIAL_PHONE_CALL_ID = 0xDC31
SPECIALCALL_ACE = 0x9C

# Uncut Crystal Core Constants
UC_BIN = "build/uc.bin"
UC_SYM = "build/uc.sym"
UC_LOADER = (0x40, 0x6B)
UC_KERNEL_OFFSET = 0x80

W_UC_HOOK_CALL = 0xDA1A  # TimoVM Call Hook
UC_HOOK_CALL_OLD = bytes.fromhex("3A DA")
UC_HOOK_CALL_NEW = bytes.fromhex("DA CF")
W_UC_REINSTALL_CALL = 0xDA37  # replaces CopyBytes with UCLoader
UC_REINSTALL_CALL_OLD = bytes.fromhex("26 30")
UC_REINSTALL_CALL_NEW = bytes.fromhex("47 DA")
W_UC_LOADER = 0xDA47
W_UC_PARKED_CALL = 0xDA0E
UC_IMAGE_BANK = 0
UC_IMAGE_OFFSET = 0xAC6B
UC_SLOT4_BASE = 0xD200  # bank 4, loaded from UC_SLOT4_IMAGE by the kernel
UC_SLOT4_IMAGE = 0xAE6B  # sram bank 0
UC_SLOT4_LEN = 0xB200 - UC_SLOT4_IMAGE  # what the kernel copies
# every slot 4 image: (start, end) labels in uc.sym. offset in uc.bin = addr - $D000
UC_SLOT4_IMAGES = [
    ("UCSlot4", "UCSlot4End"),
    ("UCGSBall", "UCGSBallEnd"),
]


def sav_offset(bank: int, addr: int) -> int:
    """bank:addr -> file offset"""
    return bank * 0x2000 + addr - 0xA000


def wram_to_sav(addr: int, block: str = "main") -> int:
    if not W_PLAYER_DATA <= addr < W_PLAYER_DATA_END:
        raise ValueError(f"Address {addr:#x} out of WRAM player data range")
    return PLAYER_DATA_IN_BLOCK[block] + (addr - W_PLAYER_DATA)


def read_sym(path: str):
    """Takes an rgblink .sym file and returns a dict of labels to addresses"""
    labels = {}
    with open(path) as f:
        for line in f:
            if not line.strip().startswith(";"):
                addr, name = line.split()
                labels[name] = int(addr.split(":")[1], 16)
    return labels


def build_uc_image():
    """Builds an SRAM image for the UC Core Kernel"""
    with open(UC_BIN, "rb") as f:
        bindata = f.read()
    symdata = read_sym(UC_SYM)
    stage1_len = symdata["UCStage1End"] - symdata["UCKernel"]
    kernel_len = symdata["UCKernelEnd"] - symdata["UCKernel"]
    if stage1_len > 255:
        raise ValueError("Stage 1 should be a one-byte length")
    stubs_len = symdata["UCStubsEnd"] - symdata["UCFrameStub"]
    pokeb1_len = symdata["UCPokeB1End"] - symdata["UCPokeB1"]
    kernel = bindata[UC_KERNEL_OFFSET : UC_KERNEL_OFFSET + kernel_len]
    stubs = bindata[0:stubs_len]
    pokeb1 = bindata[stubs_len : stubs_len + pokeb1_len]
    return kernel[:stage1_len] + stubs + pokeb1 + kernel[stage1_len:]


def check_dma_hijack(sav: bytearray):
    """Check if TimoVM or UC Core DMA Hijack is installed"""
    for addr, old, new in (
        (W_UC_HOOK_CALL, UC_HOOK_CALL_OLD, UC_HOOK_CALL_NEW),
        (W_UC_REINSTALL_CALL, UC_REINSTALL_CALL_OLD, UC_REINSTALL_CALL_NEW),
    ):
        for block in BLOCKS:
            offset = wram_to_sav(addr, block)
            if sav[offset : offset + 2] not in (old, new):
                raise SystemExit(
                    f"Unexpected value at {addr:#x} in block {block}. Please install dma hijack first."
                )


def patch_save(sav: bytearray, writes: list[tuple[int | None, int, bytes]]):
    """Apply a list of writes to the save file"""
    for bank, addr, data in writes:
        if bank is None:
            for block in BLOCKS:
                offset = wram_to_sav(addr, block)
                sav[offset : offset + len(data)] = data
        else:
            offset = sav_offset(bank, addr)
            sav[offset : offset + len(data)] = data
    fix_checksums(sav)


def install_uc_core(sav: bytearray):
    """Install the UC Core: Redirects TimoVM's two calls to the UC Loader"""
    check_dma_hijack(sav)
    patch_save(sav, uc_core_writes())


def uc_core_writes():
    """List of writes to be performed to install the UC core"""
    with open(UC_BIN, "rb") as f:
        bindata = f.read()
    loader = bindata[UC_LOADER[0] : UC_LOADER[1]]
    return [
        # None = WRAM
        (UC_IMAGE_BANK, UC_IMAGE_OFFSET, build_uc_image()),
        (None, W_UC_LOADER, loader),
        (None, W_UC_PARKED_CALL, bytes(1)),
        (None, W_UC_HOOK_CALL, UC_HOOK_CALL_NEW),
        (None, W_UC_REINSTALL_CALL, UC_REINSTALL_CALL_NEW),
    ]


def check_uc_core(sav: bytearray):
    """Check that the UC core's two call redirects are in place"""
    for addr, new in (
        (W_UC_HOOK_CALL, UC_HOOK_CALL_NEW),
        (W_UC_REINSTALL_CALL, UC_REINSTALL_CALL_NEW),
    ):
        for block in BLOCKS:
            offset = wram_to_sav(addr, block)
            if sav[offset : offset + 2] != new:
                raise SystemExit(
                    f"Unexpected value at {addr:#x} in block {block}. Please install the uc core first."
                )


def install_uc_runtime(sav: bytearray):
    """Install the UC Runtime into slot 4"""
    check_uc_core(sav)
    patch_save(sav, uc_runtime_writes())


def uc_runtime_writes(images=UC_SLOT4_IMAGES):
    """List of writes to be performed to install the UC runtime, one per image"""
    with open(UC_BIN, "rb") as f:
        bindata = f.read()
    symdata = read_sym(UC_SYM)
    writes = []
    for start, end in images:
        addr, end_addr = symdata[start], symdata[end]
        if end_addr - UC_SLOT4_BASE > UC_SLOT4_LEN:
            raise ValueError(f"{start} ends past the slot 4 window")
        offset = addr - 0xD000
        image = bindata[offset : offset + end_addr - addr]
        writes.append((UC_IMAGE_BANK, UC_SLOT4_IMAGE + addr - UC_SLOT4_BASE, image))
    return writes


def add_item(sav: bytearray, block: str, item: int, qty: int = 1) -> str:
    """make sure the main pocket has at least qty of item. returns present/topped-up/added"""
    num_items_offset = wram_to_sav(W_NUM_ITEMS, block)
    num_items = sav[num_items_offset]
    for i in range(num_items):
        if sav[num_items_offset + 1 + 2 * i] == item:
            qty_offset = num_items_offset + 1 + 2 * i + 1
            if sav[qty_offset] >= qty:
                return "present"
            sav[qty_offset] = qty
            return "topped-up"
    if num_items >= MAX_ITEMS:
        raise SystemExit(f"{block}: main item pocket is full ({MAX_ITEMS} items)")
    item_offset = num_items_offset + 1 + num_items * 2
    sav[item_offset] = item
    sav[item_offset + 1] = qty
    sav[item_offset + 2] = 0xFF
    sav[num_items_offset] += 1
    return "added"


def install_timovm(sav: bytearray):
    """Mail writer + TM15 bootstrap + the TM"""
    for block in BLOCKS:
        for addr, value in ((W_MAIL_WRITER, MAIL_WRITER), (W_BOOTSTRAP, BOOTSTRAP)):
            offset = wram_to_sav(addr, block)
            sav[offset : offset + len(value)] = value
        add_item(sav, block, item=ITEM_TM15, qty=1)
    fix_checksums(sav)


def install_dma_hijack(sav: bytearray):
    """Special call ACE + OAM DMA hijack framework"""
    for block in BLOCKS:
        offset = wram_to_sav(W_DMA_HOOK, block)
        dma_base = DMA_HOOK + REINSTALL + DISPATCHER
        sav[offset : offset + len(dma_base)] = dma_base
        for start, size in ((W_SLOT1, SLOT1_SIZE), (W_SLOT23, SLOT23_SIZE)):
            offset = wram_to_sav(start, block)
            sav[offset : offset + size] = bytes(size)
            sav[offset + size] = RET
        sav[wram_to_sav(W_SPECIAL_PHONE_CALL_ID, block)] = SPECIALCALL_ACE
    fix_checksums(sav)


def compute_checksum(sav: bytes, start: int, end: int) -> int:
    return sum(sav[start:end]) & 0xFFFF


def verify(sav: bytes) -> dict:
    """Stored/computed checksum per block"""
    result = {}
    for block_name, block in BLOCKS.items():
        stored = int.from_bytes(
            sav[block["checksum"] : block["checksum"] + 2], "little"
        )
        computed = compute_checksum(sav, block["sum_start"], block["sum_end"])
        check_values_ok = (
            sav[block["check1"]] == SAVE_CHECK_VALUE_1
            and sav[block["check2"]] == SAVE_CHECK_VALUE_2
        )
        result[block_name] = {
            "stored": stored,
            "computed": computed,
            "check_values_ok": check_values_ok,
            "ok": stored == computed and check_values_ok,
        }
    return result


def fix_checksums(sav: bytearray) -> None:
    """Recompute both checksums in place"""
    for block in BLOCKS.values():
        checksum = compute_checksum(bytes(sav), block["sum_start"], block["sum_end"])
        sav[block["checksum"] : block["checksum"] + 2] = checksum.to_bytes(2, "little")
        sav[block["check1"]] = SAVE_CHECK_VALUE_1
        sav[block["check2"]] = SAVE_CHECK_VALUE_2
    result = verify(bytes(sav))
    assert all([check["ok"] for check in result.values()])


def read_save(path: str) -> tuple[bytes, bytes]:
    """(SRAM, tail). tail = VC footer or mGBA RTC state, written back as is"""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < SAV_SIZE:
        raise SystemExit(
            f"{path}: expected at least {SAV_SIZE:#x} bytes, got {len(data):#x}"
        )
    return data[:SAV_SIZE], data[SAV_SIZE:]


def load_sav(path: str) -> bytes:
    """The four SRAM banks only"""
    return read_save(path)[0]


def write_save(path: str, sav: bytes, tail: bytes) -> None:
    if os.path.exists(path):
        raise SystemExit(f"{path}: exists; refusing to overwrite")
    with open(path, "wb") as f:
        f.write(sav)
        f.write(tail)


def is_crystal_save(sav: bytes) -> bool:
    """Checks the magic bytes in both blocks"""
    return all(block["check_values_ok"] for block in verify(sav).values())


def sentinel_byte(offset: int) -> int:
    """Position dependent fill for the gaps"""
    return (offset & 0xFF) ^ 0xA5


def sentinel_fill(sav: bytearray) -> None:
    for bank, start, end in GAPS:
        for off in range(sav_offset(bank, start), sav_offset(bank, end) + 1):
            sav[off] = sentinel_byte(off)


def sentinel_check(sav: bytes) -> bool:
    """Report bytes that no longer hold the sentinel"""
    clean = True
    for bank, start, end in GAPS:
        lo, hi = sav_offset(bank, start), sav_offset(bank, end) + 1
        changed = [off for off in range(lo, hi) if sav[off] != sentinel_byte(off)]
        where = (
            ""
            if not changed
            else f"  first at {changed[0]:#06x} (bank {bank} ${0xA000 + changed[0] - bank * 0x2000:04X})"
        )
        print(
            f"  bank {bank} ${start:04X}-${end:04X}: {len(changed):4d} of {hi - lo} bytes changed{where}"
        )
        clean = clean and not changed
    return clean


def report(sav: bytes) -> None:
    for name, block in verify(sav).items():
        state = "ok" if block["ok"] else "MISMATCH"
        print(
            f"  {name:7s} stored={block['stored']:#06x} computed={block['computed']:#06x} "
            f"check_values={'ok' if block['check_values_ok'] else 'BAD'}  -> {state}"
        )


def main(argv: list[str]) -> int:
    usage = (
        f"usage: {argv[0]} verify <in.sav> | fix <in.sav> <out.sav>\n"
        f"       {argv[0]} sentinel <in.sav> <out.sav>   (fill SRAM gaps with a marker pattern)\n"
        f"       {argv[0]} sentinel-check <in.sav>       (report gap bytes the game touched)\n"
        f"       {argv[0]} install-timovm <in.sav> <out.sav>  (option (a): Mail Writer + TM15 bootstrap)\n"
        f"       {argv[0]} install-dma-hijack <in.sav> <out.sav>  (option (b): Special Call ACE + OAM DMA hook)"
        f"       {argv[0]} install-uc-core <in.sav> <out.sav>     (Uncut Crystal core: loader + kernel image)\n"
        f"       {argv[0]} install-uc-runtime <in.sav> <out.sav>  (Uncut Crystal runtime: slot 4 image)"
    )
    if len(argv) < 3:
        print(usage, file=sys.stderr)
        return 2
    cmd, src = argv[1], argv[2]
    sav, tail = read_save(src)
    if not is_crystal_save(sav):
        print(f"{src}: check values wrong; not a Pokémon Crystal save", file=sys.stderr)
        return 1

    if cmd == "verify" and len(argv) == 3:
        report(sav)
        return 0 if all(b["ok"] for b in verify(sav).values()) else 1

    if cmd == "fix" and len(argv) == 4:
        patched = bytearray(sav)
        fix_checksums(patched)
        patched = bytes(patched)
        write_save(argv[3], patched, tail)
        print(f"wrote {argv[3]} ({len(tail)}-byte tail preserved)")
        report(patched)
        return 0

    if cmd == "sentinel" and len(argv) == 4:
        patched = bytearray(sav)
        sentinel_fill(patched)
        fix_checksums(patched)
        patched = bytes(patched)
        write_save(argv[3], patched, tail)
        print(f"wrote {argv[3]} ({len(tail)}-byte tail preserved); gaps filled:")
        sentinel_check(patched)
        return 0

    if cmd == "install-timovm" and len(argv) == 4:
        patched = bytearray(sav)
        install_timovm(patched)
        patched = bytes(patched)
        write_save(argv[3], patched, tail)
        changed = sum(1 for a, b in zip(sav, patched) if a != b)
        print(
            f"wrote {argv[3]} ({len(tail)}-byte tail preserved); {changed} bytes changed"
        )
        report(patched)
        return 0

    if cmd == "install-dma-hijack" and len(argv) == 4:
        patched = bytearray(sav)
        install_dma_hijack(patched)
        patched = bytes(patched)
        write_save(argv[3], patched, tail)
        changed = sum(1 for a, b in zip(sav, patched) if a != b)
        print(
            f"wrote {argv[3]} ({len(tail)}-byte tail preserved); {changed} bytes changed"
        )
        report(patched)
        return 0

    if cmd in ("install-uc-core", "install-uc-runtime") and len(argv) == 4:
        patched = bytearray(sav)
        if cmd == "install-uc-core":
            install_uc_core(patched)
        else:
            install_uc_runtime(patched)
        patched = bytes(patched)
        write_save(argv[3], patched, tail)
        changed = sum(1 for a, b in zip(sav, patched) if a != b)
        print(
            f"wrote {argv[3]} ({len(tail)}-byte tail preserved); {changed} bytes changed"
        )
        report(patched)
        return 0

    if cmd == "sentinel-check" and len(argv) == 3:
        return 0 if sentinel_check(sav) else 1

    print(usage, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
