# uc.bin: stubs at $0000, loader at $0040, kernel at $0080
RGBASM  := rgbasm -i pokecrystal/
SRC     := $(wildcard src/uc/*.asm)
OBJ     := $(patsubst src/uc/%.asm,build/%.o,$(SRC))

build/uc.bin: $(OBJ)
	rgblink -x -o $@ -n build/uc.sym $^

build/%.o: src/uc/%.asm
	$(RGBASM) -o $@ $<

clean:
	rm -f build/*.o build/uc.bin build/uc.sym
.PHONY: clean
