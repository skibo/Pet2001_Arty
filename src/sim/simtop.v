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
`else
    wire [1:0] CVID;
    reg        UART_TXD_IN;
    wire       UART_RXD_OUT;
`endif
    wire       LED;
    reg        CLK100;

    initial begin
        SW = 3'b000;
        BTN = 1'b0;
`ifndef PET_REAL
        UART_TXD_IN = 1'b1;
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
`else
    Pet2001_Arty dut(.SW(SW),
                     .BTN(BTN),
                     .LED(LED),
                     .CVID(CVID),
                     .UART_TXD_IN(UART_TXD_IN),
                     .UART_RXD_OUT(UART_RXD_OUT),
                     .CLK(CLK100)
                  );
`endif

endmodule // testPet2001_Arty
