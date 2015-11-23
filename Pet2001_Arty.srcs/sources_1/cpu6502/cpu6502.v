`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Thomas Skibo
// 
// Create Date:    22:28:56 08/21/2007 
// Modified:	   Thu Dec 15 12:21:26 PST 2011
//
// Module Name:    cpu6502 
// Description:
//
//      Yet another 6502 implementation.  This is NOT a cycle accurate
//	implementation of the 6502.
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2007-2011, Thomas Skibo.  All rights reserved.
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

module cpu6502(output reg [15:0]	addr,
	       output reg [7:0]		data_out,
	       output reg      		we,
	       input [7:0]    		data_in,
	       input          		rdy,
	       input          		irq,
	       input          		nmi,
	       input          		reset,
	       input          		clk
       );

`define IRQ_VEC   16'hfffe
`define RESET_VEC 16'hfffc
`define NMI_VEC   16'hfffa

    /////////////// CPU Regs ////////////////
    //
    reg [15:0] 		pc;		// program counter
    reg [7:0] 		acc;           	// accumulator
    reg [7:0] 		x;             	// x index reg
    reg [7:0] 		y;             	// y indexreg
    reg [7:0] 		sp;            	// stack pointer
    reg [7:0] 		p;	     	// processor status
`define P_N    7
`define P_V    6
`define P_1    5   // always one.
`define P_B    4
`define P_D    3
`define P_I    2
`define P_Z    1
`define P_C    0
    
    reg [7:0] 		instr;		// current instruction
    reg [7:0] 		data_in_r;
    reg [7:0] 		opaddr_l;
    reg [7:0] 		opaddr_h;
    reg 		nmi_r;
    reg 		irq_r;
    
    // register these inputs
    always @(posedge clk)
	if (reset) begin
            irq_r <=    0;
            nmi_r <=    0;
	end
	else begin
            irq_r <=    irq;
            nmi_r <=    nmi;
	end

    always @(posedge clk)
	if (rdy)
	    data_in_r <= data_in;
    
    /////////////////
    // NMI Logic
    /////////////////
    reg   		nmi_r_1;       	// nmi_r in previous cycle?
    reg 		do_nmi;        	// set by nmi transition,
    					//  cleared by state machine
    reg 		clr_do_nmi;    	// from cpu state machine
    always @(posedge clk)
	if (reset)
	    nmi_r_1 <= 0;
	else
	    nmi_r_1 <= nmi_r;
    always @(posedge clk)
	if (reset || clr_do_nmi)
	    do_nmi <= 0;
	else if (nmi_r && !nmi_r_1)
	    do_nmi <= 1;
    
   ///////////////////////////////////////////////////////////////////////////
   // Instruction Decode Logic
   //////////////////////////////////////////////////////////////////////////
      
    parameter [4:0]	INSTR_TYPE_ALU =         0,
        		INSTR_TYPE_STA =         1,
                     	INSTR_TYPE_BRANCH =      2,
                     	INSTR_TYPE_TYA =         3,
                     	INSTR_TYPE_TAY =         4,
                     	INSTR_TYPE_TAX =         5,
                     	INSTR_TYPE_TSX =         6,
                     	INSTR_TYPE_DEX =         7,
                     	INSTR_TYPE_DEY =         8,
                     	INSTR_TYPE_TXA =         9,
                     	INSTR_TYPE_TXS =         10,
                     	INSTR_TYPE_SCFLAGS =     11,
                     	INSTR_TYPE_SHIFT =       12,
                     	INSTR_TYPE_PSHPUL =      13,
                     	INSTR_TYPE_LDXY =        14,
                     	INSTR_TYPE_STXY =        15,
                     	INSTR_TYPE_INCXY =       16,
                     	INSTR_TYPE_CMPXY =       17,
                     	INSTR_TYPE_INCDEC =      18,
                     	INSTR_TYPE_BIT =         19,
                     	INSTR_TYPE_RTSI =        20,
                     	INSTR_TYPE_JSR =         21,
                     	INSTR_TYPE_JMP =         22,
                     	INSTR_TYPE_BRK =         23,
                     	INSTR_TYPE_NOP =         24,
		     	INSTR_TYPE_UNKNOWN =     25;

    function [4:0] instr_type_func(input [7:0] instr);
	begin
	    casex (instr)
		8'b0000_0000:	instr_type_func = INSTR_TYPE_BRK;
		8'b1110_1010:	instr_type_func = INSTR_TYPE_NOP;
		
		8'b????_??01:            	// ALU/STA instr
		    if (instr[7:5] == 3'b100)
			instr_type_func = INSTR_TYPE_STA;
		    else
			instr_type_func = INSTR_TYPE_ALU;            
		
		8'b???1_0000:	instr_type_func = INSTR_TYPE_BRANCH;
		8'b1001_1000:	instr_type_func = INSTR_TYPE_TYA;
		8'b1010_1000:	instr_type_func = INSTR_TYPE_TAY;
		8'b1010_1010:	instr_type_func = INSTR_TYPE_TAX;
		8'b1011_1010:	instr_type_func = INSTR_TYPE_TSX;
		8'b1100_1010:	instr_type_func = INSTR_TYPE_DEX;
		8'b1000_1000:	instr_type_func = INSTR_TYPE_DEY;
		8'b1000_1010:	instr_type_func = INSTR_TYPE_TXA;
		8'b1001_1010:	instr_type_func = INSTR_TYPE_TXS;
		
		8'b11?0_1000:	instr_type_func = INSTR_TYPE_INCXY;         

		8'b???1_1000:	instr_type_func = INSTR_TYPE_SCFLAGS;
		
		8'b0??0_1000:	instr_type_func = INSTR_TYPE_PSHPUL;
		
		8'b0010_?100:	instr_type_func = INSTR_TYPE_BIT;
		
		8'b01?0_0000:	instr_type_func = INSTR_TYPE_RTSI;
		
		8'b0010_0000:	instr_type_func = INSTR_TYPE_JSR;
		
		8'b01?0_1100:	instr_type_func = INSTR_TYPE_JMP;

		// ASL/LSR/ROL/ROR (shift ops)		
		8'b0???_??10:	instr_type_func = INSTR_TYPE_SHIFT;	
		
		8'b101?_???0:	instr_type_func = INSTR_TYPE_LDXY;
		
		8'b100?_?1?0:	instr_type_func = INSTR_TYPE_STXY;
		
		8'b11?0_??00:	instr_type_func = INSTR_TYPE_CMPXY;
		
		8'b11??_?110:	instr_type_func = INSTR_TYPE_INCDEC;
`ifdef brkundefined
		default:	instr_type_func = INSTR_TYPE_UNKNOWN;
`else
		default:	instr_type_func = 5'bxxxxx;
`endif
	    endcase // case (instr)
	end
    endfunction // instr_type_func
    

    wire [4:0] instr_type = instr_type_func(instr);
   
    parameter [3:0]  ADDR_MODE_IMPLIED =       0,
                     ADDR_MODE_IMMEDIATE =     1,
                     ADDR_MODE_ZEROPG =        2,
                     ADDR_MODE_ZEROPG_X =      3,
                     ADDR_MODE_ZEROPG_Y =      4,
                     ADDR_MODE_JMP_ABS =       5,
                     ADDR_MODE_ABS =           6,
                     ADDR_MODE_ABS_X =         7,
                     ADDR_MODE_ABS_Y =         8,
                     ADDR_MODE_JMP_INDIRECT =  9,
                     ADDR_MODE_INDIRECT_X =    10,
                     ADDR_MODE_INDIRECT_Y =    11;

    function [3:0] addr_mode_func(input [7:0] instr);
	begin
	    casex (instr)
		8'b0000_0000,						// BRK
		8'b1110_1010: addr_mode_func = ADDR_MODE_IMPLIED;  	// NOP
		
		8'b????_??01:   					// ALU/STA instr
		    case (instr[4:2])
			3'b000:  addr_mode_func = ADDR_MODE_INDIRECT_X;
			3'b001:  addr_mode_func = ADDR_MODE_ZEROPG;
			3'b010:  addr_mode_func = ADDR_MODE_IMMEDIATE;
			3'b011:  addr_mode_func = ADDR_MODE_ABS;
			3'b100:  addr_mode_func = ADDR_MODE_INDIRECT_Y;
			3'b101:  addr_mode_func = ADDR_MODE_ZEROPG_X;
			3'b110:  addr_mode_func = ADDR_MODE_ABS_Y;
			3'b111:  addr_mode_func = ADDR_MODE_ABS_X;
		    endcase // case (instr[4:2])
		
      		// (relative, actually)  conditional branches		
		8'b???1_0000:  addr_mode_func = ADDR_MODE_IMMEDIATE;

		8'b1001_1000, 						// TYA
		    8'b1010_1000,					// TAY
		    8'b1010_1010, 					// TAX
		    8'b1011_1010,					// TSX
		    8'b1100_1010,					// DEX
		    8'b1000_1000,					// DEY
		    8'b1000_1010,					// TXA
		    8'b1001_1010,					// TXS
            
		    8'b11?0_1000,					// INCXY;
	    
		    8'b???1_1000,  					// S/C FLAGS;
            
		    8'b0??0_1000: 					// PUSH/PULL
			addr_mode_func = ADDR_MODE_IMPLIED;

		8'b0010_0100:	addr_mode_func = ADDR_MODE_ZEROPG;	// BIT
		8'b0010_1100:  	addr_mode_func = ADDR_MODE_ABS;		// BIT
		
		8'b0010_0000:  addr_mode_func = ADDR_MODE_JMP_ABS;	// JSR

		8'b0100_1100:	addr_mode_func = ADDR_MODE_JMP_ABS;	// JSR
		8'b0110_1100:	addr_mode_func = ADDR_MODE_JMP_INDIRECT;
		
		8'b01?0_0000:  addr_mode_func = ADDR_MODE_IMPLIED;	// RTSI
		
		8'b0???_??10: 		 	// ASL/LSR/ROL/ROR (shift ops)
		    case (instr[4:2])
			3'b010:  addr_mode_func = ADDR_MODE_IMPLIED; 	// acc
			3'b001:  addr_mode_func = ADDR_MODE_ZEROPG;
			3'b101:  addr_mode_func = ADDR_MODE_ZEROPG_X;
			3'b011:  addr_mode_func = ADDR_MODE_ABS;
			3'b111:  addr_mode_func = ADDR_MODE_ABS_X;
			default: addr_mode_func = 4'hX;
		    endcase
		
		8'b101?_???0:  						// LD[XY]
		    case (instr[4:2])
			3'b000:  addr_mode_func = ADDR_MODE_IMMEDIATE;
			3'b001:  addr_mode_func = ADDR_MODE_ZEROPG;
			3'b101:  addr_mode_func = instr[1] ? ADDR_MODE_ZEROPG_Y : ADDR_MODE_ZEROPG_X;
			3'b011:  addr_mode_func = ADDR_MODE_ABS;
			3'b111:  addr_mode_func = instr[1] ? ADDR_MODE_ABS_Y : ADDR_MODE_ABS_X;
			default: addr_mode_func = 4'hX;
		    endcase
		8'b100?_?1?0:    					// ST[XY]
		    case (instr[4:3])
			2'b00:   addr_mode_func = ADDR_MODE_ZEROPG;
			2'b10:   addr_mode_func = instr[1] ? ADDR_MODE_ZEROPG_Y : ADDR_MODE_ZEROPG_X;
			2'b01:   addr_mode_func = ADDR_MODE_ABS;
			default: addr_mode_func = 4'hX;
		    endcase
		
		8'b11?0_??00: 						// CMP[XY]
		    case (instr[3:2])
			2'b00:   addr_mode_func = ADDR_MODE_IMMEDIATE;
			2'b01:   addr_mode_func = ADDR_MODE_ZEROPG;
			2'b11:   addr_mode_func = ADDR_MODE_ABS;
			default: addr_mode_func = 4'hX;
		    endcase
		
		8'b11??_?110: 						// INC/DEC
		    case (instr[4:3])
			2'b00:   addr_mode_func = ADDR_MODE_ZEROPG;
			2'b10:   addr_mode_func = ADDR_MODE_ZEROPG_X;
			2'b01:   addr_mode_func = ADDR_MODE_ABS;
			2'b11:   addr_mode_func = ADDR_MODE_ABS_X;
		    endcase
		
		default:  addr_mode_func = 3'hX;
		
	    endcase // case(instr)
	end
    endfunction
    

    wire [3:0] addr_mode = addr_mode_func(instr);
    
    // This function helps further decode
    // conditional branches.
    function [0:0] do_branch_func(input [7:0] instr,
				  input [7:0] p);
	begin
            case (instr[7:6])
		2'b00:   do_branch_func = (p[`P_N] == instr[5]);
		2'b01:   do_branch_func = (p[`P_V] == instr[5]);
		2'b10:   do_branch_func = (p[`P_C] == instr[5]);
		2'b11:   do_branch_func = (p[`P_Z] == instr[5]);
            endcase
	end
    endfunction


    wire [15:0] pc_inc = pc + 1'b1;
    wire [15:0]	pc_dec = pc - 1'b1;
    wire [7:0] 	sp_inc = sp + 1'b1;
    wire [7:0] 	sp_dec = sp - 1'b1;

    /////////////////////////////////////////////////////
    // Main CPU State machine
    /////////////////////////////////////////////////////
    reg [4:0]      cpu_sm;
   
    parameter [4:0]	CPU_SM_RESET =          5'd0,
                   	CPU_SM_VECTOR1 =     	5'd1,
                   	CPU_SM_VECTOR2 =     	5'd2,
			CPU_SM_STALL = 		5'd3,
                   	CPU_SM_DECODE =         5'd4,
                   	CPU_SM_FETCH_I1 =       5'd5,
                   	CPU_SM_FETCH_I2 =       5'd6,
                   	CPU_SM_FETCH_INL =      5'd7,
                   	CPU_SM_FETCH_INH =      5'd8,
                   	CPU_SM_EXECUTE =        5'd9,
                   	CPU_SM_STORE =          5'd10,
                   	CPU_SM_PULL =           5'd11,
                   	CPU_SM_JSR1 =           5'd12,
                   	CPU_SM_JSR2 =           5'd13,
                   	CPU_SM_RTI =            5'd14,
                   	CPU_SM_RTS1 =           5'd15,
                   	CPU_SM_RTS2 =           5'd16,
                   	CPU_SM_INTR1 =          5'd17,
                   	CPU_SM_INTR2 =          5'd18,
                   	CPU_SM_INTR3 =          5'd19,
			CPU_SM_INTR4 = 		5'd20;

    // combinatorial outputs of always @(*) block below.
    reg [4:0] 	   cpu_sm_nxt;
    reg [15:0] 	   pc_nxt;
    reg [7:0] 	   sp_nxt;
    reg [7:0] 	   p_nxt;
    reg [7:0] 	   acc_nxt;
    reg [7:0] 	   x_nxt;
    reg [7:0] 	   y_nxt;
    reg [7:0] 	   instr_nxt;
    reg [7:0] 	   opaddr_l_nxt;
    reg [7:0] 	   opaddr_h_nxt;

    // CPU SM register
    always @(posedge clk)
	if (reset)
	    cpu_sm <=	CPU_SM_RESET;
	else
	    cpu_sm <= 	cpu_sm_nxt;

    // Implement Registers
    always @(posedge clk) begin
	pc <= 		pc_nxt;
	sp <= 		sp_nxt;
	p <= 		p_nxt;
	
	acc <=		acc_nxt;
	x <=		x_nxt;
	y <=		y_nxt;
	instr <=	instr_nxt;
	opaddr_l <=	opaddr_l_nxt;
	opaddr_h <=	opaddr_h_nxt;
    end

    // Main state machine.
    always @(*) begin
	// Defaults
	cpu_sm_nxt =	cpu_sm;
	sp_nxt =	sp;
	p_nxt =		p;
	pc_nxt =	pc;
	acc_nxt =	acc;
	x_nxt =		x;
	y_nxt =		y;
	instr_nxt =	instr;
	opaddr_l_nxt =	opaddr_l;
	opaddr_h_nxt =	opaddr_h;

	addr =		pc;
	data_out =	8'hXX;
	we =		0;
	
	clr_do_nmi =	0;

	case (cpu_sm)
	    CPU_SM_RESET: begin
		pc_nxt = `RESET_VEC;
		sp_nxt = 8'hff;
		p_nxt = 8'h24;
		addr = `RESET_VEC;
		if (rdy && !reset) begin
		    pc_nxt = pc_inc;
		    cpu_sm_nxt = CPU_SM_VECTOR1;
		end
	    end

	    // Fetched low byte of RESET, NMI, or IRQ vector.  Vector address is in pc.
	    CPU_SM_VECTOR1: begin
		opaddr_l_nxt = data_in_r;
		if (rdy)
		    cpu_sm_nxt = CPU_SM_VECTOR2;
	    end

	    // Fetched high byte of RESET, NMI, or IRQ vector.
	    CPU_SM_VECTOR2: begin
		pc_nxt = {data_in_r, opaddr_l};
		if (rdy)
		    cpu_sm_nxt = CPU_SM_STALL;
	    end

	    // If PC changed, we need to stall.
	    CPU_SM_STALL: begin
		instr_nxt = data_in;
		if (rdy) begin
		    pc_nxt = pc_inc;
		    cpu_sm_nxt = CPU_SM_DECODE;
		end
	    end

	    // Decode opcode and execute many single byte instructions.
	    CPU_SM_DECODE: begin
		if (do_nmi || (irq_r && ! p[`P_I])) begin // IRQ, NMI?
		    pc_nxt = pc_dec;
		    cpu_sm_nxt = CPU_SM_INTR1;
		end
		else begin
		    
		    if (instr_type == INSTR_TYPE_PSHPUL) begin
			if (instr[5])   	// PLP/PLA
			    addr = {8'h01, sp_inc};
			else begin
			    addr = {8'h01, sp}; // PHP/PHA
			    data_out = instr[6] ? acc : (p | (8'd1<<`P_B));
			    we = 1;
			end
		    end
		    else if (instr_type == INSTR_TYPE_RTSI)
			addr = {8'h01, sp_inc};
		    
		    if (rdy) begin
			if (addr_mode == ADDR_MODE_IMPLIED) begin

			    if (instr_type != INSTR_TYPE_RTSI &&
				instr_type != INSTR_TYPE_PSHPUL) begin
				pc_nxt = pc_inc;
				instr_nxt = data_in;
			    end

			    // Most one-byte instructions are handled here.
			    case (instr_type)
				INSTR_TYPE_TYA: begin
				    p_nxt[`P_Z] = (y == 8'h00);
				    p_nxt[`P_N] = y[7];
				    acc_nxt = y;
				end
				INSTR_TYPE_TAY: begin
				    p_nxt[`P_Z] = (acc == 8'h00);
				    p_nxt[`P_N] = acc[7];
				    y_nxt = acc;
				end
				INSTR_TYPE_TAX: begin
				    p_nxt[`P_Z] = (acc == 8'h00);
				    p_nxt[`P_N] = acc[7];
				    x_nxt = acc;
				end
				INSTR_TYPE_TSX: begin
				    p_nxt[`P_Z] = (sp == 8'h00);
				    p_nxt[`P_N] = sp[7];
				    x_nxt = sp;
				end
				INSTR_TYPE_DEX: begin
				    p_nxt[`P_Z] = (x == 8'h01);
				    p_nxt[`P_N] = (x == 8'h00 || (x[7] && x != 8'h80));
				    x_nxt = x - 1'b1;
				end
				INSTR_TYPE_DEY: begin
				    p_nxt[`P_Z] = (y == 8'h01);
				    p_nxt[`P_N] = (y == 8'h00 || (y[7] && y != 8'h80));
				    y_nxt = y - 1'b1;
				end
				INSTR_TYPE_TXA: begin
				    p_nxt[`P_Z] = (x == 8'h00);
				    p_nxt[`P_N] = x[7];
				    acc_nxt = x;
				end
				INSTR_TYPE_TXS:
				    sp_nxt = x;
				INSTR_TYPE_INCXY:
				    if (instr[5]) begin
					p_nxt[`P_Z] = (x == 8'hff);
					p_nxt[`P_N] = (x == 8'h7f || (x[7] && x != 8'hff));
					x_nxt = x + 1'b1;
				    end
				    else begin
					p_nxt[`P_Z] = (y == 8'hff);
					p_nxt[`P_N] = (y == 8'h7f || (y[7] && y != 8'hff));
					y_nxt = y + 1'b1;
				    end
				INSTR_TYPE_SCFLAGS:
				    // Set or clear P flags.
				    case (instr[7:6])
					2'b00: p_nxt[`P_C] = instr[5];
					2'b01: p_nxt[`P_I] = instr[5];
					2'b10: p_nxt[`P_V] = 1'b0;
					2'b11: p_nxt[`P_D] = instr[5];
				    endcase
				INSTR_TYPE_SHIFT: begin
				    case (instr[6:5])
					2'b00:  {p_nxt[`P_C], acc_nxt} = {acc, 1'b0};	// ASL
					2'b01:  {p_nxt[`P_C], acc_nxt} = {acc, p[`P_C]};// ROL
					2'b10:  {acc_nxt, p_nxt[`P_C]} = {1'b0, acc};	// LSR
					2'b11:  {acc_nxt, p_nxt[`P_C]} = {p[`P_C], acc};// ROR
				    endcase
				    
				    p_nxt[`P_Z] = (acc_nxt == 8'h00);
				    p_nxt[`P_N] = acc_nxt[7];
				end
				
				INSTR_TYPE_PSHPUL:
				    if (instr[5]) begin   // PLP/PLA
					sp_nxt = sp_inc;
					cpu_sm_nxt = CPU_SM_PULL;
				    end
				    else begin
					sp_nxt = sp_dec;
					cpu_sm_nxt = CPU_SM_STORE;
				    end
				
				INSTR_TYPE_RTSI: begin
				    sp_nxt = sp_inc;
				    if (instr[5])
					cpu_sm_nxt = CPU_SM_RTS1;
				    else
					cpu_sm_nxt = CPU_SM_RTI;
				end
				
				INSTR_TYPE_BRK: begin
				    p_nxt[`P_B] = 1;
				    cpu_sm_nxt = CPU_SM_INTR1;
				end

				INSTR_TYPE_NOP: ;
				default: begin
`ifdef brkundefined
				    p_nxt[`P_B] = 1;
				    cpu_sm_nxt = CPU_SM_INTR1;
`endif
`ifdef simulation
				    $display("%t: decode problem in cpu sm",$time);
				    $stop;
`endif
				end
			    endcase // instr_type
			end
			else if (addr_mode == ADDR_MODE_IMMEDIATE) begin
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_EXECUTE;
			end
			else begin
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_FETCH_I1;
			end
		    end // if (rdy)
		end
	    end // case: CPU_SM_DECODE

	    // Fetched second byte of an instruction
	    CPU_SM_FETCH_I1: begin
		
		// Calculate address output
		case (addr_mode)
		    ADDR_MODE_ZEROPG:       addr = {8'h00, data_in_r};
		    ADDR_MODE_ZEROPG_X:     addr = {8'h00, data_in_r + x};
		    ADDR_MODE_ZEROPG_Y:     addr = {8'h00, data_in_r + y};
		    ADDR_MODE_INDIRECT_X:   addr = {8'h00, data_in_r + x};
		    ADDR_MODE_INDIRECT_Y:   addr = {8'h00, data_in_r};
		endcase

		if ((addr_mode == ADDR_MODE_ZEROPG ||
		     addr_mode == ADDR_MODE_ZEROPG_X ||	     
		     addr_mode == ADDR_MODE_ZEROPG_Y) &&
		    (instr_type == INSTR_TYPE_STA ||
		     instr_type == INSTR_TYPE_STXY)) begin
		    we = 1;
		    data_out = ((instr_type == INSTR_TYPE_STA) ? acc : (instr[1] ? x : y));
		end
		
		opaddr_h_nxt = 8'h00;
		
		if (rdy) begin
		    if (instr_type == INSTR_TYPE_JSR) begin
			opaddr_l_nxt = data_in_r;
			cpu_sm_nxt = CPU_SM_JSR1;
		    end
		    else begin
			case (addr_mode)
			    ADDR_MODE_ZEROPG,
			    ADDR_MODE_ZEROPG_X,
			    ADDR_MODE_ZEROPG_Y: begin
				opaddr_l_nxt = addr[7:0];
				if (instr_type == INSTR_TYPE_STA || instr_type == INSTR_TYPE_STXY)
				    cpu_sm_nxt = CPU_SM_STORE;
				else
				    cpu_sm_nxt = CPU_SM_EXECUTE;
			    end
			    ADDR_MODE_INDIRECT_X,
			    ADDR_MODE_INDIRECT_Y: begin
				opaddr_l_nxt = addr[7:0];
				cpu_sm_nxt = CPU_SM_FETCH_INL;
			    end
			    default: begin
				opaddr_l_nxt = data_in_r;
				pc_nxt = pc_inc;
				cpu_sm_nxt = CPU_SM_FETCH_I2;
			    end
			endcase
		    end
		end
	    end // case: CPU_SM_FETCH_I1
	    
	    // Fetch third byte of an instruction.
	    CPU_SM_FETCH_I2: begin
		case (addr_mode)
		    ADDR_MODE_ABS_X:  addr = {data_in_r, opaddr_l} + x;
		    ADDR_MODE_ABS_Y:  addr = {data_in_r, opaddr_l} + y;
		    default:          addr = {data_in_r, opaddr_l};
		endcase

		if (instr_type == INSTR_TYPE_STA || instr_type == INSTR_TYPE_STXY) begin
		    we = 1;
		    data_out = ((instr_type == INSTR_TYPE_STA) ? acc : (instr[1] ? x : y));
		end		    
		
		opaddr_h_nxt = addr[15:8];
		    
		if (rdy) begin
		    opaddr_l_nxt = addr[7:0];
		    case (instr_type)
			INSTR_TYPE_STA,
			INSTR_TYPE_STXY:
			    cpu_sm_nxt = CPU_SM_STORE;
			INSTR_TYPE_JMP:
			    if (addr_mode == ADDR_MODE_JMP_INDIRECT)
				cpu_sm_nxt = CPU_SM_FETCH_INL;
			    else begin
				pc_nxt = {data_in_r, opaddr_l};
				cpu_sm_nxt = CPU_SM_STALL;
			    end
			default:
			    cpu_sm_nxt = CPU_SM_EXECUTE;
		    endcase
		end
	    end // case: CPU_SM_FETCH_I2
	    
	    // Fetched one-byte operand or low-byte of address for
	    // indirect addressing modes.
	    CPU_SM_FETCH_INL: begin
		addr = {opaddr_h, opaddr_l + 1'b1};
		
		if (rdy) begin
		    opaddr_l_nxt = data_in_r;
		    cpu_sm_nxt = CPU_SM_FETCH_INH;
		end
	    end
	    
	    // Fetched high-byte of address for indirect addressing modes.
	    CPU_SM_FETCH_INH: begin
		
		if (addr_mode == ADDR_MODE_INDIRECT_Y)
		    addr = {data_in_r, opaddr_l} + y;
		else
		    addr = {data_in_r, opaddr_l};
		if (instr_type == INSTR_TYPE_STA) begin
		    data_out = acc;
		    we = 1;
		end
		
		if (rdy) begin
		    case (instr_type)
			INSTR_TYPE_STA:
			    cpu_sm_nxt = CPU_SM_STORE;
			INSTR_TYPE_JMP: begin
			    pc_nxt = {data_in_r, opaddr_l};
			    cpu_sm_nxt = CPU_SM_STALL;
			end
			default:
			    cpu_sm_nxt = CPU_SM_EXECUTE;
		    endcase
		end
	    end // case: CPU_SM_FETCH_INH
	    
	    // Store cycle
	    CPU_SM_STORE:    		// STA, STX, STY, all the RMW stores.
		if (rdy) begin
		    pc_nxt = pc_inc;
		    instr_nxt = data_in;
		    cpu_sm_nxt = CPU_SM_DECODE;
		end
		
	    // Execute cycle for instructions not handled in decode cycle
	    CPU_SM_EXECUTE: begin

		// Determine addr, data_out, and we signals.
		case (instr_type)
		    INSTR_TYPE_BRANCH:
			if (do_branch_func(instr,p))
			    addr = pc + {{8{data_in_r[7]}}, data_in_r};
		    
		    INSTR_TYPE_SHIFT: begin			// RMW Shift instructions
			addr = {opaddr_h, opaddr_l};
			case (instr[6:5])
			    2'b00:  data_out = {data_in_r[6:0], 1'b0};		// ASL
			    2'b01:  data_out = {data_in_r[6:0], p[`P_C]};	// ROL
			    2'b10:  data_out = {1'b0, data_in_r[7:1]};		// LSR
			    2'b11:  data_out = {p[`P_C], data_in_r[7:1]};	// ROR
			endcase
			we = 1;
		    end

		    INSTR_TYPE_INCDEC: begin			// RMW INC/DEC instructions
			addr = {opaddr_h, opaddr_l};
			if (instr[5])
			    data_out = data_in_r + 1'b1;
			else
			    data_out = data_in_r - 1'b1;
			we = 1;
		    end
		endcase
		    
		if (rdy) begin
		    
		    if (addr_mode == ADDR_MODE_IMMEDIATE)
			pc_nxt = pc_inc;

		    case (instr_type)
			INSTR_TYPE_ALU: begin
			    case (instr[7:5])
				3'b000:  acc_nxt = acc | data_in_r;	// ORA
				3'b001:  acc_nxt = acc & data_in_r;	// AND
				3'b010:  acc_nxt = acc ^ data_in_r;	// EOR
				3'b011: begin     			// ADC
				    if (p[`P_D]) begin:bcd_adc
					reg half_carry;
					reg carry_nxt;
					
					half_carry = ({1'b0,acc[3:0]}+data_in_r[3:0]+p[`P_C] > 5'd9);
					carry_nxt = ({1'b0,acc[7:4]}+data_in_r[7:4]+half_carry > 5'd9);
					
					acc_nxt = {(acc[7:4]+data_in_r[7:4]+half_carry+(carry_nxt?4'd6:4'd0)),
						   (acc[3:0]+data_in_r[3:0]+p[`P_C]+(half_carry?4'd6:4'd0))};

					p_nxt[`P_C] = carry_nxt;
				    end
				    else
					{p_nxt[`P_C], acc_nxt} = {1'b0, acc} + data_in_r + p[`P_C];
				    p_nxt[`P_V] = (acc[7] == data_in_r[7]) && (acc[7] != acc_nxt[7]);
				end
				3'b101:  acc_nxt = data_in_r;    	// LDA
				3'b110: begin:cmp_blk			// CMP
				    reg [7:0] result;
				    reg borrow;
				    {borrow, result} = ({1'b0, acc} - data_in_r);
				    p_nxt[`P_C] = ~borrow;
				    p_nxt[`P_N] = result[7];
				    p_nxt[`P_Z] = (result == 8'h00);
				end
				3'b111: begin:sbc_block			// SBC
				    reg borrow;
				    reg half_borrow;
				    if (p[`P_D]) begin
					half_borrow = ({1'b0,acc[3:0]}-data_in_r[3:0]-(1'b1^p[`P_C]) > 5'd9);
					borrow = ({1'b0,acc[7:4]}-data_in_r[7:4]- half_borrow > 5'd9);
					
					acc_nxt = {(acc[7:4]-data_in_r[7:4]-half_borrow-(borrow?4'd6:4'd0)),
						   (acc[3:0]-data_in_r[3:0]-(1'b1^p[`P_C])-(half_borrow?4'd6:4'd0))};
					p_nxt[`P_C] = ~borrow;
				    end
				    else begin
					{borrow, acc_nxt} = ({1'b0, acc} - data_in_r - (1'b1^p[`P_C]));
					p_nxt[`P_C] = ~borrow;
				    end
				    p_nxt[`P_V] = (acc[7] != data_in_r[7]) && (acc[7] != acc_nxt[7]);
				end
			    endcase // case (instr_type)

			    if (instr[7:5] != 3'b110) begin // not CMP instruction
				p_nxt[`P_N] = acc_nxt[7];
				p_nxt[`P_Z] = (acc_nxt == 8'h00);
			    end

			    instr_nxt = data_in;
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_DECODE;
			end // INSTR_TYPE_ALU

			INSTR_TYPE_BRANCH: begin         // Conditional branches
			    if (do_branch_func(instr,p)) begin
				pc_nxt = addr;
				cpu_sm_nxt = CPU_SM_STALL;
			    end
			    else begin
				instr_nxt = data_in;
				pc_nxt = pc_inc;
				cpu_sm_nxt = CPU_SM_DECODE;
			    end
			end
			
			INSTR_TYPE_SHIFT: begin			    // RMW Shift instructions
			    p_nxt[`P_C] = instr[6] ? data_in_r[0] : data_in_r[7];
			    p_nxt[`P_Z] = (data_out == 8'h00);
			    p_nxt[`P_N] = data_out[7];
			    cpu_sm_nxt = CPU_SM_STORE;
			end
			
			INSTR_TYPE_LDXY: begin     					// LDX/LDY
			    if (instr[1])
				x_nxt = data_in_r;
			    else
				y_nxt = data_in_r;
			    p_nxt[`P_N] = data_in_r[7];
			    p_nxt[`P_Z] = (data_in_r == 8'h00);

			    instr_nxt = data_in;
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_DECODE;
			end
			
			INSTR_TYPE_CMPXY: begin          				// CPX/CPY
			    if (instr[5]) begin
				p_nxt[`P_N] = (((x - data_in_r) & 8'h80) != 8'h00);
				p_nxt[`P_C] = (x >= data_in_r);
				p_nxt[`P_Z] = (x == data_in_r);
			    end
			    else begin
				p_nxt[`P_N] = (((y - data_in_r) & 8'h80) != 8'h00);
				p_nxt[`P_C] = (y >= data_in_r);
				p_nxt[`P_Z] = (y == data_in_r);
			    end

			    instr_nxt = data_in;
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_DECODE;
			end
			
			INSTR_TYPE_INCDEC: begin   		// INC/DEC (read-modify-write)
			    p_nxt[`P_N] = data_out[7];
			    p_nxt[`P_Z] = (data_out == 8'h00);				
			    cpu_sm_nxt = CPU_SM_STORE;
			end
			
			INSTR_TYPE_BIT: begin      		// BIT instructions
			    p_nxt[`P_N] = data_in_r[7];
			    p_nxt[`P_V] = data_in_r[6];
			    p_nxt[`P_Z] = ((acc & data_in_r) == 8'h00);

			    instr_nxt = data_in;
			    pc_nxt = pc_inc;
			    cpu_sm_nxt = CPU_SM_DECODE;
			end
			
			default: begin
`ifdef simulation
			    $display("[%t] INSTRUCTION DECODE PROBLEM instr=%h", $time, instr);
			    $stop;
`endif
			end
		    endcase
		end // if (rdy)
	    end // case: CPU_SM_EXECUTE
	    
            // Read cycle for PLA/PLP data_in_rations
	    CPU_SM_PULL: begin
		if (rdy) begin
		    if (instr[6]) begin
			acc_nxt = data_in_r;
			p_nxt[`P_N] = data_in_r[7];
			p_nxt[`P_Z] = (data_in_r == 8'h00);
		    end
		    else begin
			p_nxt = data_in_r;
			p_nxt[`P_B] = 0;
			p_nxt[`P_1] = 1;
		    end

		    instr_nxt = data_in;
		    pc_nxt = pc_inc;
		    cpu_sm_nxt = CPU_SM_DECODE;
		end
	    end
		
	    // Fetched second byte of JSR, begin push of high return address
	    CPU_SM_JSR1: begin
		opaddr_h_nxt = data_in_r;
		
		addr = {8'h01, sp};
		data_out = pc[15:8];
		we = 1;
		
		if (rdy) begin
		    sp_nxt = sp_dec;
		    cpu_sm_nxt = CPU_SM_JSR2;
		end
	    end
	    
            // Store cycle for JSR low address push		
	    CPU_SM_JSR2: begin
		
		addr = {8'h01, sp};
		data_out = pc[7:0];
		we = 1;
		
		if (rdy) begin
		    pc_nxt = {opaddr_h, opaddr_l};
		    sp_nxt = sp_dec;
		    cpu_sm_nxt = CPU_SM_STALL;
		end
	    end
		
            // Read cycle for P in RTI instruction
	    CPU_SM_RTI: begin
		addr = {8'h01, sp_inc};
		if (rdy) begin
		    sp_nxt = sp_inc;
		    p_nxt = data_in_r;
		    p_nxt[`P_B] = 0;
		    cpu_sm_nxt = CPU_SM_RTS1;
		end
	    end

            // Read cycle for low-byte of return address in RTS/RTI		
	    CPU_SM_RTS1: begin
		opaddr_l_nxt = data_in_r;
		addr = {8'h01, sp_inc};
		
		if (rdy) begin
		    sp_nxt = sp_inc;
		    cpu_sm_nxt = CPU_SM_RTS2;
		end
	    end
	    
            // Read cycle for high-byte of return address in RTS/RTI.		
	    CPU_SM_RTS2:
		if (rdy) begin
		    pc_nxt = {data_in_r, opaddr_l} + instr[5];	// add 1 if RTS (vs. RTI)
		    cpu_sm_nxt = CPU_SM_STALL;
		end
	    
            // Store cycle for high-byte of PC during interrupt/BRK.		
	    CPU_SM_INTR1: begin
		addr = {8'h01, sp};
		data_out = pc[15:8];
		we = 1;
		
		if (rdy) begin
		    sp_nxt = sp_dec;
		    cpu_sm_nxt = CPU_SM_INTR2;
		end
	    end

 	    // Store cycle for low-byte of PC during interrupt/BRK.
	    CPU_SM_INTR2: begin
		addr = {8'h01, sp};
		data_out = pc[7:0];
		we = 1;
		
		if (rdy) begin
		    sp_nxt = sp_dec;
		    cpu_sm_nxt = CPU_SM_INTR3;
		end
	    end
	    
            // Store cycle for P during interrupt/BRK.
	    CPU_SM_INTR3: begin
		addr = {8'h01, sp};
		data_out = p;
		we = 1;
		
		if (rdy) begin
		    pc_nxt = (do_nmi ? `NMI_VEC : `IRQ_VEC);
		    sp_nxt = sp_dec;
		    cpu_sm_nxt = CPU_SM_INTR4;
		end
	    end

	    CPU_SM_INTR4: begin
		p_nxt[`P_I] = 1;
		p_nxt[`P_B] = 0;
		p_nxt[`P_D] = 0;  // like a 65C02!
		
		if (rdy) begin
		    pc_nxt = pc_inc;
		    clr_do_nmi = do_nmi;
		    cpu_sm_nxt = CPU_SM_VECTOR1;
		end
	    end
		
	    default: begin
		cpu_sm_nxt = 5'bxxxxx;
`ifdef simulation
		if ($time > 0.0) begin
		    $display("[%t] cpu sm problem! cpu_sm = %h", $time, cpu_sm);
		    $stop;
		end
`endif
	    end
		
        endcase // cpu_sm
    end
    
endmodule // cpu6502
