`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
//
// Engineer:	Thomas Skibo 
// 
// Create Date:	Sep 26, 2011
//
// Module Name:	pet2001ps2_key
//
// Description:
//
//    	Emulate Pet 2001 matrix keyboard.  PS/2 codes are translated into
//	locations in the PET keyboard matrix.  A small RAM keeps track of
//	the state of all keys.  The translation table looks awful but I'm
//	confident the FPGA tools will map it efficiently to appropriate LUTs.
//	XXX: maybe the table should go into a block RAM.
//
/////////////////////////////////////////////////////////////////////////////
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

module pet2001ps2_key(output reg [7:0]	keyin,
                      input [3:0]	keyrow,

                      input		ps2_clk,
                      input		ps2_data,
                   
                      input		clk,
                      input		reset
               );

    //////////////////////// PS2 serial interface //////////////////////
    //
    wire [7:0]	ps2_code;
    wire 	ps2_wr;
    
    ps2_intf ps2if(.ps2_code(ps2_code),
		   .ps2_wr(ps2_wr),

		   .ps2_clk(ps2_clk),
		   .ps2_data(ps2_data),

		   .reset(reset),
		   .clk(clk)
	   );

    //////////////////////// PS2 decode ////////////////////////////////
    //
    reg         key_release;	// set by an 0xF0 code.  key is being released.
    reg         key_extended;	// set by an 0xE0 code. not used.
    reg         key_shift;	// shift key is down
    
`define PS2_RELEASE	8'hf0
`define PS2_EXTENDED	8'he0
`define PS2_SHIFT1	8'h59
`define PS2_SHIFT2	8'h12
`define PS2_ALT		8'h11
`define PS2_CTRL	8'h14
    
    
    // Flag "extended" keys (not used at the moment)
    always @(posedge clk)
	if (reset || (ps2_wr && ps2_code != `PS2_EXTENDED &&
		      ps2_code != `PS2_RELEASE))
            key_extended <= 1'b0;
	else if (ps2_wr && ps2_code == `PS2_EXTENDED)
            key_extended <= 1'b1;

    // Next code is a key release.
    always @(posedge clk)
	if (reset || (ps2_wr && ps2_code != `PS2_RELEASE))
            key_release <= 1'b0;
	else if (ps2_wr && ps2_code == `PS2_RELEASE)
            key_release <= 1'b1;
    
    // Look for SHIFT key(s)
    always @(posedge clk)
	if (reset)
            key_shift <= 1'b0;
	else if (ps2_wr && (ps2_code == `PS2_SHIFT1 ||
			    ps2_code == `PS2_SHIFT2))
            key_shift <= ! key_release;


    ////////////////////////// PS/2 to PET conversion function ////////////////
    // This script-generated function converts shift-flag and PS/2 code into
    // a PET keyboard matrix location.  column=[6:4] row=[3:0]
    //
    function [6:0] ps2_to_pet(input shift, input [7:0] code);
	begin
            case ({shift, code})
		9'h0_05:	ps2_to_pet = 7'h49;	// 0x03 (STOP)
		9'h1_05:	ps2_to_pet = 7'h49;	// 0x03
		9'h0_11:	ps2_to_pet = 7'h08;	// ALT
		9'h1_11:	ps2_to_pet = 7'h08;	// ALT
		9'h0_15:	ps2_to_pet = 7'h02;	// 'q'
		9'h1_15:	ps2_to_pet = 7'h02;	// 'Q'
		9'h0_16:	ps2_to_pet = 7'h66;	// '1'
		9'h1_16:	ps2_to_pet = 7'h00;	// '!'
		9'h0_1A:	ps2_to_pet = 7'h06;	// 'z'
		9'h1_1A:	ps2_to_pet = 7'h06;	// 'Z'
		9'h0_1B:	ps2_to_pet = 7'h05;	// 's'
		9'h1_1B:	ps2_to_pet = 7'h05;	// 'S'
		9'h0_1C:	ps2_to_pet = 7'h04;	// 'a'
		9'h1_1C:	ps2_to_pet = 7'h04;	// 'A'
		9'h0_1D:	ps2_to_pet = 7'h03;	// 'w'
		9'h1_1D:	ps2_to_pet = 7'h03;	// 'W'
		9'h0_1E:	ps2_to_pet = 7'h67;	// '2'
		9'h1_1E:	ps2_to_pet = 7'h18;	// '@'
		9'h0_21:	ps2_to_pet = 7'h16;	// 'c'
		9'h1_21:	ps2_to_pet = 7'h16;	// 'C'
		9'h0_22:	ps2_to_pet = 7'h07;	// 'x'
		9'h1_22:	ps2_to_pet = 7'h07;	// 'X'
		9'h0_23:	ps2_to_pet = 7'h14;	// 'd'
		9'h1_23:	ps2_to_pet = 7'h14;	// 'D'
		9'h0_24:	ps2_to_pet = 7'h12;	// 'e'
		9'h1_24:	ps2_to_pet = 7'h12;	// 'E'
		9'h0_25:	ps2_to_pet = 7'h64;	// '4'
		9'h1_25:	ps2_to_pet = 7'h11;	// '$'
		9'h0_26:	ps2_to_pet = 7'h76;	// '3'
		9'h1_26:	ps2_to_pet = 7'h10;	// '#'
		9'h0_29:	ps2_to_pet = 7'h29;	// ' '
		9'h1_29:	ps2_to_pet = 7'h29;	// ' '
		9'h0_2A:	ps2_to_pet = 7'h17;	// 'v'
		9'h1_2A:	ps2_to_pet = 7'h17;	// 'V'
		9'h0_2B:	ps2_to_pet = 7'h15;	// 'f'
		9'h1_2B:	ps2_to_pet = 7'h15;	// 'F'
		9'h0_2C:	ps2_to_pet = 7'h22;	// 't'
		9'h1_2C:	ps2_to_pet = 7'h22;	// 'T'
		9'h0_2D:	ps2_to_pet = 7'h13;	// 'r'
		9'h1_2D:	ps2_to_pet = 7'h13;	// 'R'
		9'h0_2E:	ps2_to_pet = 7'h65;	// '5'
		9'h1_2E:	ps2_to_pet = 7'h20;	// '%'
		9'h0_2F:	ps2_to_pet = 7'h09;	// 0x12
		9'h1_2F:	ps2_to_pet = 7'h09;	// 0x12
		9'h0_31:	ps2_to_pet = 7'h27;	// 'n'
		9'h1_31:	ps2_to_pet = 7'h27;	// 'N'
		9'h0_32:	ps2_to_pet = 7'h26;	// 'b'
		9'h1_32:	ps2_to_pet = 7'h26;	// 'B'
		9'h0_33:	ps2_to_pet = 7'h25;	// 'h'
		9'h1_33:	ps2_to_pet = 7'h25;	// 'H'
		9'h0_34:	ps2_to_pet = 7'h24;	// 'g'
		9'h1_34:	ps2_to_pet = 7'h24;	// 'G'
		9'h0_35:	ps2_to_pet = 7'h23;	// 'y'
		9'h1_35:	ps2_to_pet = 7'h23;	// 'Y'
		9'h0_36:	ps2_to_pet = 7'h74;	// '6'
		9'h1_36:	ps2_to_pet = 7'h52;	// '^'
		9'h0_3A:	ps2_to_pet = 7'h36;	// 'm'
		9'h1_3A:	ps2_to_pet = 7'h36;	// 'M'
		9'h0_3B:	ps2_to_pet = 7'h34;	// 'j'
		9'h1_3B:	ps2_to_pet = 7'h34;	// 'J'
		9'h0_3C:	ps2_to_pet = 7'h32;	// 'u'
		9'h1_3C:	ps2_to_pet = 7'h32;	// 'U'
		9'h0_3D:	ps2_to_pet = 7'h62;	// '7'
		9'h1_3D:	ps2_to_pet = 7'h30;	// '&'
		9'h0_3E:	ps2_to_pet = 7'h63;	// '8'
		9'h1_3E:	ps2_to_pet = 7'h75;	// '*'
		9'h0_41:	ps2_to_pet = 7'h37;	// ','
		9'h1_41:	ps2_to_pet = 7'h39;	// '<'
		9'h0_42:	ps2_to_pet = 7'h35;	// 'k'
		9'h1_42:	ps2_to_pet = 7'h35;	// 'K'
		9'h0_43:	ps2_to_pet = 7'h33;	// 'i'
		9'h1_43:	ps2_to_pet = 7'h33;	// 'I'
		9'h0_44:	ps2_to_pet = 7'h42;	// 'o'
		9'h1_44:	ps2_to_pet = 7'h42;	// 'O'
		9'h0_45:	ps2_to_pet = 7'h68;	// '0'
		9'h1_45:	ps2_to_pet = 7'h41;	// ')'
		9'h0_46:	ps2_to_pet = 7'h72;	// '9'
		9'h1_46:	ps2_to_pet = 7'h40;	// '('
		9'h0_49:	ps2_to_pet = 7'h69;	// '.'
		9'h1_49:	ps2_to_pet = 7'h48;	// '>'
		9'h0_4A:	ps2_to_pet = 7'h73;	// '/'
		9'h1_4A:	ps2_to_pet = 7'h47;	// '?'
		9'h0_4B:	ps2_to_pet = 7'h44;	// 'l'
		9'h1_4B:	ps2_to_pet = 7'h44;	// 'L'
		9'h0_4C:	ps2_to_pet = 7'h46;	// ';'
		9'h1_4C:	ps2_to_pet = 7'h45;	// ':'
		9'h0_4D:	ps2_to_pet = 7'h43;	// 'p'
		9'h1_4D:	ps2_to_pet = 7'h43;	// 'P'
		9'h0_4E:	ps2_to_pet = 7'h78;	// '-'
		9'h1_4E:	ps2_to_pet = 7'h50;	// '_'
		9'h0_52:	ps2_to_pet = 7'h21;	// '''
		9'h1_52:	ps2_to_pet = 7'h01;	// '"'
		9'h0_54:	ps2_to_pet = 7'h19;	// '['
		9'h0_55:	ps2_to_pet = 7'h79;	// '='
		9'h1_55:	ps2_to_pet = 7'h77;	// '+'
		9'h0_5A:	ps2_to_pet = 7'h56;	// 0x0d
		9'h1_5A:	ps2_to_pet = 7'h56;	// 0x0d
		9'h0_5B:	ps2_to_pet = 7'h28;	// ']'
		9'h0_5D:	ps2_to_pet = 7'h31;	// '\'
		9'h0_66:	ps2_to_pet = 7'h71;	// 0x08
		9'h1_66:	ps2_to_pet = 7'h71;	// 0x08
		9'h0_6C:	ps2_to_pet = 7'h60;	// 0x13
		9'h1_6C:	ps2_to_pet = 7'h60;	// 0x13
		9'h0_72:	ps2_to_pet = 7'h61;	// 0x11
		9'h1_72:	ps2_to_pet = 7'h61;	// 0x11
		9'h0_74:	ps2_to_pet = 7'h70;	// 0x1d
		9'h1_74:	ps2_to_pet = 7'h70;	// 0x1d

		default:	ps2_to_pet = 7'h7f;
            endcase // case ({shift, code})
	end
    endfunction // ps2_to_pet
   
    ////////////////// Pet 2001 Matrix little RAM ///////////////////////////
    
    // Build a 16x8 memory from LUTs.  It will store the current state
    // of the PET keyboard.  A 4-bit counter clears out the state at
    // reset.
    //
    wire [7:0]	keymx_o;
    wire [7:0] 	keymx_we;
    wire [3:0] 	keymx_a;
    wire 	keymx_d;

    reg 	keymx_rst;	// Doing reset sequence.
    reg [3:0] 	keymx_rst_a;	// Write address during reset sequence.

    genvar x;
    generate
	for (x=0; x<8; x=x+1) begin:bit
	    RAM32X1S
	    	keymatrix(.O(keymx_o[x]),
			  .A0(keymx_a[0]),
			  .A1(keymx_a[1]),
			  .A2(keymx_a[2]),
			  .A3(keymx_a[3]),
			  .A4(1'b0),
			  .D(keymx_d),
			  .WE(keymx_we[x]),
			  .WCLK(clk)
		  );
	end
    endgenerate

    // Do reset sequence.
    always @(posedge clk)
	if (reset)
	    keymx_rst <= 1'b1;
	else if (keymx_rst_a == 4'hf)
	    keymx_rst <= 1'b0;

    // Go through row addresses during reset sequence
    always @(posedge clk)
	if (reset)
	    keymx_rst_a <= 4'h0;
	else if (keymx_rst)
	    keymx_rst_a <= keymx_rst_a + 1'b1;


    ////////////////////// Write translated codes into RAM ////////////////

    // RAM isn't dual port so share address pins by even/odd clocks.
    reg		oddclock;
    always @(posedge clk)
	if (reset)
	    oddclock <= 1'b0;
	else
	    oddclock <= ~oddclock;

    reg [7:0] 	ps2_code_r;
    reg 	key_release_r;
    reg 	do_keymx_wr_nxt;
    reg 	do_keymx_wr;

    // Translate PS/2 codes into matrix locations.
    reg [3:0]	pet_row;
    reg [2:0] 	pet_column;
    always @(posedge clk)
	{ pet_column, pet_row } <= ps2_to_pet(key_shift, ps2_code_r);

    // Exlude special codes and shift keys
    wire 	ps2_real_key = (ps2_code != `PS2_EXTENDED &&
				ps2_code != `PS2_RELEASE &&
				ps2_code != `PS2_SHIFT1 &&
				ps2_code != `PS2_SHIFT2);
    // Register code, release flag
    always @(posedge clk)
	if (ps2_wr) begin
	    ps2_code_r <= ps2_code;
	    key_release_r <= key_release;
	end

    // Start key matrix write for codes other than SHIFT/EXTEND/RELEASE
    always @(posedge clk)
	if (reset)
	    do_keymx_wr_nxt <= 1'b0;
	else
	    do_keymx_wr_nxt <= ps2_wr && ps2_real_key;

    // One more clock so code gets through translator.
    always @(posedge clk)
	if (reset)
	    do_keymx_wr <= 1'b0;
	else if (do_keymx_wr_nxt)
	    do_keymx_wr <= 1'b1;
	else if (!oddclock)
	    do_keymx_wr <= 1'b0;

    // Write RAM on even clocks. (keymx_rst is reset sequence.)
    assign keymx_a = keymx_rst ? keymx_rst_a :
		     (oddclock ? keyrow : pet_row);
    assign keymx_we = keymx_rst ? 8'hFF :
		      ((do_keymx_wr && !oddclock) ?
		       (8'h01 << pet_column) : 8'h00);
    assign keymx_d = keymx_rst || key_release_r;

    // Read RAM on odd clocks.
    always @(posedge clk)
	if (oddclock)
	    keyin <= keymx_o;

endmodule // pet2001ps2_key
