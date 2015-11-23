########################################################################
#
# Pull together raw ROM files into .mem files.
#
# Particulary, the project needs pet2001_rom2.mem and charrom.mem
#
# Raw ROM files come from Vice-2.2.  ROM contents are Copyright by
# Commodore Business Machines and are used without permission.
#
########################################################################

TARGETS=pet2001_rom1.mem pet2001_rom1.v pet2001_rom2.mem pet2001_rom2.v

BMMFILE=pet2001.bmm
BIN2MEM=./bin2mem.pl
CAT=/bin/cat

DATA2MEM=data2mem

default: $(TARGETS)

pet2001_rom1.mem: kernel1 basic1 edit1g
	$(BIN2MEM) 0xc000 basic1 > $@
	$(BIN2MEM) 0xe000 edit1g >> $@
	$(CAT) charrom.mem >> $@
	$(BIN2MEM) 0xf000 kernel1 >> $@

pet2001_rom2.mem: kernel2 basic2 edit2g
	$(BIN2MEM) 0xc000 basic2 > $@
	$(BIN2MEM) 0xe000 edit2g >> $@
	$(CAT) charrom.mem >> $@
	$(BIN2MEM) 0xf000 kernel2 >> $@
%.v: %.mem
	$(DATA2MEM) -bm $(BMMFILE) -bd $< -o v $@

clean:
	$(RM) $(TARGETS)
