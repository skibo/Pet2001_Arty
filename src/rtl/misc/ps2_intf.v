`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
//
// Engineer:         Thomas Skibo 
// 
// Create Date:      18:53:38 08/21/2007 
//
// Module Name:      ps2_intf
//
// Description:      Implement PS/2 interface.  Generates a one-clock write
//                   strobe (ps2_wr) for each byte coming over PS2 interface.
//
///////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2007, Thomas Skibo.  All rights reserved.
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

module ps2_intf(output [7:0]	ps2_code,
                output reg     	ps2_wr,

                input          	ps2_clk,
                input          	ps2_data,

                input          	reset,
                input          	clk
	);
   
    reg [8:0]	data9;
    assign	ps2_code = data9[7:0];   // sans parity

    reg [7:0] 	ps2_clk_r;
    reg 	ps2_clk_filtered;
    reg 	ps2_clk_filtered_1;
    reg 	ps2_data_2;
    reg 	ps2_data_1;
    reg [3:0] 	bit_ctr;
    reg [14:0] 	ps2_timeout_ctr;

    wire 	parity_ok = ((^data9) == 1'b1);
    wire 	ps2_timeout;

    ///////////////////////////////////////////////////////////////////////
    // input registers/synchronizers
    ///////////////////////////////////////////////////////////////////////
    always @(posedge clk)
	if (reset) begin
            ps2_clk_r <= 8'hff;
            ps2_data_2 <= 1'b1;
            ps2_data_1 <= 1'b1;
	end
	else begin
            ps2_clk_r <= { ps2_clk_r[6:0], ps2_clk };
            ps2_data_2 <= ps2_data_1;
            ps2_data_1 <= ps2_data;
	end

    // implement some hysteresis
    always @(posedge clk)
	if (reset || ps2_clk_r[7:2] == 6'h3f)
            ps2_clk_filtered <= 1'b1;
	else if (ps2_clk_r[7:2] == 6'h00)
            ps2_clk_filtered <= 1'b0;

    always @(posedge clk)
	if (reset)
            ps2_clk_filtered_1 <= 1'b1;
	else
            ps2_clk_filtered_1 <= ps2_clk_filtered;

    // negative transition
    wire ps2_clk_transition = (!ps2_clk_filtered && ps2_clk_filtered_1);
   
    //////////////////////////////// PS2 input logic //////////////////////
   
    // count bits
    always @(posedge clk)
	if (reset || ps2_timeout || (ps2_clk_filtered && bit_ctr == 4'd11))
            bit_ctr <= 4'd0;
	else if (ps2_clk_transition)
            bit_ctr <= bit_ctr + 1'b1;
    
    // shift register with data
    always @(posedge clk)
	if (reset)
            data9 <= 9'd0;
	else if (ps2_clk_transition && bit_ctr < 4'd10)
            data9 <= {ps2_data_2, data9[8:1]};

    // create a one clock write pulse when we're happy with data
    always @(posedge clk)
	if (reset)
            ps2_wr <= 0;
	else
            ps2_wr <= (bit_ctr == 4'd10 && ps2_clk_transition && parity_ok);
    
    // a timeout that will reset the counter if the ps2_clk is high
    // for more than 320 usecs.
    //
    always @(posedge clk)
	if (reset || ! ps2_clk_filtered)
            ps2_timeout_ctr <= 15'd0;
	else if (bit_ctr != 4'd0)
            ps2_timeout_ctr <= ps2_timeout_ctr + 1'b1;
    
    assign ps2_timeout = (ps2_timeout_ctr == 15'h7fff);
    
endmodule // ps2_intf

