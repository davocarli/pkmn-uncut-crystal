# uc.bin: stubs at $0000, loader at $0040, kernel at $0080, slot 4 from $0200 (bank 4 address - $D000; window 5 images at $1108+, see patcher.py)
RGBASM  := rgbasm -i pokecrystal/ -i src/uc/
SRC     := $(wildcard src/uc/*.asm src/uc/features/*.asm)
OBJ     := $(addprefix build/,$(notdir $(SRC:.asm=.o)))

build/uc.bin: $(OBJ)
	rgblink -x -o $@ -n build/uc.sym $^

build/%.o: src/uc/%.asm
	$(RGBASM) -o $@ $<

build/%.o: src/uc/features/%.asm
	$(RGBASM) -o $@ $<

# script fragments included by the NPC table
build/cut_npcs.o: $(wildcard src/uc/npcs/*.asm)

# constants and macros are included, not linked: rebuild everything when one changes
$(OBJ): $(wildcard src/uc/*_constants.asm)

clean:
	rm -f build/*.o build/uc.bin build/uc.sym
.PHONY: clean
