# uc.bin: stubs at $0000, loader at $0040, kernel at $0080, slot 4 from $0200 (bank 4 address - $D000; window 5 images at $1108+, see patcher.py)
# src/uc: core (loader, kernel, runtime, window loader), frameworks (shared, module-tagged tables), features (one per module feature), shelved (not built)
RGBASM  := rgbasm -i pokecrystal/ -i src/uc/
SRC     := $(wildcard src/uc/core/*.asm src/uc/frameworks/*.asm src/uc/features/*.asm)
OBJ     := $(addprefix build/,$(notdir $(SRC:.asm=.o)))

build/uc.bin: $(OBJ)
	rgblink -x -o $@ -n build/uc.sym $^

build/%.o: src/uc/core/%.asm
	$(RGBASM) -o $@ $<

build/%.o: src/uc/frameworks/%.asm
	$(RGBASM) -o $@ $<

build/%.o: src/uc/features/%.asm
	$(RGBASM) -o $@ $<

# constants and macros are included, not linked: rebuild everything when one changes
$(OBJ): $(wildcard src/uc/core/*_constants.asm src/uc/frameworks/*_constants.asm src/uc/npcs/*.asm)

clean:
	rm -f build/*.o build/uc.bin build/uc.sym
.PHONY: clean
