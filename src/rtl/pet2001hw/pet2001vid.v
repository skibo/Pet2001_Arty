`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////
//
// Engineer:	Thomas Skibo
// 
// Create Date: Sep 23, 2011
//
// Module Name: pet2001vid
//
// Description:   Implement Pet 2001 video logic.
//
/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, 2015 Thomas Skibo.  All rights reserved.
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

module pet2001vid(output reg 	    vid_n,	// Pet video interface
		  output reg        vert_n,
                  output reg        horz_n,
                    
		  output reg [10:0] video_addr, // Video RAM intf
		  input [7:0]       video_data,

                  output reg [10:0] charaddr, // char rom intf
                  input [7:0]       chardata,

                  output            video_on, // control sigs
                  input             video_blank,
                  input             video_gfx,

		  input             reset,
		  input             clk		// 80Mhz input clock
               );
   
    ////////////////////////////// video counters //////////////////////////
    //
    reg [8:0]	h_counter;
    reg [8:0] 	v_counter;
    wire 	next_line;
    wire 	next_screen;
    reg [2:0] 	clk_div_cnt;
    reg 	clk_div;
   
    // Create pixel clock by dividing 40Mhz clock by 5
    always @(posedge clk)
	if (reset || clk_div)
            clk_div_cnt <= 3'd0;
	else
            clk_div_cnt <= clk_div_cnt + 1'b1;

    // 8Mhz pulse used as pixel clock everywhere.
    always @(posedge clk)
        clk_div <= (clk_div_cnt == 3'd3);

    // 64us horizontal lines
    always @(posedge clk)
	if (reset)
            h_counter <= 9'd0;
	else if (clk_div)
            h_counter <= h_counter + 1'b1;
         
    assign next_line = (h_counter == 9'd511) && clk_div;

    // count lines   
    always @(posedge clk)
	if (reset || next_screen)
            v_counter <= 9'd0;
	else if (next_line)
            v_counter <= v_counter + 1'b1;

    assign next_screen = (v_counter == 9'd259) && next_line;
   
    // Generate horz and vert sync pulses
    always @(posedge clk)
	if (reset || next_line)
            horz_n <= 1'b0;
	else if (clk_div && h_counter == 9'd190)
            horz_n <= 1'b1;
    
    always @(posedge clk)
	if (reset || next_screen)
            vert_n <= 1'b1;
	else if (clk_div && v_counter == 9'd20)
            vert_n <= 1'b0;

    ////////// Pet 320x200 display
    //
    reg [2:0] 	pixel_xbit;		// 0-7: video bit within byte
    reg [2:0] 	pixel_ybit;		// 0-7: row within char
    reg 	is_pet_row;		// is a row in pet video region
    reg 	is_pet_col;           	// is a column in pet video region

    // "window" within display
    parameter [9:0]
	PET_WINDOW_TOP =	9'd40,
      	PET_WINDOW_LEFT =	9'd143,
      	PET_WINDOW_BOTTOM =	PET_WINDOW_TOP + 9'd200,
	PET_WINDOW_RIGHT =	PET_WINDOW_LEFT + 9'd320;

    always @(posedge clk)
        if (reset || (clk_div && v_counter == PET_WINDOW_BOTTOM))
            is_pet_row <= 1'b0;
        else if (clk_div && v_counter == PET_WINDOW_TOP)
            is_pet_row <= 1'b1;

    always @(posedge clk)
        if (reset || (clk_div && h_counter == PET_WINDOW_RIGHT))
            is_pet_col <= 1'b0;
        else if (clk_div && is_pet_row && h_counter == PET_WINDOW_LEFT)
            is_pet_col <= 1'b1;

    always @(posedge clk)
	if (reset || next_screen)
            pixel_ybit <= 3'd0;
	else if (is_pet_row && next_line)
            pixel_ybit <= pixel_ybit + 1'b1;

    always @(posedge clk)
	if (reset || next_line)
            pixel_xbit <= 3'd0;
	else if (clk_div)
            pixel_xbit <= pixel_xbit + 1'b1;

    // This signal is used to generate 60hz interrupts and was used on
    // original PET to avoid "snow" on the display by preventing simultaneous
    // reads and writes to video RAM.
    assign video_on = is_pet_row;

    /////////////////////// Video RAM address generator ////////////////////
    
    // Keeps the video address of the leftmost character in current row.
    reg [9:0]	video_row_addr;
    always @(posedge clk)
	if (reset || next_screen)
            video_row_addr <= 10'd0;
	else if (is_pet_row && next_line && pixel_ybit == 3'd6)
            video_row_addr <= video_row_addr + 6'd40;

    // Keeps the video address of the current character.  Scans through
    // each row 8 times before video_row_addr is incremented.
    always @(posedge clk)
	if (next_line)
            video_addr <= { 1'b0, video_row_addr };
	else if (is_pet_col && pixel_xbit == 3'd6 && clk_div)
            video_addr <= video_addr + 1'b1;

    // Generate an address into the character ROM.
    always @(posedge clk)
	charaddr <= { video_gfx, video_data[6:0], pixel_ybit[2:0] };

    // Shift register is loaded with character ROM data and spit out to screen.
    reg [7:0] 	chardata_r;
    always @(posedge clk)
	if (clk_div) begin
            if (pixel_xbit == 3'd7)
		chardata_r <= chardata;
            else
		chardata_r <= { chardata_r[6:0], 1'b0 };
	end
    
    // Is current character reverse video?
    reg	char_invert;
    always @(posedge clk)
	if (clk_div && pixel_xbit == 3'd7)
            char_invert <= video_data[7];

    //////////////////////////////// Video Logic ////////////////////////////
    //
    wire pixel = (chardata_r[7] ^ char_invert) & ~video_blank & is_pet_col;
   
    always @(posedge clk)
        vid_n <= pixel;

endmodule // pet2001vid


