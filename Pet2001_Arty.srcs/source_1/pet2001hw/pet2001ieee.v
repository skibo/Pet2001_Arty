`timescale 1ns / 1ps
//
// Copyright (c) 2023 Thomas Skibo.
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

// Keep in mind the ieee signals are all active low and _o signals are coming
// from PET hardware and so are inputs.

(* keep_hiearchy = "YES" *)
module pet2001ieee
    (
                 input [7:0]      ieee_do, // IEEE interface
                 output reg [7:0] ieee_di,
                 input            ieee_atn_o,
                 output reg       ieee_atn_i,
                 input            ieee_ndac_o,
                 output reg       ieee_ndac_i,
                 input            ieee_nrfd_o,
                 output reg       ieee_nrfd_i,
                 input            ieee_dav_o,
                 output reg       ieee_dav_i,
                 output reg       ieee_srq_i,
                 input            ieee_eoi_o,
                 output reg       ieee_eoi_i,

                 input            clk,
                 input            reset);

    // Device IEEE address
    parameter [7:0]
        MY_ADDRESS = 8;

    parameter
        PRGMFILE = "program.mem",
        PRGMLEN = 2971;

    // Implement a block RAM for program data.
    (* ram_style = "block" *)
    reg [7:0]   prgm[32767:0];
    reg [7:0]   prgmdata;
    reg [14:0]  prgmaddr;

    initial $readmemh(PRGMFILE, prgm);

    always @(posedge clk)
        prgmdata <= prgm[prgmaddr];

    // Program address counter.
    reg         prgmaddr_reset;
    reg         prgmaddr_inc;
    always @(posedge clk)
        if (reset || prgmaddr_reset)
            prgmaddr <= 15'd0;
        else if (prgmaddr_inc)
            prgmaddr <= prgmaddr + 1;

    // Send program data to IEEE
    always @(posedge clk)
        ieee_di <= ~prgmdata;

    // register these inputs to detect transitions.
    reg         ieee_atn_o_1;
    reg         ieee_ndac_o_1;
    reg         ieee_nrfd_o_1;
    reg         ieee_dav_o_1;
    always @(posedge clk)
        if (reset) begin
            ieee_atn_o_1 <= 1;
            ieee_ndac_o_1 <= 1;
            ieee_nrfd_o_1 <= 1;
            ieee_dav_o_1 <= 1;
        end
        else begin
            ieee_atn_o_1 <= ieee_atn_o;
            ieee_ndac_o_1 <= ieee_ndac_o;
            ieee_nrfd_o_1 <= ieee_nrfd_o;
            ieee_dav_o_1 <= ieee_dav_o;
        end

    // Main state machine
    parameter [1:0]
        IEEE_STATE_IDLE = 0,
        IEEE_STATE_LISTEN = 1,
        IEEE_STATE_FNAME = 2,
        IEEE_STATE_TALK = 3;

    reg [1:0]   ieee_sm;

    reg [1:0]   ieee_sm_nxt;
    reg         ieee_atn_i_nxt;
    reg         ieee_ndac_i_nxt;
    reg         ieee_nrfd_i_nxt;
    reg         ieee_dav_i_nxt;
    reg         ieee_srq_i_nxt;
    reg         ieee_eoi_i_nxt;

    always @(posedge clk)
        if (reset) begin
            ieee_sm <= IEEE_STATE_IDLE;
            ieee_atn_i <= 1;
            ieee_ndac_i <= 1;
            ieee_nrfd_i <= 1;
            ieee_dav_i <= 1;
            ieee_srq_i <= 1;
            ieee_eoi_i <= 1;
        end
        else begin
            ieee_sm <= ieee_sm_nxt;
            ieee_atn_i <= ieee_atn_i_nxt;
            ieee_ndac_i <= ieee_ndac_i_nxt;
            ieee_nrfd_i <= ieee_nrfd_i_nxt;
            ieee_dav_i <= ieee_dav_i_nxt;
            ieee_srq_i <= ieee_srq_i_nxt;
            ieee_eoi_i <= ieee_eoi_i_nxt;
        end

    always @(*) begin
        // Defaults
        ieee_sm_nxt = ieee_sm;
        ieee_atn_i_nxt = ieee_atn_i;
        ieee_ndac_i_nxt = ieee_ndac_i;
        ieee_nrfd_i_nxt = ieee_nrfd_i;
        ieee_dav_i_nxt = ieee_dav_i;
        ieee_srq_i_nxt = ieee_srq_i;
        ieee_eoi_i_nxt = ieee_eoi_i;
        prgmaddr_reset = 0;
        prgmaddr_inc = 0;

        if (!ieee_atn_o && ieee_atn_o_1) begin
            // Negative transition of ATN
            ieee_ndac_i_nxt = 0;
        end

        case (ieee_sm)
            IEEE_STATE_IDLE: begin
                if (ieee_atn_o && !ieee_atn_o_1) begin
                    // Positive transition of ATN
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 1;
                end
                else if (!ieee_atn_o && ieee_dav_o && !ieee_dav_o_1) begin
                    // !ATN and Positive transition of DAV
                    ieee_ndac_i_nxt = 0;
                    ieee_nrfd_i_nxt = 1;
                end
                if (!ieee_atn_o && !ieee_dav_o && ieee_dav_o_1) begin
                    // !ATN and Negative transition of DAV
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 0;

                    if (~ieee_do == 8'h20 + MY_ADDRESS)
                        ieee_sm_nxt = IEEE_STATE_LISTEN;
                    else if (~ieee_do == 8'h40 + MY_ADDRESS) begin
                        prgmaddr_reset = 1;
                        ieee_sm_nxt = IEEE_STATE_TALK;
                    end
                end
            end

            IEEE_STATE_LISTEN: begin
                if (ieee_dav_o && !ieee_dav_o_1) begin
                    // Positive transition of DAV
                    ieee_ndac_i_nxt = 0;
                    ieee_nrfd_i_nxt = 1;
                    if (ieee_atn_o)
                        prgmaddr_inc = 1;
                end
                else if (!ieee_dav_o && ieee_dav_o_1) begin
                    // Negative transition of DAV
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 0;

                    if (!ieee_atn_o) begin
                        if (~ieee_do == 8'h3f)
                            // UNListen
                            ieee_sm_nxt = IEEE_STATE_IDLE;
                        else if (~ieee_do >= 8'hf0)
                            // Open file
                            ieee_sm_nxt = IEEE_STATE_FNAME;
                    end
                end
            end

            IEEE_STATE_FNAME: begin
                if (ieee_dav_o && !ieee_dav_o_1) begin
                    // Positive transition of DAV
                    ieee_ndac_i_nxt = 0;
                    ieee_nrfd_i_nxt = 1;
                end
                else if (!ieee_dav_o && ieee_dav_o_1) begin
                    // Negative transition of DAV
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 0;

                    if (!ieee_atn_o) begin
                        if (~ieee_do == 8'h3f)
                            // UNListen
                            ieee_sm_nxt = IEEE_STATE_IDLE;
                    end
                end
            end

            IEEE_STATE_TALK: begin
                if (ieee_atn_o && !ieee_atn_o_1) begin
                    // Positive transition of ATN
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 1;

                    if (ieee_nrfd_o) begin
                        // put data on bus
                        ieee_dav_i_nxt = 0;
                    end
                end
                else if (!ieee_atn_o && ieee_dav_o && !ieee_dav_o_1) begin
                    // !ATN and Positive transition of DAV
                    ieee_ndac_i_nxt = 0;
                    ieee_nrfd_i_nxt = 1;
                end
                else if (!ieee_atn_o && !ieee_dav_o && ieee_dav_o_1) begin
                    // !ATN and Negative transition of DAV
                    ieee_ndac_i_nxt = 1;
                    ieee_nrfd_i_nxt = 0;

                    if (~ieee_do == 8'h5f)
                        // UNTalk
                        ieee_sm_nxt = IEEE_STATE_IDLE;
                end
                if (ieee_ndac_o && !ieee_ndac_o_1) begin
                    // Positive transition of NDAC.  Data acknowledged.
                    ieee_dav_i_nxt = 1;
                    ieee_eoi_i_nxt = 1;
                    if (ieee_atn_o)
                        prgmaddr_inc = 1;
                end
                if (ieee_nrfd_o && !ieee_nrfd_o_1) begin
                    // Positive transition of NRFD
                    ieee_dav_i_nxt = 0;
                    if (prgmaddr >= PRGMLEN)
                        ieee_eoi_i_nxt = 0;
                end
            end
        endcase // ieee_sm
    end

endmodule // pet2001ieee
