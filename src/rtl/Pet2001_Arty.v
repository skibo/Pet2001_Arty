`timescale 1ns / 1ps
//
// Pet2001_Arty.v
//
//      This is the very top module for Pet2001 in Digilent Arty FPGA
//      evaluation board.  This version converts UART inputs into PET
//      keystrokes and outputs composite video.  An adapter plugged into PMOD
//      connector JA is needed to produce the composite video signal.
//
// Interfaces:
//      BTN -           Button 0, system reset.
//      SW[2] -         PET diagnostic switch
//      SW[1] -         PET turbo mode
//      SW[0] -         PET suspend
//      LED -           PET diagnostic LED.
//      CVID[1:0] -     PMOD connections JA[9:10], composite video out.
//                      Connect JA9 through 330 ohm resistor to RCA jack
//                      tip and JA10 through 100 ohm resistor to tip and
//                      ground the ring.
//      UART_TXD_IN -   UART signal FROM USB/UART chip.  Characters received
//                      are turned into PET keystrokes.  9600 baud.
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
            
            output [1:0] CVID,
            
            input        UART_TXD_IN,
            output       UART_RXD_OUT,
            
            input        CLK
        );


`include "roms/pet2001_rom1.v"

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
                  .CLKFBOUT_MULT_F(10.0),
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
    wire [3:0] keyrow;
    wire [7:0] keyin;

    pet2001_top pet_top(.vidout(CVID),

                        .keyrow(keyrow),
                        .keyin(keyin),
        
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

    assign UART_RXD_OUT = UART_TXD_IN; // echo back serial data

    wire [7:0] uart_data;
    wire       uart_strobe;

    uart #(.CLK_DIVIDER(5208)) uart0(.serial_out(),
                                     .serial_in(UART_TXD_IN),

                                     .write_rdy(), // unused xmit interface
                                     .write_data(8'h00),
                                     .write_strobe(1'b0),

                                     .read_data(uart_data),
                                     .read_strobe(uart_strobe),

                                     .clk(clk),
                                     .reset(reset)
                                );

    pet2001uart_keys petkeys(.keyrow(keyrow),
                             .keyin(keyin),
                             
                             .uart_data(uart_data),
                             .uart_strobe(uart_strobe),

                             .clk(clk),
                             .reset(reset)
                        );

    always @(posedge clk)
        LED <= (keyrow == 4'd11); // diag LED
    
endmodule // Pet2001_Arty
