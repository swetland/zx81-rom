
all: golden.zx81.hex zx81plus.rom zx81plus.chk zx81v2.rom zx81v2.chk

V := @

%.chk: %.hex
	$(V)diff $< golden.zx81.hex
	$(V)echo SUCCESS - $< is identical to original rom
	$(V)touch $@

%.rom: %.asm
	$(V)z80asm --list=$@.lst --label=$@.xref --output=$@ $<

%.hex: %.rom
	$(V)xxd -g1 $< > $@

clean:
	$(V)rm -f *.hex *.lst *.xref *.chk zx81plus.rom zx81v2.rom
