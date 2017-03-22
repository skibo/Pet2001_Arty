#
# make_real.tcl
#
# Modify exsting project, Pet2001_Arty, so that it talks to real PET hardware.
#

set orig_dir "[file normalize "[get_property directory [current_project]]/.."]"

set files [list \
               "[file normalize "$orig_dir/src/rtl/Pet2001_Arty.v"]" \
               "[file normalize "$orig_dir/src/rtl/pet2001hw/pet2001ntsc.v"]" \
               "[file normalize "$orig_dir/src/rtl/pet2001hw/pet2001uart_keys.v"]" \
               "[file normalize "$orig_dir/src/rtl/misc/uart.v"]" \
               "[file normalize "$orig_dir/src/constrs/Pet2001_Arty.xdc"]" ]
remove_files $files

set files [list \
               "[file normalize "$orig_dir/src/rtl/Pet2001Real_Arty.v"]" \
               "[file normalize "$orig_dir/src/rtl/pet2001hw/pet2001vid.v"]"]
add_files -norecurse -fileset [get_filesets sources_1] $files

set files [list \
               "[file normalize "$orig_dir/src/constrs/Pet2001Real_Arty.xdc"]"]
add_files -norecurse -fileset [get_filesets constrs_1] $files

set_property verilog_define PET_REAL=y [get_filesets sources_1]
set_property verilog_define PET_REAL=y [get_filesets sim_1]
