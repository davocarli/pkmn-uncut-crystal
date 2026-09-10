TABLE_HEADER = "| Label | v1.0 Address | v1.1 Address | Status | Sav Offset |\n|-------|--------------|--------------|--------|-----------|"


def calc_offset(addr) -> str:
    if addr is None:
        return "-"
    bank, offset = addr
    if bank is None or offset is None:
        return "-"
    return hex((int(bank, 16) * int("2000", 16)) + (int(offset, 16) - int("A000", 16)))


def print_row(var_name):
    addr_10 = addresses_10.get(var_name, None)
    addr_10_label = "-" if addr_10 is None else f"{addr_10[0]}:{addr_10[1]}"
    addr_11 = addresses_11.get(var_name, None)
    addr_11_label = "-" if addr_11 is None else f"{addr_11[0]}:{addr_11[1]}"
    if addr_11 is None and addr_10 is None:
        status = "MISSING"
    elif addr_10 is None:
        status = "ADDED"
    elif addr_11 is None:
        status = "REMOVED"
    elif addr_10 != addr_11:
        status = "DIFFERS"
    else:
        status = "OK"
    offset = "-"
    if var_name.startswith("s"):
        offset = calc_offset(addr_10)
    print(f"| {var_name} | {addr_10_label} | {addr_11_label} | {status} | {offset} |")


if __name__ == "__main__":
    addresses_10 = {}
    addresses_11 = {}

    with open("pokecrystal/pokecrystal.sym") as f:
        # iterate through lines
        for line in f:
            line = line.strip()
            if not line.startswith(";") and len(line) > 0 and ":" in line:
                address, var_name = line.split(" ")
                bank, addr = address.split(":")
                addresses_10[var_name] = (bank, addr)

    with open("pokecrystal/pokecrystal11.sym") as f:
        for line in f:
            line = line.strip()
            if not line.startswith(";") and len(line) > 0 and ":" in line:
                address, var_name = line.split(" ")
                bank, addr = address.split(":")
                addresses_11[var_name] = (bank, addr)

    removed_vars = addresses_10.keys() - addresses_11.keys()
    added_vars = addresses_11.keys() - addresses_10.keys()
    changed_vars = [
        var
        for var in addresses_10.keys() & addresses_11.keys()
        if addresses_10[var] != addresses_11[var]
    ]

    print(TABLE_HEADER)

    with open("docs/labels.txt") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("#") and len(line) > 0:
                print_row(line)

    print()
    print()
    if len(removed_vars) > 0:
        print("REMOVED VARIABLES")
        print(TABLE_HEADER)
        for var_name in sorted(removed_vars):
            print_row(var_name)
        print()

    if len(added_vars) > 0:
        print("ADDED VARIABLES")
        print(TABLE_HEADER)
        for var_name in sorted(added_vars):
            print_row(var_name)
        print()

    if len(changed_vars) > 0:
        print("CHANGED VARIABLES")
        print(TABLE_HEADER)
        for var_name in sorted(changed_vars):
            print_row(var_name)
