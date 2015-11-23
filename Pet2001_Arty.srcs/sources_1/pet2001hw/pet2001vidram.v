`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Engineer:	Thomas Skibo
// 
// Create Date: Sep 23, 2011
// Modified:    Jan 24, 2013
//
// Module Name: pet2001vidram
//
// Description:
//
//	2K of commodore PET video RAM built using a Artix-7 18 kbit two-port
//	RAM.  This resides in the 0x8000-0x87FF address region.  The second
//	memory port is used by the video interface.  Unlike early PETs, you
//	won't get "snow" on the display if you write this at the same time as
//	the video hardware is reading it.  Although, that would be fun.
//
//   	These RAMs are clocked by the negative edge of clk.  The Xilinx tools
// 	should not generate an inverter on the clock line here but instead
//  	change an attribute in the BRAM which controls which edge triggers it.
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
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

module pet2001vidram(output [7:0]	data_out,	// cpu interface
		     input [7:0]    	data_in,
		     input [10:0]   	cpu_addr,
		     input          	we,

                     output [7:0]	video_data,	// video hardware intf
                     input [10:0]	video_addr,

		     input          	clk
	     );

    // A single Artix-7 8x2k 2-port RAM.  Easy.
    BRAM_TDP_MACRO
	#(.BRAM_SIZE("18Kb"),
	  .WRITE_WIDTH_A(8),
	  .READ_WIDTH_A(8),
	  .WRITE_WIDTH_B(8),
	  .READ_WIDTH_B(8)
	  ) ram (.DIA(data_in),
		 .DOA(data_out),
		 .ADDRA(cpu_addr),
		 .WEA(we),
		 .ENA(1'b1),
		 .REGCEA(1'b0),
		 .RSTA(1'b0),
		 .CLKA(~clk),		// see description

		 .DIB(8'h00),
		 .DOB(video_data),
		 .ADDRB(video_addr),
		 .WEB(1'b0),
		 .ENB(1'b1),
		 .REGCEB(1'b0),
		 .RSTB(1'b0),
		 .CLKB(~clk)		// see description
	);
         
endmodule // pet2001vidram

