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
`ifdef PET_REAL
                   output       petvid_data_n,
                   output       petvid_horz_n,
                   output       petvid_vert_n,
`else
                   output [1:0] vidout,
`endif
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

    wire [15:0]         addr;
    wire [7:0]          cpu_data_out;
    wire [7:0]          cpu_data_in;
    wire                we;

    wire                rdy;
    wire                nmi;
    wire                irq;

    cpu6502 cpu(.addr(addr),
                .data_out(cpu_data_out),
                .we(we),
                .data_in(cpu_data_in),
                .rdy(rdy),
                .nmi(nmi),
                .irq(irq),
                .clk(clk),
                .reset(reset)
        );

    ///////////////////////////////////////////////////
    // Commodore Pet hardware
    ///////////////////////////////////////////////////
    pet2001hw hw(.addr(addr),
                 .data_out(cpu_data_in),
                 .data_in(cpu_data_out),
                 .we(we),
                 .rdy(rdy),
                 .nmi(nmi),
                 .irq(irq),
`ifdef PET_REAL
                 .petvid_data_n(petvid_data_n),
                 .petvid_horz_n(petvid_horz_n),
                 .petvid_vert_n(petvid_vert_n),
`else
                 .vidout(vidout),
`endif
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
