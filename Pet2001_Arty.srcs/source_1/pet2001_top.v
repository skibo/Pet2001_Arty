`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
//
// pet2001_top.v
//
//  Engineer:   Thomas Skibo
//  Created:    Sep 23, 2011
//  Module:     pet2001_top
//
//  Description:
//      Encapsulate 6502 CPU and Pet hardware in a somewhat target
//      independent module.  Goal should be to put this module as-is
//      in other FPGA eval boards?
//
///////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, Thomas Skibo.  All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
// * The names of contributors may not be used to endorse or promote products
//   derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL Thomas Skibo OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//
//////////////////////////////////////////////////////////////////////////////

module pet2001_top(
                   output [3:0] vga_r,
                   output [3:0] vga_g,
                   output [3:0] vga_b,
                   output       vga_hsync,
                   output       vga_vsync,

                   output [3:0] keyrow,
                   input [7:0]  keyin,

                   output       cass_motor_n,
                   output       cass_write,
                   output       audio,
                   input        cass_sense_n,
                   input        cass_read,

                   input        diag_l,
                   input        clk_speed,
                   input        clk_stop,

                   input        clk,
                   input        reset
           );

   ///////////////////////////////////////////////////
   // CPU
   ///////////////////////////////////////////////////

    wire [15:0]         A;
    wire [7:0]          DO;
    wire [7:0]          DI;
    wire                RW;
    wire                RDY;
    wire                SYNC;

    wire                nmi;
    wire                NMI_ = !nmi;
    wire                irq;
    wire                IRQ_ = !irq;
    wire                RES_ = !reset;

    cpu6502 cpu(.A(A),
                .RW(RW),
                .DO(DO),
                .DI(DI),
                .RDY(RDY),
                .SYNC(SYNC),
                .IRQ_(IRQ_),
                .NMI_(NMI_),
                .PHI(clk),
                .RES_(RES_)
        );

    ///////////////////////////////////////////////////
    // Commodore Pet hardware
    ///////////////////////////////////////////////////
    pet2001hw hw(.addr(A),
                 .data_out(DI),
                 .data_in(DO),
                 .we(!RW),
                 .rdy(RDY),
                 .nmi(nmi),
                 .irq(irq),

                 .vga_r(vga_r),
                 .vga_g(vga_g),
                 .vga_b(vga_b),
                 .vga_hsync(vga_hsync),
                 .vga_vsync(vga_vsync),

                 .keyin(keyin),
                 .keyrow(keyrow),

                 .cass_motor_n(cass_motor_n),
                 .cass_write(cass_write),
                 .audio(audio),
                 .cass_sense_n(cass_sense_n),
                 .cass_read(cass_read),

                 .diag_l(diag_l),

                 .clk_speed(clk_speed),
                 .clk_stop(clk_stop),

                 .clk(clk),
                 .reset(reset)
         );

endmodule // pet2001_top
