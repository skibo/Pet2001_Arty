########################################################################
#
# Pull together raw ROM files into .mem files.
#
# Raw ROM files come from Vice-2.2.  ROM contents are Copyright by
# Commodore Business Machines and are used without permission.
#
########################################################################

TARGETS=pet2001_rom1.mem pet2001_rom2.mem

BIN2HEX=/usr/bin/hexdump -v -e '/1 "%02X\n"'

default: $(TARGETS)

pet2001_rom1.mem: kernel1 basic1 edit1g charrom
	$(BIN2HEX) basic1 > $@
	$(BIN2HEX) edit1g >> $@
	$(BIN2HEX) charrom >> $@
	$(BIN2HEX) kernel1 >> $@

pet2001_rom2.mem: kernel2 basic2 edit2g charrom
	$(BIN2HEX) basic2 > $@
	$(BIN2HEX) edit2g >> $@
	$(BIN2HEX) charrom >> $@
	$(BIN2HEX) kernel2 >> $@

clean:
	$(RM) $(TARGETS)
