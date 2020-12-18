`timescale 1ns / 1ps
//
// Pet2001Real_Arty.v
//
// Copyright (c) 2015-2017 Thomas Skibo.
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
//      This is the very top module for Pet2001 in Digilent Arty FPGA
//      evaluation board.  This version is designed to interface to a
//  real Commodore PET 2001 keyboard and video interface.
//
// Interfaces:
//
//      BTN -           Button 0, system reset.
//      SW[2] -         PET diagnostic switch
//      SW[1] -         PET turbo mode
//      SW[0] -         PET suspend
//      LED -           PET diagnostic LED.
//
// PET video interface:
//
//  These signals are inverted because I run them through a TTL 7404
//  hex inverter to convert 3.3v signals to 5v signals.
//
//  PET_VID_DATA_N - PET video data inverted.
//  PET_VID_HORZ_N - PET video horizontal drive, inverted.
//  PET_VID_VERT_N - PET video vertical drive, inverted.
//
// PET keyboard interface:
//
//  KEYROW[9:0] - PET keyboard row outputs, "open drain"
//  KEYCOL[7:0] - PET keyboard column inputs with pull-downs.
//
//  XXX: due to a few mishaps when I cobbled together the Arty
//  daughter board for this, I had to use five of Arty's analog
//  inputs for the keyboard column inputs.  It turns out Arty has
//      pull-down resistors on those signals which overwhelm the weak pull-ups
//  that the FPGA can implement.  Sooo, I reversed the logic used
//  for the PET keyboard: the row outputs are high-Z when not asserted
//  and 1 when asserted.  The column inputs implement pull-downs.
//

module Pet2001Real_Arty(
            input [2:0]  SW,
            input        BTN,
            output reg   LED,

            output       PET_VID_DATA_N,
            output       PET_VID_HORZ_N,
            output       PET_VID_VERT_N,

            output [9:0] KEYROW,
            input [7:0]  KEYCOL,

            input        CLK
        );


    ////////////////////////////// Clock and Reset /////////////////////////
    //
    wire                clkin1;
    wire                clkout0;
    wire                clk;
    wire                clkfbout, clkfbin;
    wire                mmcm_locked;
    reg                 reset_p1;
    reg                 reset;

    // Input clock buffer.
    IBUFG gclk_inbuf(.I(CLK), .O(clkin1));

    MMCME2_BASE #(.CLKIN1_PERIOD(10.0),
                  .CLKFBOUT_MULT_F(8.0),
                  .CLKOUT0_DIVIDE_F(20.0)
                  // .CLKOUT1_DIVIDE(40),       // subsequent divides are decimal
          )
    mmcm0(.CLKIN1(clkin1),
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

    wire diag_l = ~SW[2];
    wire clk_speed = SW[1];
    wire clk_stop = SW[0];
    wire [3:0] keyrowsel;
    wire [7:0] keycol_n = ~KEYCOL; // See note at top on logic reversal.

    pet2001_top pet_top(.petvid_data_n(PET_VID_DATA_N),
                        .petvid_horz_n(PET_VID_HORZ_N),
                        .petvid_vert_n(PET_VID_VERT_N),

                        .keyrow(keyrowsel),
                        .keyin(keycol_n),

                        .cass_motor_n(),
                        .cass_write(),
                        .cass_sense_n(1'b1),
                        .cass_read(1'b1),

                        .audio(),

                        .diag_l(diag_l),

                        .clk_speed(clk_speed),
                        .clk_stop(clk_stop),

                        .clk(clk),
                        .reset(reset)
                );

    // Implement "open drain" output bufs: high-Z when deasserted,
    // 1 when asserted.  See note at top.
    genvar     i;
    generate
        for (i = 0; i < 10; i = i + 1) begin:keyobufs
            OBUFT kr(.I(1'b1), .T(keyrowsel != i), .O(KEYROW[i]));
        end
    endgenerate

    always @(posedge clk)
        LED <= (keyrowsel == 4'd11); // diag LED

endmodule // Pet2001Real_Arty
