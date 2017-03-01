
PROJNM=Pet2001_Arty
SRCDIR=src
SOURCES= \
	$(SRCDIR)/constrs/Pet2001_Arty.xdc		\
	$(SRCDIR)/rtl/Pet2001_Arty.v			\
	$(SRCDIR)/rtl/pet2001hw/via6522.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001vidram.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001uart_keys.v	\
	$(SRCDIR)/rtl/pet2001hw/pet2001hw.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001ram.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001ntsc.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001roms.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001io.v		\
	$(SRCDIR)/rtl/pet2001hw/pia6520.v		\
	$(SRCDIR)/rtl/cpu6502/cpu6502.v			\
	$(SRCDIR)/rtl/misc/uart.v			\
	$(SRCDIR)/rtl/pet2001_top.v

ROMSRCS= \
	$(SRCDIR)/rtl/roms/charrom			\
	$(SRCDIR)/rtl/roms/basic1			\
	$(SRCDIR)/rtl/roms/basic2			\
	$(SRCDIR)/rtl/roms/edit1g			\
	$(SRCDIR)/rtl/roms/edit2g			\
	$(SRCDIR)/rtl/roms/kernel1			\
	$(SRCDIR)/rtl/roms/kernel2

ROMS= 	$(SRCDIR)/rtl/roms/pet2001_rom2.mem		\
	$(SRCDIR)/rtl/roms/pet2001_rom1.mem

ifndef XILINX_VIVADO
$(error XILINX_VIVADO must be set to point to Xilinx tools)
endif

VIVADO=$(XILINX_VIVADO)/bin/vivado

.PHONY: default project bitstream roms program

default: project roms

PROJECT_FILE=$(PROJNM)/$(PROJNM).xpr

project: $(PROJECT_FILE)

$(PROJECT_FILE): 
	$(VIVADO) -mode batch -source project.tcl

BITSTREAM=$(PROJNM)/$(PROJNM).runs/impl_1/$(PROJNM).bit

bitstream: $(BITSTREAM) 

$(BITSTREAM): $(SOURCES) $(ROMS) $(PROJECT_FILE)
	echo Building $(BITSTREAM) from sources
	$(VIVADO) -mode batch -source bitstream.tcl -tclargs $(PROJNM)

roms: $(ROMS)

$(ROMS): $(ROMSRCS)
	(cd $(SRCDIR)/rtl/roms ; $(MAKE))

program: $(BITSTREAM)
	djtgcfg prog -d Arty -i 0 -f $(BITSTREAM)


