`timescale 1ns / 1ps
//
// Copyright (c) 2024 Thomas Skibo.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//

module test_pet2001vid;

    wire	vid_n;
    wire        vert_n;
    wire        horz_n;
    wire [9:0]  video_addr;
    reg [7:0]   video_data;
    wire [10:0] charaddr;
    wire [7:0]  chardata;
    wire        video_on;
    reg         video_blank;
    reg         video_gfx;
    reg         reset;
    reg         clk;


    initial begin
        video_data = 'd0;
        video_blank = 0;
        video_gfx = 0;
        reset = 1;
        clk = 0;
    end

    always #12.5 clk = ~clk;	// 40 Mhz clock

    initial begin
        repeat (5) @(posedge clk);
        reset <= 0;
    end

    pet2001vid
        pet2001vid_0(
                     .vid_n(vid_n),
                     .vert_n(vert_n),
                     .horz_n(horz_n),
                     .video_addr(video_addr),
                     .video_data(video_data),
                     .charaddr(charaddr),
                     .chardata(chardata),
                     .video_on(video_on),
                     .video_blank(video_blank),
                     .video_gfx(video_gfx),
                     .reset(reset),
                     .clk(clk)
             );

    pet2001roms
        pet2001roms_0(
                      .data(),
                      .addr(14'h0000),
                      .chardata(chardata),
                      .charaddr(charaddr),
                      .clk(clk)
             );

endmodule // test_pet2001vid
