`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////
//
// Engineer:    Thomas Skibo
//
// Create Date: Sep 23, 2011
// Modified:    Dec 20, 2020
//
// Module Name: pet2001vga
//
// Description:   Implement Pet 2001 video on a 640x480 @ 60hz VGA screen.
//
/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, 2020 Thomas Skibo.
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

module pet2001vga(output reg [3:0]  vga_r,      // VGA output
                  output reg [3:0]  vga_g,
                  output reg [3:0]  vga_b,
                  output reg        vga_hsync,
                  output reg        vga_vsync,

                  output reg [9:0]  video_addr, // Video RAM intf
                  input [7:0]       video_data,

                  output reg [10:0] charaddr,   // char rom intf
                  input [7:0]       chardata,

                  output            video_on,   // control sigs
                  input             video_blank,
                  input             video_gfx,

                  input             reset,
                  input             clk
               );

    ////////////////////////////// VGA counters //////////////////////////////
    //
    reg [9:0]   h_counter;
    reg [9:0]   v_counter;
    wire        next_line;
    wire        next_screen;
    reg [1:0]   clk_div_cnt;
    wire        clk_div;

    // Divide clk by 4 or 2.
    always @(posedge clk)
        if (reset)
            clk_div_cnt <= 2'b00;
        else
            clk_div_cnt <= clk_div_cnt + 1'b1;

`ifdef CLK100MHZ
    assign clk_div = (clk_div_cnt == 2'b11);
`elsif CLK25MHZ
    assign clk_div = 1'b1;
`else
    assign clk_div = clk_div_cnt[1];
`endif

    always @(posedge clk)
        if (reset || next_line)
            h_counter <= 10'd0;
        else if (clk_div)
            h_counter <= h_counter + 1'b1;

    assign next_line = (h_counter == 10'd799) && clk_div;


    always @(posedge clk)
        if (reset || next_screen)
            v_counter <= 10'd0;
        else if (next_line)
            v_counter <= v_counter + 1'b1;

    assign next_screen = (v_counter == 10'd524) && next_line;


    always @(posedge clk)
        if (reset)
            vga_hsync <= 1;
        else if (clk_div)
            vga_hsync <= (h_counter >= 10'd96);

    always @(posedge clk)
        if (reset)
            vga_vsync <= 1;
        else if (clk_div)
            vga_vsync <= (v_counter >= 10'd2);

    ////////// Pet 320x200 display within 800x480 VGA (pixels doubled) ////////
    //
    reg [2:0]   pixel_xbit;     // 0-7: video bit within byte
    reg [2:0]   pixel_ybit;     // 0-7: row within char
    reg         is_pet_row;     // is a row in pet video region
    reg         is_pet_col;     // is a column in pet video region

    // "window" within display
    parameter [9:0]
        PET_WINDOW_TOP =    10'd74,     // back porch + sync + 39
        PET_WINDOW_LEFT =   10'd127,    // mod 8 must be 7.
        PET_WINDOW_BOTTOM = PET_WINDOW_TOP + 10'd400,
        PET_WINDOW_RIGHT =  PET_WINDOW_LEFT + 10'd640;

    always @(posedge clk)
        if (clk_div) begin
            is_pet_row <= (v_counter >= PET_WINDOW_TOP &&
                           v_counter < PET_WINDOW_BOTTOM);
            is_pet_col <= (h_counter >= PET_WINDOW_LEFT &&
                           h_counter < PET_WINDOW_RIGHT);
        end

    always @(posedge clk)
        if (reset || next_screen)
            pixel_ybit <= 3'd0;
        else if (is_pet_row && next_line && v_counter[0] && clk_div)
            pixel_ybit <= pixel_ybit + 1'b1;

    always @(posedge clk)
        if (reset || next_line)
            pixel_xbit <= 3'd0;
        else if (h_counter[0] && clk_div)
            pixel_xbit <= pixel_xbit + 1'b1;

    // This signal is used to generate 60hz interrupts and was used on
    // original PET to avoid "snow" on the display by preventing simultaneous
    // reads and writes to video RAM.
    assign video_on = is_pet_row;

    /////////////////////// Video RAM address generator ////////////////////
    //

    // Keeps the video address of the leftmost character in current row.
    reg [9:0]   video_row_addr;
    always @(posedge clk)
    if (reset || next_screen)
        video_row_addr <= 10'd0;
    else if (is_pet_row && next_line && !v_counter[0] &&
             pixel_ybit == 3'b111 && clk_div)
        video_row_addr <= video_row_addr + 6'd40;

    // Keeps the video address of the current character.  Scans through
    // each row 8 times before video_row_addr is incremented.
    always @(posedge clk)
        if (reset || (next_line && clk_div))
            video_addr <= video_row_addr;
        else if (is_pet_row && is_pet_col && pixel_xbit == 3'd6 &&
                 h_counter[0] && clk_div)
            video_addr <= video_addr + 1'b1;

    // Generate an address into the character ROM.
    always @(posedge clk)
        charaddr <= {video_gfx, video_data[6:0], pixel_ybit[2:0]};

    // Shift register is loaded with character ROM data and spit out to screen.
    reg [7:0]   chardata_r;
    always @(posedge clk)
        if (clk_div && h_counter[0]) begin
            if (pixel_xbit == 3'd7)
                chardata_r <= chardata;
            else
                chardata_r <= {chardata_r[6:0], 1'b0};
        end

    // Is current character reverse video?
    reg char_invert;
    always @(posedge clk)
        if (clk_div && h_counter[0] && pixel_xbit == 3'd7)
            char_invert <= video_data[7];

    //////////////////////////////// Video Logic ////////////////////////////
    //
    wire pixel = (chardata_r[7] ^ char_invert) & ~video_blank;
    wire [3:0] petvideo = {4{pixel}};

    always @(posedge clk) begin
        vga_r <= (is_pet_row && is_pet_col) ? petvideo : 4'b0000;
        vga_g <= (is_pet_row && is_pet_col) ? petvideo : 4'b0000;
        vga_b <= (is_pet_row && is_pet_col) ? petvideo : 4'b0000;
    end

endmodule // pet2001vga
