`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Engineer:    Thomas Skibo
//
// Create Date: Sep 23, 2011
// Modified:    Dec 18, 2020
//
// Module Name: pet2001vidram
//
// Description:
//
//      1K of commodore PET video RAM.  This is implemented as an 8x1K dual-
//      port RAM.  This resides in the 0x8000-0x83FF address region.  The
//      second memory port is used by the video interface.  Unlike early PETs,
//      you won't get "snow" on the display if you write this at the same time
//      as the video hardware is reading it.  Although, that would be fun to
//      emulate.
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011-2023, Thomas Skibo.  All rights reserved.
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

module pet2001vidram(output reg [7:0]   data_out,   // cpu interface
                     input [7:0]        data_in,
                     input [9:0]        cpu_addr,
                     input              we,

                     output reg [7:0]   video_data, // video hardware intf
                     input [9:0]        video_addr,

                     input              clk
             );

    (* ram_style = "block" *)
    reg [7 : 0] ram[1023 : 0];

    always @(posedge clk)
        if (we)
            ram[cpu_addr] <= data_in;

    always @(posedge clk)
        data_out <= ram[cpu_addr];

    always @(posedge clk)
        video_data <= ram[video_addr];

endmodule // pet2001vidram
