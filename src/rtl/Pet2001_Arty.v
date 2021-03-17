`timescale 1ns / 1ps
//
// Pet2001_Arty.v
//
//      This is the very top module for Pet2001 in Digilent Arty FPGA
//      evaluation board.  This version converts PS/2 input into PET
//      keystrokes and outputs VGA video.  A PmodVGA adapter is needed
//      on PMOD connectors JA and JB and a PS/2 adapter is needed on
//      connector JD.
//
// Interfaces:
//      BTN -           Button 0, system reset.
//      SW[2] -         PET diagnostic switch
//      SW[1] -         PET turbo mode
//      SW[0] -         PET suspend
//      LED -           PET diagnostic LED.
//      VGA_R[3:0] -    PMOD connections to JA and JB on Arty.  The constraints
//      VGA_G[3:0] -    file assigns these signals to the proper pins so as to
//      VGA_B[3:0] -    interface to Digilent's PmodVGA PMOD board.
//      VGA_HSYNC -
//      VGA_VSYNC -
//		AUDIO -			CB2 audio connected to JC[1].
//		CASS_WR -		Cassette write output connected to JC[3].
//		CASS_RD -		Cassette read input connected to JC[4].
//      PS2_CLK -		PS/2 clock connected to JD[7].
//      PS2_DATA -		PS/2 data connected to JD[9].
//
//
// Copyright (c) 2015 Thomas Skibo.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//



module Pet2001_Arty(
            input [2:0]  SW,
            input        BTN,
            output reg   LED,

            output       AUDIO,
            output       CASS_WR,
            input        CASS_RD,

`ifdef PET_COMP
            output [1:0] COMPVID,
`else
            output [3:0] VGA_R,
            output [3:0] VGA_G,
            output [3:0] VGA_B,
            output       VGA_HSYNC,
            output       VGA_VSYNC,
`endif

            input        PS2_CLK,
            input        PS2_DATA,

            input        CLK
        );


    ////////////////////////////// Clock and Reset /////////////////////////
    //
    wire                clkout0;
    wire                clk;
    wire                clkfbout, clkfbin;
    wire                mmcm_locked;
    reg                 reset_p1;
    reg                 reset;

    MMCME2_BASE #(.CLKIN1_PERIOD(10.0),
                  .CLKFBOUT_MULT_F(10.0),
                  .CLKOUT0_DIVIDE_F(20.0))
       mmcm0(.CLKIN1(CLK),
             .CLKFBIN(clkfbin),
             .PWRDWN(1'b0),
             .RST(1'b0),
             .CLKOUT0(clkout0),
             .CLKOUT0B(),
             .CLKOUT1(),
             .CLKOUT1B(),
             .CLKOUT2(),
             .CLKOUT2B(),
             .CLKOUT3(),
             .CLKOUT3B(),
             .CLKOUT4(),
             .CLKOUT5(),
             .CLKOUT6(),
             .CLKFBOUT(clkfbout),
             .CLKFBOUTB(),
             .LOCKED(mmcm_locked)
       );

    // Output clock buffers.
    BUFG clk0_buf (.I(clkout0), .O(clk));
    BUFG clkfb_buf (.I(clkfbout), .O(clkfbin));

    // Create a synchronized reset.
    always @(posedge clk) begin
        reset_p1 <= (BTN || ~mmcm_locked);
        reset <= reset_p1;
    end

    /////////////////////////////////////////////////////////////////////

    // Synchronize inputs
    reg        cass_rd_1;
    reg        cass_rd_2;
    reg        sw0_1;
    reg        sw0_2;
    reg        sw1_1;
    reg        sw1_2;
    reg        sw2_1;
    reg        sw2_2;
    always @(posedge clk) begin
        cass_rd_1 <= CASS_RD;
        cass_rd_2 <= cass_rd_1;
        sw0_1 <= SW[0];
        sw0_2 <= sw0_1;
        sw1_1 <= SW[1];
        sw1_2 <= sw1_1;
        sw2_1 <= SW[2];
        sw2_2 <= sw2_1;
    end

    wire diag_l = ~sw2_2;
    wire clk_speed = sw1_2;
    wire clk_stop = sw0_2;
    wire [3:0] keyrow;
    wire [7:0] keyin;

    pet2001_top
        pet_top(
`ifdef PET_COMP
                .vidout(COMPVID),
`else
                .vga_r(VGA_R),
                .vga_g(VGA_G),
                .vga_b(VGA_B),
                .vga_hsync(VGA_HSYNC),
                .vga_vsync(VGA_VSYNC),
`endif

                .keyrow(keyrow),
                .keyin(keyin),

                .cass_motor_n(),
                .cass_write(CASS_WR),
                .cass_sense_n(1'b0),
                .cass_read(cass_rd_2),

                .audio(AUDIO),

                .diag_l(diag_l),

                .clk_speed(clk_speed),
                .clk_stop(clk_stop),

                .clk(clk),
                .reset(reset)
        );

    pet2001ps2_key
        petkeys(.keyrow(keyrow),
                .keyin(keyin),

                .ps2_clk(PS2_CLK),
                .ps2_data(PS2_DATA),

                .clk(clk),
                .reset(reset)
         );

    always @(posedge clk)
        LED <= (keyrow == 4'd11); // diag LED

endmodule // Pet2001_Arty
