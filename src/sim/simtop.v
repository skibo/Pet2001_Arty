`timescale 1ns / 1ps
//
// simtop.v
//
//      Simulate top module for Pet2001_Arty and Pet2001Real_Arty.
//
module testPet2001_Arty;

    reg [2:0]  SW;
    reg        BTN;
`ifdef PET_REAL
    wire       PET_VID_DATA_N;
    wire       PET_VID_HORZ_N;
    wire       PET_VID_VERT_N;
    wire [9:0] KEYROW;
    wire [7:0] KEYCOL;
    pulldown pulls[7:0](KEYCOL); // Implemented in constraints.
`else // !PET_REAL
 `ifdef PET_COMP
    wire [1:0] COMPVID;
 `else
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;
    wire       VGA_HSYNC;
    wire       VGA_VSYNC;
    wire       AUDIO;
    wire       CASS_WR;
    reg        CASS_RD;
 `endif // !PET_COMP
 `ifdef PET_UART
    reg        UART_TXD_IN;
    wire       UART_RXD_OUT;
 `else
    reg		   PS2_CLK;
    reg        PS2_DATA;
 `endif // !PET_UART
`endif // !PET_REAL
    wire       LED;
    reg        CLK100;

    initial begin
        SW = 3'b000;
        BTN = 1'b0;
`ifndef PET_REAL
 `ifdef PET_UART
        UART_TXD_IN = 1'b1;
 `else
        PS2_CLK = 1'b1;
        PS2_DATA = 1'b1;
 `endif
        CASS_RD = 1'b1;
`endif
        CLK100 = 1'b0;
    end

    always #5.0 CLK100 = ~CLK100; // outboard clock 100Mhz

    // DUT
`ifdef PET_REAL
    Pet2001Real_Arty dut(.SW(SW),
                         .BTN(BTN),
                         .LED(LED),
                         .PET_VID_DATA_N(PET_VID_DATA_N),
                         .PET_VID_HORZ_N(PET_VID_HORZ_N),
                         .PET_VID_VERT_N(PET_VID_VERT_N),
                         .KEYROW(KEYROW),
                         .KEYCOL(KEYCOL),
                         .CLK(CLK100)
                  );
`else // !PET_REAL
    Pet2001_Arty dut(.SW(SW),
                     .BTN(BTN),
                     .LED(LED),
                     .AUDIO(AUDIO),
                     .CASS_WR(CASS_WR),
                     .CASS_RD(CASS_RD),
 `ifdef PET_COMP
                     .COMPVID(COMPVID),
 `else
                     .VGA_R(VGA_R),
                     .VGA_G(VGA_G),
                     .VGA_B(VGA_B),
                     .VGA_HSYNC(VGA_HSYNC),
                     .VGA_VSYNC(VGA_VSYNC),
 `endif // !PET_COMP
 `ifdef PET_UART
                     .UART_TXD_IN(UART_TXD_IN),
                     .UART_RXD_OUT(UART_RXD_OUT),
 `else
                     .PS2_CLK(PS2_CLK),
                     .PS2_DATA(PS2_DATA),
 `endif // !PET_UART
                     .CLK(CLK100)
                  );
`endif // !PET_REAL

endmodule // testPet2001_Arty
