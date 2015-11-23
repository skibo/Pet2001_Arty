`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:	Thomas Skibo 
// 
// Create Date: 16:25:10 09/19/2007 
// Design Name: 
// Module Name: uart 
//
//    Implements a simple no parity, 8-bit serial interface.
//
//////////////////////////////////////////////////////////////////////////////
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

module uart(output		serial_out,
	    input		serial_in,

	    output		write_rdy,
	    input [7:0]		write_data,
	    input		write_strobe,

	    output reg [7:0]  	read_data,
	    output reg        	read_strobe,

	    input             	reset,
	    input             	clk
    );
   
    parameter [15:0]
	CLK_DIVIDER = 5208; // 19,200 baud @ 100 Mhz or 9600 @ 50 Mhz
   
    ///////////// output //////////////////////////
    //
    reg [8:0]	out_data;
    reg [3:0] 	out_bit_cntr;
    reg [15:0] 	out_clk_div;
    reg         out_clk_div_zero;
   
    always @(posedge clk)
	if (reset)
            out_data <= 9'h1ff;
	else if (write_strobe)
            out_data <= { write_data, 1'b0 };
         else if (out_clk_div_zero)
	     out_data <= { 1'b1, out_data[8:1] };

    // out_clk_div is a clock divider.  It generates a pulse
    // every bit time and advances the shift register.
    //
    always @(posedge clk)
	if (reset || write_strobe || out_clk_div_zero) begin
            out_clk_div <= CLK_DIVIDER-1;
            out_clk_div_zero <= 0;
	end
	else begin
            out_clk_div <= out_clk_div - 1;
            out_clk_div_zero <= (out_clk_div == 16'd1);
	end

    // out_bit_cntr counts the 10 bits out and controls the write_rdy
    // signal.
    //
    always @(posedge clk)
	if (reset)
            out_bit_cntr <= 4'd10;
	else if (write_strobe)
            out_bit_cntr <= 4'd0;
	else if (out_clk_div_zero && out_bit_cntr != 4'd10)
	    out_bit_cntr <= out_bit_cntr + 1;

    assign write_rdy = (out_bit_cntr == 4'd10);
    assign serial_out = out_data[0];
   
    //////////////// Input ////////////////////////////
    //
    reg         serial_in_1;
    reg         serial_in_synced;
    reg [3:0] 	in_bit_cntr;
    reg [15:0] 	in_clk_div;
    reg [15:0] 	in_ones_cntr;
    reg         in_ones_avg;
    reg         in_clk_tick;
    
    wire        in_start;
    wire        in_err;

    // synchronize serial_in.
    //
    always @(posedge clk)
	if (reset) begin
            serial_in_synced <= 1;
            serial_in_1 <= 1;
	end
	else begin
            serial_in_synced <= serial_in_1;
            serial_in_1 <= serial_in;
	end

    always @(posedge clk)
	if (reset || in_err)
            in_bit_cntr <= 4'd9;
	else if (in_start)
            in_bit_cntr <= 4'd0;
	else if (in_bit_cntr != 4'd9 && in_clk_tick)
	    in_bit_cntr <= in_bit_cntr+1;
    
    assign in_start = (in_bit_cntr == 4'd9 && !serial_in_synced);
    assign in_err = (in_clk_tick && in_bit_cntr == 4'd0 && in_ones_avg);
   
    always @(posedge clk)
	if (reset || in_clk_tick || in_start) begin
            in_clk_div <= CLK_DIVIDER-1;
            in_clk_tick <= 0;
	end
	else begin
            in_clk_div <= in_clk_div - 1;
            in_clk_tick <= (in_clk_div == 16'd1);
	end
   
    always @(posedge clk)
	if (reset || in_clk_tick || in_start)
            in_ones_cntr <= 16'd0;
	else if (serial_in_synced)
            in_ones_cntr <= in_ones_cntr + 1;
   
    always @(posedge clk)
	in_ones_avg <= (in_ones_cntr > (CLK_DIVIDER/2));

    always @(posedge clk)
	if (in_clk_tick && in_bit_cntr != 4'd0 && in_bit_cntr != 4'd9)
            read_data <= { in_ones_avg, read_data[7:1] };
   
    always @(posedge clk)
	if (reset)
            read_strobe <= 0;
	else
            read_strobe <= (in_bit_cntr == 4'd8 && in_clk_tick);
    
endmodule // uart
