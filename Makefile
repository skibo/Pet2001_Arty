
PROJNM=Pet2001_Arty
SRCDIR=src
SOURCES= \
	$(SRCDIR)/constrs/Pet2001_Arty.xdc		\
	$(SRCDIR)/rtl/Pet2001_Arty.v			\
	$(SRCDIR)/rtl/pet2001_top.v			\
	$(SRCDIR)/rtl/cpu6502/cpu6502.v			\
	$(SRCDIR)/rtl/misc/ps2_intf.v			\
	$(SRCDIR)/rtl/pet2001hw/pet2001ps2_key.v	\
	$(SRCDIR)/rtl/pet2001hw/pia6520.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001ram.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001vga.v		\
	$(SRCDIR)/rtl/pet2001hw/via6522.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001io.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001hw.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001roms.v		\
	$(SRCDIR)/rtl/pet2001hw/pet2001vidram.v

ROMS=	$(SRCDIR)/rtl/roms/pet2001_rom2.mem		\
	$(SRCDIR)/rtl/roms/pet2001_rom1.mem

ifndef XILINX_VIVADO
$(error XILINX_VIVADO must be set to point to Xilinx tools)
endif

VIVADO=$(XILINX_VIVADO)/bin/vivado
XSDB=$(XILINX_VIVADO)/bin/xsdb

.PHONY: default project bitstream program

default: project

PROJECT_FILE=$(PROJNM)/$(PROJNM).xpr

project: $(PROJECT_FILE)

$(PROJECT_FILE): $(ROMS)
	$(VIVADO) -mode batch -source project.tcl

BITSTREAM=$(PROJNM)/$(PROJNM).runs/impl_1/$(PROJNM).bit

bitstream: $(BITSTREAM) 

$(BITSTREAM): $(SOURCES) $(ROMS) $(PROJECT_FILE)
	@echo Building $(BITSTREAM) from sources
	$(VIVADO) -mode batch -source bitstream.tcl -tclargs $(PROJNM)

program: $(BITSTREAM)
	@echo Programming device
	$(XSDB) -eval "connect ; fpga -file $(BITSTREAM)"

