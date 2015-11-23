`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
//
// Engineer:         Thomas Skibo
// 
// Create Date:      Sep 23, 2011
//
// Module Name:      pet2001hw
//
// Description:      Encapsulate all Pet hardware except cpu.
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

module pet2001hw(
		 input [15:0]     addr, // CPU Interface
	         input [7:0]      data_in,
	         output reg [7:0] data_out,
	         input            we,
	         output           rdy,
	         output           nmi,
	         output           irq,

                 output [1:0]	  vidout,  // Composite video

                 output [3:0]     keyrow, // Keyboard
                 input [7:0]      keyin,

                 output           cass_motor_n, // Cassette
                 output           cass_write,
                 input            cass_sense_n,
                 input            cass_read,

                 output           audio, // CB2 audio

                 input            clk_speed,
                 input            clk_stop,
                 input            diag_l,

	         input            clk,
	         input            reset
	 );

    assign   nmi = 0;    // unused for now

    ////////////////////////////////////////////////////////////////
    // Create a 1Mhz "slow clock" (actually it's a pulse).  This
    // will pace the CPU and VIA Timers at close to original speed.
    // Asserting clk_speed will let everything go at full speed.
    // Asserting clk_stop will suspend it.
    ///////////////////////////////////////////////////////////////
    reg [6:0] 	clkdiv;
    reg 	slow_clock;
    
`ifdef CLK100MHZ
 `define CLKDIV_VAL 7'd99
`elsif CLK25MHZ
 `define CLKDIV_VAL 7'd24
`else
 `define CLKDIV_VAL 7'd49
`endif
    
    always @(posedge clk)
	if (reset || clkdiv == 7'd0)
	    clkdiv <= `CLKDIV_VAL;
	else
	    clkdiv <= clkdiv - 1'b1;

    always @(posedge clk)
	if (reset)
            slow_clock <= 1'b0;
	else
            slow_clock <= (clk_speed || clkdiv == 7'd1) && !clk_stop;
   
    ///////////////////////////////////////////////////////////////
    // rdy logic: A wait state is needed for video RAM and I/O.  rdy is also
    // held back until slow_clock pulse if clk_speed isn't asserted.
    ///////////////////////////////////////////////////////////////
    reg 	rdy_r;
    wire 	needs_cycle = (addr[15:11] == 5'b1110_1);

    assign rdy = rdy_r || (clk_speed && !needs_cycle);
		 
    always @(posedge clk)
	if (reset)
            rdy_r <= 0;
	else
            rdy_r <= slow_clock && ! rdy;
    
    /////////////////////////////////////////////////////////////
    // Pet ROMS incuding character ROM.  Character data is read
    // out second port.  This brings total ROM to 16K which is
    // easy to arrange.
    /////////////////////////////////////////////////////////////
    wire [7:0]	rom_data;
   
    wire [10:0] charaddr;
    wire [7:0] 	chardata;
   
    pet2001roms rom( .data(rom_data),
                     .addr(addr[13:0]),
                    
                     .charaddr(charaddr),
                     .chardata(chardata),
                    
                     .clk(clk)
	     );
      
    //////////////////////////////////////////////////////////////
    // Pet RAM and video RAM.  Video RAM is dual ported.
    //////////////////////////////////////////////////////////////
    wire [7:0] 	ram_data;
    wire [7:0] 	vram_data;
    wire [7:0] 	video_data;
    wire [10:0] video_addr;

    wire	ram_we = we && (addr[15:14] == 2'b00);
    wire	vram_we = we && (addr[15:11] == 5'b1000_0);

    pet2001ram ram(.data_out(ram_data),
                   .data_in(data_in),
                   .addr(addr[13:0]),
                   .we(ram_we),
        
                   .clk(clk)
	   );

    pet2001vidram vidram(.data_out(vram_data),
                         .data_in(data_in),
                         .cpu_addr(addr[10:0]),
                         .we(vram_we),
        
                         .video_addr(video_addr),
                         .video_data(video_data),
        
                         .clk(clk)
		 );

   //////////////////////////////////////
   // Video hardware.
   //////////////////////////////////////
    wire	video_on;	// signal indicating VGA is scanning visible
    				// rows.  Used to generate tick interrupts.
    wire 	video_blank;	// blank screen during scrolling
    wire	video_gfx;	// display graphic characters vs. lower-case
    
    pet2001ntsc vid(.vidout(vidout),

                    .video_addr(video_addr),
                    .video_data(video_data),
        
                    .charaddr(charaddr),
                    .chardata(chardata),

                    .video_on(video_on),
                    .video_blank(video_blank),
                    .video_gfx(video_gfx),
        
                    .clk(clk),
                    .reset(reset)
            );
    
    ////////////////////////////////////////////////////////
    // I/O hardware
    ////////////////////////////////////////////////////////
    wire [7:0] 	io_read_data;
    wire 	io_we = we && (addr[15:11] == 5'b1110_1);

    pet2001io io(.data_out(io_read_data),
                 .data_in(data_in),
                 .addr(addr[10:0]),
                 .rdy(rdy),
                 .we(io_we),

                 .irq(irq),

		 .keyrow(keyrow),
		 .keyin(keyin),
		 
                 .video_sync(video_on),
                 .video_blank(video_blank),
                 .video_gfx(video_gfx),

                 .cass_motor_n(cass_motor_n),
                 .cass_write(cass_write),
                 .audio(audio),
                 .cass_sense_n(cass_sense_n),
                 .cass_read(cass_read),

                 .diag_l(diag_l),
	
                 .slow_clock(slow_clock),
        
                 .clk(clk),
                 .reset(reset)
	 );

    /////////////////////////////////////
    // Read data mux (to CPU)
    /////////////////////////////////////
    always @(*)
	casex (addr[15:11])
            5'b1110_1:           		// E800
		data_out = io_read_data;
            5'b11xx_x:           		// C000-FFFF
		data_out = rom_data;
            5'b1000_0:				// 8000-87FF
		data_out = vram_data;
            5'b00xx_x:				// 0000-3FFF
		data_out = ram_data;
            default:
		data_out = 8'h55;
	endcase
    
endmodule // pet2001hw

