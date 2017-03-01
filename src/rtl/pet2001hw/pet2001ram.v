`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Engineer:    Thomas Skibo
// 
// Create Date: Sep 23, 2011
// Modified:    Mar 1, 2017
// Design Name: 
// Module Name: pet2001ram
//
// Description:
//
//      16K RAM for PET.
//
//      These RAMs are clocked by the negative edge of clk.  The Xilinx tools
//      should not generate an inverter on the clock line here but instead
//      change an attribute in the BRAM which controls which edge triggers it.
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, 2013, 2017 Thomas Skibo.  All rights reserved.
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

module pet2001ram(
                  output reg [7 : 0] data_out, // cpu interface
                  input [7 : 0]      data_in,
                  input [13 : 0]     addr,
                  input              we,

                  input              clk
          );

    reg [7 : 0] ram[16383 : 0];

    always @(negedge clk)
        if (we)
            ram[addr] <= data_in;

    always @(negedge clk)
        data_out <= ram[addr];

endmodule // pet2001ram

