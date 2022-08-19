
all: check

check:: zx81plus.hex golden.zx81.hex
	@diff zx81plus.hex golden.zx81.hex
	@echo SUCCESS - identical to original rom

zx81plus.rom: zx81plus.asm
	z80asm --list=zx81plus.lst --label=zx81plus.xref --output=zx81plus.rom -v zx81plus.asm

zx81plus.hex: zx81plus.rom
	xxd -g1 zx81plus.rom > zx81plus.hex

golden.zx81.hex: golden.zx81.rom
	xxd -g1 golden.zx81.rom > golden.zx81.hex

clean:
	rm -f zx81plus.rom zx81plus.hex zx81plus.lst zx81plus.xref
	rm -f golden.zx81.hex
