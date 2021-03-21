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
    reg         clk_div;

    // VGA 640x480 @ 60Hz
    parameter [9:0]
        H_ACTIVE =      10'd640,
        H_FRONT_PORCH = 10'd16,
        H_SYNC =        10'd96,
        H_BACK_PORCH =  10'd48,
        H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH,
        V_ACTIVE =      10'd480,
        V_FRONT_PORCH = 10'd10,
        V_SYNC =        10'd2,
        V_BACK_PORCH =  10'd33,
        V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    // Divide clk by 2 to get 25Mhz pixel "clock"
    always @(posedge clk)
        if (reset)
            clk_div <= 1'b0;
        else
            clk_div <= ~clk_div;

    always @(posedge clk)
        if (reset || next_line)
            h_counter <= 10'd0;
        else if (clk_div)
            h_counter <= h_counter + 1'b1;

    assign next_line = (h_counter == H_TOTAL - 1'b1) && clk_div;


    always @(posedge clk)
        if (reset || next_screen)
            v_counter <= 10'd0;
        else if (next_line)
            v_counter <= v_counter + 1'b1;

    assign next_screen = (v_counter == V_TOTAL - 1'b1) && next_line;

    // Generate vsync and hsync signals.  hsync is delayed one clock so it
    // lines up correctly with the video data which is also registered.
    reg         vga_hsync_p;
    always @(posedge clk)
        if (reset)
            vga_hsync_p <= 1;
        else if (clk_div)
            vga_hsync_p <= !(h_counter < H_SYNC);

    always @(posedge clk)
        vga_hsync <= vga_hsync_p;

    always @(posedge clk)
        if (reset)
            vga_vsync <= 1;
        else if (clk_div)
            vga_vsync <= !(v_counter < V_SYNC);

    ////////// Pet 320x200 display in 640x480 VGA (pixels doubled) ////////
    //
    reg [2:0]   pixel_xbit;     // 0-7: video bit within byte
    reg [2:0]   pixel_ybit;     // 0-7: row within char
    reg         is_pet_row;     // is a row in pet video region
    reg         is_pet_col;     // is a column in pet video region
    wire        pet_active = is_pet_row && is_pet_col;

    // "window" within display
    parameter [9:0]
        PET_WINDOW_TOP =    V_SYNC + V_BACK_PORCH + 10'd40,
        PET_WINDOW_LEFT =   H_SYNC + H_BACK_PORCH,
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
        else if (is_pet_row && next_line && !v_counter[0] && clk_div)
            pixel_ybit <= pixel_ybit + 1'b1;

    always @(posedge clk)
        if (reset || next_line)
            pixel_xbit <= 3'd7;
        else if (!h_counter[0] && clk_div)
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
    else if (is_pet_row && next_line && v_counter[0] &&
             pixel_ybit == 3'b111 && clk_div)
        video_row_addr <= video_row_addr + 6'd40;

    // Keeps the video address of the current character.  Scans through
    // each row 8 times before video_row_addr is incremented.
    always @(posedge clk)
        if (reset || (next_line && clk_div))
            video_addr <= video_row_addr;
        else if (pet_active && pixel_xbit == 3'd6 && !h_counter[0] && clk_div)
            video_addr <= video_addr + 1'b1;

    // Generate an address into the character ROM.
    always @(posedge clk)
        charaddr <= {video_gfx, video_data[6:0], pixel_ybit[2:0]};

    // Shift register is loaded with character ROM data and spit out to screen.
    reg [7:0]   chardata_r;
    always @(posedge clk)
        if (clk_div && !h_counter[0]) begin
            if (pixel_xbit == 3'd7)
                chardata_r <= chardata;
            else
                chardata_r <= {chardata_r[6:0], 1'b0};
        end

    // Is current character reverse video?
    reg char_invert;
    always @(posedge clk)
        if (clk_div && !h_counter[0] && pixel_xbit == 3'd7)
            char_invert <= video_data[7];

    //////////////////////////////// Video Logic ////////////////////////////
    //
    wire pixel = (chardata_r[7] ^ char_invert) & ~video_blank;
    wire [3:0] petvideo = {4{pixel}};

    always @(posedge clk) begin
        vga_r <= pet_active ? petvideo : 4'b0000;
        vga_g <= pet_active ? petvideo : 4'b0000;
        vga_b <= pet_active ? petvideo : 4'b0000;
    end

endmodule // pet2001vga
