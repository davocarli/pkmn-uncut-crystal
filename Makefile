# uc.bin: stubs at $0000, loader at $0040, kernel at $0080, slot 4 from $0200
RGBASM  := rgbasm -i pokecrystal/ -i src/uc/
SRC     := $(wildcard src/uc/*.asm src/uc/features/*.asm)
OBJ     := $(addprefix build/,$(notdir $(SRC:.asm=.o)))

build/uc.bin: $(OBJ)
	rgblink -x -o $@ -n build/uc.sym $^

build/%.o: src/uc/%.asm
	$(RGBASM) -o $@ $<

build/%.o: src/uc/features/%.asm
	$(RGBASM) -o $@ $<

clean:
	rm -f build/*.o build/uc.bin build/uc.sym
.PHONY: clean
