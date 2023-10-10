
BIN2HEX=/usr/bin/hexdump -v -e '/1 "%02X\n"'

TARGETS=program.mem

.PHONY: default clean

default: $(TARGETS)

clean:
	 $(RM) *.mem

%.mem: %.prg
	$(BIN2HEX) $< > $@

