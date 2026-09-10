"""Build the payload that installs the uc core over a TimoVM setup.

Output is hex for TimoVM's MailConverter, 16 bytes per line like his guides.
"""

import sys
from patcher import uc_core_writes

MAIL_BASE = 0xD280  # wOTPartyCount, where the mail writer writes payloads
MAIL_MAX = 416  # 26 mail limit
OPEN_SRAM = 0x2FCB
CLOSE_SRAM = 0x2FE1
COPY_BYTES = 0x3026


def ld_a(n):
    return bytes([0x3E, n])


def ld_c(n):
    return bytes([0x0E, n])


def ld_bc(nn):
    return bytes([0x01]) + nn.to_bytes(2, "little")


def ld_de(nn):
    return bytes([0x11]) + nn.to_bytes(2, "little")


def ld_hl(nn):
    return bytes([0x21]) + nn.to_bytes(2, "little")


def call(nn):
    return bytes([0xCD]) + nn.to_bytes(2, "little")


RET = bytes([0xC9])


def format_hex(payload):
    if len(payload) > MAIL_MAX:
        raise ValueError(f"payload is {len(payload)} bytes, max {MAIL_MAX}")
    return "\n".join(
        payload[i : i + 16].hex(" ").upper() for i in range(0, len(payload), 16)
    )


def format_codes(payloads):
    out = []
    for n, payload in enumerate(payloads, 1):
        out.append(f"code {n} of {len(payloads)} ({len(payload)} bytes)")
        out.append(format_hex(payload))
        out.append("")
    return "\n".join(out)


def installer_code(writes, start):
    """Writes hexcode to perform a sequence of writes to its address."""
    code = b""
    for i in range(len(writes)):
        bank, addr, data = writes[i]
        if bank is not None:
            # Point to the correct bank and open SRAM
            code += ld_a(bank) + call(OPEN_SRAM)
        if i == 0:
            # Load the starting address
            code += ld_hl(start)
        # Write, write, write
        # b is 0 after the first CopyBytes
        if i == 0:
            count = ld_bc(len(data))
        elif len(data) > 255:
            raise ValueError(
                f"write {i} is {len(data)} bytes, only the first may exceed 255"
            )
        else:
            count = ld_c(len(data))
        code += ld_de(addr) + count + call(COPY_BYTES)
    return code + call(CLOSE_SRAM) + RET


def installer(writes):
    """Generates a complete payload: code, then the data to be written."""
    code = installer_code(writes, 0)
    code = installer_code(writes, MAIL_BASE + len(code))
    data = b"".join(data for _, _, data in writes)
    return code + data


def installers(writes):
    """One payload per 26 mails, writes split across them as needed"""
    payloads = []
    current = []
    queue = list(writes)
    while queue:
        bank, addr, data = queue.pop(0)
        # only the first write of a payload may exceed 255 bytes
        fits = not current or len(data) <= 255
        if fits and len(installer(current + [(bank, addr, data)])) <= MAIL_MAX:
            current.append((bank, addr, data))
            continue
        room = MAIL_MAX - len(installer(current + [(bank, addr, b"")]))
        if current:
            room = min(room, 255)
        if room > 0:
            current.append((bank, addr, data[:room]))
            queue.insert(0, (bank, addr + room, data[room:]))
        payloads.append(installer(current))
        current = []
    if current:
        payloads.append(installer(current))
    return payloads


def written_bytes(payloads):
    """what the payloads would leave in memory, {(bank, addr): byte}"""
    mem = {}
    for payload in payloads:
        # walk the code, each copy's data follows the previous one
        src = None
        i = 0
        bank = None
        while payload[i] != RET[0]:
            op = payload[i]
            if op == 0x3E:
                bank = payload[i + 1]
                i += 2
            elif op == 0x21:
                src = int.from_bytes(payload[i + 1 : i + 3], "little") - MAIL_BASE
                i += 3
            elif op == 0x11:
                addr = int.from_bytes(payload[i + 1 : i + 3], "little")
                i += 3
            elif op == 0x01:
                count = int.from_bytes(payload[i + 1 : i + 3], "little")
                i += 3
            elif op == 0x0E:
                count = payload[i + 1]
                i += 2
            elif op == 0xCD:
                target = int.from_bytes(payload[i + 1 : i + 3], "little")
                i += 3
                if target == COPY_BYTES:
                    key = bank if addr < 0xC000 else None
                    for k in range(count):
                        mem[(key, addr + k)] = payload[src + k]
                    src += count
                elif target == CLOSE_SRAM:
                    bank = None
            else:
                raise ValueError(f"unexpected opcode {op:#x} at {i}")
    return mem


def main(argv):
    payloads = installers(uc_core_writes())
    print(format_codes(payloads))
    if len(argv) > 1:
        for n, payload in enumerate(payloads, 1):
            with open(f"{argv[1]}-{n}.bin", "wb") as f:
                f.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
