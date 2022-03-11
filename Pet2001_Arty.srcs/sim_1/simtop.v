`timescale 1ns / 1ps
//
// simtop.v
//
//      Simulate top module for Pet2001_Arty and Pet2001Real_Arty.
//
module testPet2001_Arty;

    reg [2:0]  SW;
    reg        BTN;
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;
    wire       VGA_HSYNC;
    wire       VGA_VSYNC;
    wire       AUDIO;
    wire       CASS_WR;
    reg        CASS_RD;
    reg        PS2_CLK;
    reg        PS2_DATA;
    wire       LED;
    reg        CLK100;

    initial begin
        SW = 3'b000;
        BTN = 1'b0;
        PS2_CLK = 1'b1;
        PS2_DATA = 1'b1;
        CASS_RD = 1'b1;
        CLK100 = 1'b0;
    end

    always #5.0 CLK100 = ~CLK100; // outboard clock 100Mhz

    // DUT
    Pet2001_Arty dut(.SW(SW),
                     .BTN(BTN),
                     .LED(LED),
                     .AUDIO(AUDIO),
                     .CASS_WR(CASS_WR),
                     .CASS_RD(CASS_RD),
                     .VGA_R(VGA_R),
                     .VGA_G(VGA_G),
                     .VGA_B(VGA_B),
                     .VGA_HSYNC(VGA_HSYNC),
                     .VGA_VSYNC(VGA_VSYNC),
                     .PS2_CLK(PS2_CLK),
                     .PS2_DATA(PS2_DATA),
                     .CLK(CLK100)
                  );

endmodule // testPet2001_Arty
