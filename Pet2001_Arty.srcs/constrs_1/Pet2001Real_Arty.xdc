## Pet2001_Arty.xdc
##

# Clock signal

set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {CLK}];


#Switches

set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { SW[0] }]; #IO_L12N_T1_MRCC_16 Sch=sw[0]
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { SW[1] }]; #IO_L13P_T2_MRCC_16 Sch=sw[1]
set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { SW[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
##set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { SW[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]


# LEDs

set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { LED }]; #IO_L24N_T3_35 Sch=led[4]

#Buttons

set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { BTN }]; #IO_L6N_T0_VREF_16 Sch=btn[0]


##ChipKit Signals

##ChipKit Single Ended Analog Inputs

##ChipKit Digital I/O Low

set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { PET_VID_DATA_N }]; #IO_L16P_T2_CSI_B_14 Sch=ck_io[0]
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { PET_VID_HORZ_N }]; #IO_L18P_T2_A12_D28_14 Sch=ck_io[1]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { PET_VID_VERT_N }]; #IO_L8N_T1_D12_14 Sch=ck_io[2]

set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[9] }]; #IO_L19P_T3_A10_D26_14 Sch=ck_io[3]
set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[8] }]; #IO_L5P_T0_D06_14 Sch=ck_io[4]
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[7] }]; #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[6] }]; #IO_L14N_T2_SRCC_14 Sch=ck_io[6]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[5] }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]

set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[4] }]; #IO_L19N_T3_A09_D25_VREF_14 Sch=ck_io[26]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[3] }]; #IO_L16N_T2_A15_D31_14 Sch=ck_io[27]
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[2] }]; #IO_L6N_T0_D08_VREF_14 Sch=ck_io[28]
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[1] }]; #IO_25_14 Sch=ck_io[29]
set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { KEYROW[0] }]; #IO_0_14 Sch=ck_io[30]

set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { KEYCOL[7] }]; #IO_L5N_T0_D07_14 Sch=ck_io[31]
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { KEYCOL[6] }]; #IO_L13N_T2_MRCC_14 Sch=ck_io[32]
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { KEYCOL[5] }]; #IO_L13P_T2_MRCC_14 Sch=ck_io[33]

# These I/O's have pull-downs on Arty:
set_property -dict { PACKAGE_PIN F5    IOSTANDARD LVCMOS33 } [get_ports { KEYCOL[4] }]; #IO_0_35 Sch=ck_a[0]
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { KEYCOL[3] }]; #IO_L4P_T0_35 Sch=ck_a[1]
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { KEYCOL[2] }]; #IO_L4N_T0_35 Sch=ck_a[2]
set_property -dict { PACKAGE_PIN E7    IOSTANDARD LVCMOS33 } [get_ports { KEYCOL[1] }]; #IO_L6P_T0_35 Sch=ck_a[3]
set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { KEYCOL[0] }]; #IO_L6N_T0_VREF_35 Sch=ck_a[4]
