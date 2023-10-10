`timescale 1ns / 1ps
//
// Copyright (c) 2022-2023 Thomas Skibo. <ThomasSkibo@yahoo.com>
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

module cpu6502(
               output reg [15:0] A,
               output reg        RW,
               output reg [7:0]  DO,
               input [7:0]       DI,
               input             RDY,
               output reg        SYNC,
               input             IRQ_,
               input             NMI_,
               input             RES_,
               input             PHI
               );

    // convenience signals
    wire        clk = PHI;
    wire        reset = !RES_;

    localparam [15:0]
        IRQ_VEC =       16'hfffe,
        RESET_VEC =     16'hfffc,
        NMI_VEC =       16'hfffa;

    /////////////// CPU Regs ////////////////
    //
    reg [15:0]          pc;             // program counter
    reg [7:0]           acc;            // accumulator
    reg [7:0]           x;              // x index reg
    reg [7:0]           y;              // y indexreg
    reg [7:0]           sp;             // stack pointer
    reg [7:0]           p;              // processor status

    localparam          // processor status bits
        P_N =  7,
        P_V =  6,
        P_1 =  5,       // always one.
        P_B =  4,
        P_D =  3,
        P_I =  2,
        P_Z =  1,
        P_C =  0;

    reg [7:0]           instr;          // current instruction
    reg [7:0]           operand;
    reg [7:0]           opaddr_l;
    reg [7:0]           opaddr_h;
    reg                 nmi_r;
    reg                 irq_r;

    // register these inputs
    always @(posedge clk)
        if (reset) begin
            irq_r <=    0;
            nmi_r <=    0;
        end
        else begin
            irq_r <=    IRQ_;
            nmi_r <=    NMI_;
        end

    /////////////////
    // NMI Logic
    /////////////////
    reg                 nmi_r_1;        // nmi_r in previous cycle?
    reg                 do_nmi;         // set by nmi transition,
                                        //  cleared by state machine
    reg                 clr_do_nmi;     // from cpu state machine
    always @(posedge clk)
        if (reset)
            nmi_r_1 <= 0;
        else
            nmi_r_1 <= nmi_r;
    always @(posedge clk)
        if (reset || clr_do_nmi)
            do_nmi <= 0;
        else if (!nmi_r && nmi_r_1)
            do_nmi <= 1;

    // Modify Z and N flags based upon an operation result.  Used by many
    // instructions.  Returns modified processor status register.
    function [7:0] func_nzflags(input [7:0] p_old,
                                input [7:0] value);
        begin
            func_nzflags = p_old;
            func_nzflags[P_Z] = (value == 8'h00);
            func_nzflags[P_N] = value[7];
        end
    endfunction

    // Perform compare operation.  Used by CMP, CPX, CPY.  Returns modified
    // processor status register.
    function [7:0] func_compare(input [7:0] p_old,
                                input [7:0] operand1,
                                input [7:0] operand2);
        begin:cmp
            reg [7:0] result;
            reg       borrow;
            reg [7:0] p_new;

            p_new = p_old;

            {borrow, result} = {1'b0, operand1} - operand2;
            p_new[P_C] = !borrow;
            p_new[P_N] = result[7];
            p_new[P_Z] = (result == 8'h00);

            func_compare = p_new;
        end
    endfunction // func_compare

    // Perform ADC instruction.  Returns modified processor status register
    // and result concatenated as {p, result}.
    function [15:0] func_adc(input [7:0] p_old,
                             input [7:0] operand1,
                             input [7:0] operand2);
        begin:adc
            reg [7:0] result;
            reg       carry;
            reg [7:0] p_new;

            p_new = p_old;

            if (p_old[P_D]) begin:bcd_adc
                // Decimal mode. Flags are weird.
                reg [4:0] nyb_l;
                reg [4:0] nyb_h;

                nyb_l = {1'b0, operand1[3:0]} + operand2[3:0] + p_old[P_C];
                p_new[P_Z] = nyb_l[3:0] == 4'h0;
                if (nyb_l > 5'd9)
                    nyb_l = nyb_l + 5'd6;
                nyb_h = {1'b0, operand1[7:4]} + operand2[7:4] + nyb_l[4];
                p_new[P_Z] = p_new[P_Z] && nyb_h[3:0] == 4'h0;
                p_new[P_N] = nyb_h[3];
                p_new[P_V] = operand1[7] == operand2[7] &&
                             operand1[7] != nyb_h[3];
                if (nyb_h > 5'd9)
                    nyb_h = nyb_h + 5'd6;
                result = {nyb_h[3:0], nyb_l[3:0]};
                p_new[P_C] = nyb_h[4];
            end
            else begin
                {carry, result} = {1'b0, operand1} + operand2 + p_old[P_C];
                p_new[P_C] = carry;
                p_new[P_V] = operand1[7] == operand2[7] &&
                             operand1[7] != result[7];

                p_new[P_N] = result[7];
                p_new[P_Z] = (result == 8'h00);
            end

            func_adc = {p_new, result};
        end
    endfunction // func_adc

    // Perform SBC instruction.  Returns modified processor status register
    // and result concatenated as {p, result}.
    function [15:0] func_sbc(input [7:0] p_old,
                             input [7:0] operand1,
                             input [7:0] operand2);
        begin:sbc
            reg [7:0] result;
            reg       borrow;
            reg [7:0] p_new;

            p_new = p_old;

            {borrow, result} = {1'b0, operand1} - operand2 - !p_old[P_C];

            p_new[P_C] = !borrow;
            p_new[P_V] = operand1[7] != operand2[7] &&
                         operand1[7] != result[7];
            p_new[P_N] = result[7];
            p_new[P_Z] = (result == 8'h00);

            if (p_old[P_D]) begin:bcd_sbc
                // Decimal mode.
                reg [4:0] nyb_l;
                reg [4:0] nyb_h;

                nyb_l = {1'b0, operand1[3:0]} - operand2[3:0] - !p_old[P_C];
                if (nyb_l[4])
                    nyb_l = nyb_l - 5'd6;
                nyb_h = {1'b0, operand1[7:4]} - operand2[7:4] - nyb_l[4];
                if (nyb_h[4])
                    nyb_h = nyb_h - 5'd6;

                result = {nyb_h[3:0], nyb_l[3:0]};
                p_new[P_C] = ~nyb_h[4];
            end

            func_sbc = {p_new, result};
        end
    endfunction // func_sbc

    // Perform calculations of group 1 instructions.  op is bits 7:5 of
    // instruction.  Returns modified processor status register and result
    // concatenated as {p, result}.
    function [15:0] func_alu1(input [7:0] p_old,
                              input [7:0] operand1,
                              input [7:0] operand2,
                              input [2:0] op);
        begin:alu1
            reg [7:0] result;
            reg [7:0] p_new;

            p_new = p_old;

            case (op)
                3'b000: begin	// ORA
                    result = operand1 | operand2;
                    p_new = func_nzflags(p_old, result);
                end
                3'b001: begin	// AND
                    result = operand1 & operand2;
                    p_new = func_nzflags(p_old, result);
                end
                3'b010: begin	// EOR
                    result = operand1 ^ operand2;
                    p_new = func_nzflags(p_old, result);
                end
                3'b011:		// ADC
                    {p_new, result} = func_adc(p_old, operand1, operand2);
                3'b100:		// STA
                    result = operand1;
                3'b101: begin	// LDA
                    result = operand2;
                    p_new = func_nzflags(p_old, result);
                end
                3'b110: begin	// CMP
                    result = operand1;
                    p_new = func_compare(p_old, operand1, operand2);
                end
                3'b111:		// SBC
                    {p_new, result} = func_sbc(p_old, operand1, operand2);
            endcase

            func_alu1 = {p_new, result};
        end
    endfunction // func_alu1


    wire [15:0] pc_inc = pc + 1'b1;
    wire [7:0]  sp_inc = sp + 1'b1;
    wire [7:0]  sp_dec = sp - 1'b1;

    /////////////////////////////////////////////////////
    // Main CPU State machine
    /////////////////////////////////////////////////////
    reg [5:0]      cpu_sm;

    localparam [5:0]
        CPU_SM_RESET =          0,
        CPU_SM_VECTOR1 =        1,
        CPU_SM_FETCH =		2,
        CPU_SM_DECODE =         3,
        CPU_SM_BRANCH =         4,
        CPU_SM_BRANCH2 =	5,
        CPU_SM_FETCH_OPAH =	6,
        CPU_SM_FETCH_INDL =	7,
        CPU_SM_FETCH_INDLX =	8,
        CPU_SM_FETCH_INDH =	9,
        CPU_SM_FETCH_FIXH =	10,
        CPU_SM_FETCH_ZPX =	11,
        CPU_SM_DELAY =		12,
        CPU_SM_FETCH_OP =	13,
        CPU_SM_STORE =		14,
        CPU_SM_RMW =		15,
        CPU_SM_INTR1 =          20,
        CPU_SM_INTR2 =          21,
        CPU_SM_INTR3 =          22,
        CPU_SM_INTR4 =          23,
        CPU_SM_INTR5 =		24,
        CPU_SM_INTR6 =		25,
        CPU_SM_JMP =		26,
        CPU_SM_JSR1 =		27,
        CPU_SM_JSR2 =		28,
        CPU_SM_JSR3 =		29,
        CPU_SM_JMPI1 =		32,
        CPU_SM_JMPI2 =		33,
        CPU_SM_JMPI3 =		34,
        CPU_SM_RTSI1 =		35,
        CPU_SM_RTI2 =		36,
        CPU_SM_RTSI3 =		37,
        CPU_SM_RTSI4 =		38,
        CPU_SM_RTS5 =		39,
        CPU_SM_PUSH =		40,
        CPU_SM_PULL1 =		41,
        CPU_SM_PULL2 =		42;

    // combinatorial outputs of always @(*) block below.
    reg [5:0]      cpu_sm_nxt;
    reg [15:0]     pc_nxt;
    reg [7:0]      sp_nxt;
    reg [7:0]      p_nxt;
    reg [7:0]      acc_nxt;
    reg [7:0]      x_nxt;
    reg [7:0]      y_nxt;
    reg [7:0]      instr_nxt;
    reg [7:0]      operand_nxt;
    reg [7:0]      opaddr_l_nxt;
    reg [7:0]      opaddr_h_nxt;

    // CPU SM register
    always @(posedge clk)
        if (reset)
            cpu_sm <=   CPU_SM_RESET;
        else if (RDY)
            cpu_sm <=   cpu_sm_nxt;

    // Implement Registers
    always @(posedge clk)
        if (RDY) begin
            pc <=           pc_nxt;
            sp <=           sp_nxt;
            p <=            p_nxt;
            acc <=          acc_nxt;
            x <=            x_nxt;
            y <=            y_nxt;

            instr <=        instr_nxt;
            operand <=	    operand_nxt;
            opaddr_l <=     opaddr_l_nxt;
            opaddr_h <=     opaddr_h_nxt;
        end

    // Main state machine.
    always @(*) begin
        // Defaults
        cpu_sm_nxt =    cpu_sm;
        sp_nxt =        sp;
        p_nxt =         p;
        pc_nxt =        pc;
        acc_nxt =       acc;
        x_nxt =         x;
        y_nxt =         y;
        instr_nxt =     instr;
        operand_nxt =	operand;
        opaddr_l_nxt =  opaddr_l;
        opaddr_h_nxt =  opaddr_h;

        A =             pc;
        SYNC =          0;
        DO =            8'hXX;
        RW =            1;

        clr_do_nmi =    0;

        case (cpu_sm)
            // Reset state.  Get ready to read RESET vector.
            CPU_SM_RESET: begin
                A = RESET_VEC;
                sp_nxt = 8'hff;
                p_nxt = 8'h34;
                pc_nxt = {8'hXX, DI};
                if (!reset)
                    cpu_sm_nxt = CPU_SM_VECTOR1;
            end

            // Fetch low byte of RESET vector.
            CPU_SM_VECTOR1: begin
                A = RESET_VEC + 1;
                pc_nxt = {DI, pc[7:0]};
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            // Fetch instruction
            CPU_SM_FETCH: begin
                instr_nxt = DI;
                if (do_nmi || (!irq_r && !p[P_I]))	// IRQ, NMI?
                    cpu_sm_nxt = CPU_SM_INTR1;
                else begin
                    SYNC = 1;
                    pc_nxt = pc_inc;
                    cpu_sm_nxt = CPU_SM_DECODE;
                end
            end

            // Decode opcode and execute many single byte and immediate
            // instructions.
            CPU_SM_DECODE: begin
                opaddr_l_nxt = DI;
                operand_nxt = DI;
                opaddr_h_nxt = 8'h00;

                // This is default (along with no pc inc) for many
                // one byte instructions executed here in this stage.
                cpu_sm_nxt = CPU_SM_FETCH;

                casez (instr)
                    8'b???1_0000: begin:br	// Branches
                        reg do_branch;

                        pc_nxt = pc_inc;

                        case (instr[7:6])
                            2'b00:
                                do_branch = (p[P_N] == instr[5]);
                            2'b01:
                                do_branch = (p[P_V] == instr[5]);
                            2'b10:
                                do_branch = (p[P_C] == instr[5]);
                            2'b11:
                                do_branch = (p[P_Z] == instr[5]);
                        endcase
                        if (do_branch)
                            cpu_sm_nxt = CPU_SM_BRANCH;
                        else
                            cpu_sm_nxt = CPU_SM_FETCH;
                    end

                    8'b???0_1001: begin	// Group 1 immediate
                        pc_nxt = pc_inc;
                        {p_nxt, acc_nxt} = func_alu1(p, acc, DI, instr[7:5]);
                        cpu_sm_nxt = CPU_SM_FETCH;
                    end

                    8'b????_??01: begin	// Group 1 other than imm
                        pc_nxt = pc_inc;
                        case (instr[4:2])
                            3'b000, 3'b100:	// INDIRECT
                                cpu_sm_nxt = CPU_SM_FETCH_INDL;
                            3'b001:		// ZP
                                if (instr[7:5] == 3'b100)
                                    // STA ZP
                                    cpu_sm_nxt = CPU_SM_STORE;
                                else
                                    cpu_sm_nxt = CPU_SM_FETCH_OP;
                            3'b101:		// ZP,X
                                cpu_sm_nxt = CPU_SM_FETCH_ZPX;
                            3'b011, 3'b110, 3'b111:
                                // ABS ABS,Y ABS,X
                                cpu_sm_nxt = CPU_SM_FETCH_OPAH;
                            default:
                                ;
                        endcase
                    end

                    8'b1010_0010: begin	// LDX imm (group 2 oddball)
                        pc_nxt = pc_inc;
                        x_nxt = DI;
                        p_nxt = func_nzflags(p, x_nxt);
                        cpu_sm_nxt = CPU_SM_FETCH;
                    end

                    8'b0??0_1010: begin	// Acc shift instrs, Group 2
                        case (instr[6:5])
                            2'b00: // ASL A
                                {p_nxt[P_C], acc_nxt} = {acc, 1'b0};
                            2'b01: // ROL A
                                {p_nxt[P_C], acc_nxt} = {acc, p[P_C]};
                            2'b10: // LSR A
                                {acc_nxt, p_nxt[P_C]} = {1'b0, acc};
                            2'b11: // ROR A
                                {acc_nxt, p_nxt[P_C]} = {p[P_C], acc};
                        endcase
                        p_nxt = func_nzflags(p_nxt, acc_nxt);
                    end

                    8'b1000_1010: begin	// TXA
                        acc_nxt = x;
                        p_nxt = func_nzflags(p, acc_nxt);
                    end

                    8'b1001_1010:       // TXS
                        sp_nxt = x;

                    8'b1010_1010: begin	// TAX
                        x_nxt = acc;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b1011_1010: begin	// TSX
                        x_nxt = sp;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b1100_1010: begin	// DEX
                        x_nxt = x - 1;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b1110_1010:       // NOP
                        ;

                    8'b????_??10: begin	// All other group 2
                        pc_nxt = pc_inc;
                        case (instr[4:2])
                            3'b001:	// ZP
                                if (instr[7:5] == 3'b100 /* STX */)
                                    cpu_sm_nxt = CPU_SM_STORE;
                                else
                                    cpu_sm_nxt = CPU_SM_FETCH_OP;
                            3'b101: // ZP,X ZP,Y
                                cpu_sm_nxt = CPU_SM_FETCH_ZPX;
                            3'b011, 3'b111:
                                // ABS ABS,X ABS,Y
                                cpu_sm_nxt = CPU_SM_FETCH_OPAH;
                            default: begin
                                // synthesis translate_off
                                if (!reset) begin
                                    $display("[%t] bad decode grp2?: %h",
                                             $time, instr);
                                    $stop;
                                end
                                // synthesis translate_on
                            end
                        endcase
                    end

                    8'b0000_0000: begin	// BRK
                        pc_nxt = pc_inc;
                        cpu_sm_nxt = CPU_SM_INTR2;
                    end

                    8'b1001_1000: begin	// TYA
                        acc_nxt = y;
                        p_nxt = func_nzflags(p, acc_nxt);
                    end

                    8'b???1_1000: begin	// Set or reset flags.
                        case (instr[7:6])
                            2'b00:
                                p_nxt[P_C] = instr[5];
                            2'b01:
                                p_nxt[P_I] = instr[5];
                            2'b10:
                                p_nxt[P_V] = 0;
                            2'b11:
                                p_nxt[P_D] = instr[5];
                        endcase
                    end

                    8'b1000_1000: begin	// DEY
                        y_nxt = y - 1;
                        p_nxt = func_nzflags(p, y_nxt);
                    end

                    8'b1010_1000: begin	// TAY
                        y_nxt = acc;
                        p_nxt = func_nzflags(p, y_nxt);
                    end

                    8'b1100_1000: begin	// INY
                        y_nxt = y + 1;
                        p_nxt = func_nzflags(p, y_nxt);
                    end

                    8'b1110_1000: begin	// INX
                        x_nxt = x + 1;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b0100_1100: begin	// JMP
                        pc_nxt = pc_inc;
                        cpu_sm_nxt = CPU_SM_JMP;
                    end

                    8'b0010_0000: begin	// JSR
                        pc_nxt = pc_inc;
                        cpu_sm_nxt = CPU_SM_JSR1;
                    end

                    8'b0110_1100: begin	// JMP (ind)
                        cpu_sm_nxt = CPU_SM_JMPI1;
                        pc_nxt = pc_inc;
                    end

                    8'b01?0_0000:		// RTS / RTI
                        cpu_sm_nxt = CPU_SM_RTSI1;

                    8'b0?00_1000:		// PHP / PHA
                        cpu_sm_nxt = CPU_SM_PUSH;

                    8'b0?10_1000:		// PLP / PLA
                        cpu_sm_nxt = CPU_SM_PULL1;

                    8'b1010_0000: begin	// LDY # (group 3 imm)
                        pc_nxt = pc_inc;
                        y_nxt = DI;
                        p_nxt = func_nzflags(p, y_nxt);
                        cpu_sm_nxt = CPU_SM_FETCH;
                    end

                    8'b1100_0000: begin	// CPY # (group 3 imm)
                        pc_nxt = pc_inc;
                        p_nxt = func_compare(p, y, DI);
                        cpu_sm_nxt = CPU_SM_FETCH;

                    end

                    8'b1110_0000: begin	// CPX # (group 3 imm)
                        pc_nxt = pc_inc;
                        p_nxt = func_compare(p, x, DI);
                        cpu_sm_nxt = CPU_SM_FETCH;
                    end

                    8'b????_??00: begin	// All other group 3
                        pc_nxt = pc_inc;
                        case (instr[4:2])
                            3'b001:	// ZP
                                if (instr[7:5] == 3'b100 /* STY */)
                                    cpu_sm_nxt = CPU_SM_STORE;
                                else
                                    cpu_sm_nxt = CPU_SM_FETCH_OP;
                            3'b101: // ZP,X ZP,Y
                                cpu_sm_nxt = CPU_SM_FETCH_ZPX;
                            3'b011, 3'b111:
                                // ABS ABS,X ABS,Y
                                cpu_sm_nxt = CPU_SM_FETCH_OPAH;
                            default: begin
                                // synthesis translate_off
                                if (!reset) begin
                                    $display("[%t] bad decode grp3?: %h",
                                             $time, instr);
                                    $stop;
                                end
                                // synthesis translate_on
                            end
                        endcase
                    end

                    default: begin
                        // synthesis translate_off
                        if (!reset) begin
                            $display("[%t] bad instr decode?: %h", $time,
                                     instr);
                            $stop;
                        end
                        // synthesis translate_on
                    end
                endcase // case (instr)
            end // CPU_SM_DECODE

            // Take a branch
            CPU_SM_BRANCH: begin
                {opaddr_h_nxt, pc_nxt[7:0]} = pc + {{8{operand[7]}}, operand};
                if (opaddr_h_nxt[0] == pc[8])
                    cpu_sm_nxt = CPU_SM_FETCH;
                else
                    cpu_sm_nxt = CPU_SM_BRANCH2;
            end

            // Take a branch that crosses page boundary
            CPU_SM_BRANCH2: begin
                pc_nxt[15:8] = opaddr_h;
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            // Indexed zero page addressing
            CPU_SM_FETCH_ZPX: begin
                A = {opaddr_h, opaddr_l};
                if (instr[1:0] == 2'b10 && instr[7:6] == 2'b10)
                    // LDX, STX
                    opaddr_l_nxt = opaddr_l + y;
                else
                    opaddr_l_nxt = opaddr_l + x;
                if (instr[7:5] == 3'b100) // ST[AXY]
                    cpu_sm_nxt = CPU_SM_STORE;
                else
                    cpu_sm_nxt = CPU_SM_FETCH_OP;
            end

            // Absolute indexed addressing
            CPU_SM_FETCH_OPAH: begin:opah
                reg pagecross;
                opaddr_h_nxt = DI;
                pc_nxt = pc_inc;
                pagecross = 0;

                // do indexing for absolute and look out for page crosses
                casez (instr)
                    8'b???1_1001, 8'b10?1_1110: begin
                        // ABS,Y
                        opaddr_l_nxt = opaddr_l + y;
                        if ({1'b0, opaddr_l} + y >= 9'h100)
                            pagecross = 1;
                    end
                    8'b???1_1101, 8'b???1_1110, 8'b???1_1100: begin
                        // ABS,X
                        opaddr_l_nxt = opaddr_l + x;
                        if ({1'b0, opaddr_l} + x >= 9'h100)
                            pagecross = 1;
                    end
                    default:
                        ;
                endcase

                if (pagecross)
                    cpu_sm_nxt = CPU_SM_FETCH_FIXH;
                else
                    // Figure out if a dead cycle is needed here.
                    casez (instr)
                        8'b1000_11??: /* ST[AXY] abs */
                            cpu_sm_nxt = CPU_SM_STORE;
                        8'b???0_11??: /* all non-store abs */
                            cpu_sm_nxt = CPU_SM_FETCH_OP;
                        8'b1011_11?0: /* LDX LDY abs,[XY] */
                            cpu_sm_nxt = CPU_SM_FETCH_OP;
                        8'b1001_1?01: /* STA abs,[XY] */
                            cpu_sm_nxt = CPU_SM_DELAY;
                        8'b???1_1?01: /* all non-store abs,[XY] in group 1 */
                            cpu_sm_nxt = CPU_SM_FETCH_OP;
                        default:
                            cpu_sm_nxt = CPU_SM_DELAY;
                    endcase
            end // CPU_SM_FETCH_OPAH

            // Indirect addressing, fetch addr low
            CPU_SM_FETCH_INDL: begin
                A = {8'h00, operand};
                opaddr_l_nxt = DI;
                if (instr[4]) begin
                    // (ZP),Y
                    operand_nxt = operand + 1;
                    cpu_sm_nxt = CPU_SM_FETCH_INDH;
                end
                else begin
                    // (ZP,X)
                    operand_nxt = operand + x;
                    cpu_sm_nxt = CPU_SM_FETCH_INDLX;
                end
            end

            // Indexed Indirect addressing (ZP,X), fetch addr low
            CPU_SM_FETCH_INDLX: begin
                A = {8'h00, operand};
                opaddr_l_nxt = DI;
                operand_nxt = operand + 1;
                cpu_sm_nxt = CPU_SM_FETCH_INDH;
            end

            // Indirect addressing, fetch addr high
            CPU_SM_FETCH_INDH: begin
                A = {8'h00, operand};
                opaddr_h_nxt = DI;
                if (instr[4]) begin
                    opaddr_l_nxt = opaddr_l + y;
                    if ({1'b0, opaddr_l} + y >= 9'h100)
                        cpu_sm_nxt = CPU_SM_FETCH_FIXH;
                    else if (instr[7:5] == 3'b100 /* STA */)
                        cpu_sm_nxt = CPU_SM_DELAY;
                    else
                        cpu_sm_nxt = CPU_SM_FETCH_OP;
                end
                else begin
                    if (instr[7:5] == 3'b100 /* STA */)
                        cpu_sm_nxt = CPU_SM_STORE;
                    else
                        cpu_sm_nxt = CPU_SM_FETCH_OP;
                end
            end

            // Indexed addressing, ABS,[XY] or (ZP),Y when crossing page
            // boundary.
            CPU_SM_FETCH_FIXH: begin
                A = {opaddr_h, opaddr_l};
                opaddr_h_nxt = opaddr_h + 1;
                if (instr[7:5] == 3'b100 /* ST[AXY] */)
                    cpu_sm_nxt = CPU_SM_STORE;
                else
                    cpu_sm_nxt = CPU_SM_FETCH_OP;
            end

            // Indexed stores and RMW instructions include this delay even if
            // they don't cross page boundaries.
            CPU_SM_DELAY: begin
                A = {opaddr_h, opaddr_l};
                if (instr[7:5] == 3'b100 /* ST[AXY] */)
                    cpu_sm_nxt = CPU_SM_STORE;
                else
                    cpu_sm_nxt = CPU_SM_FETCH_OP;
            end

            CPU_SM_FETCH_OP: begin
                A = {opaddr_h, opaddr_l};
                operand_nxt = DI;
                cpu_sm_nxt = CPU_SM_FETCH;

                casez (instr)
                    8'b????_??01:	// Group 1 instructions
                        {p_nxt, acc_nxt} = func_alu1(p, acc, DI, instr[7:5]);

                    8'b101?_??10: begin	// LDX (group 2)
                        x_nxt = DI;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b101?_??00: begin	// LDY (group 3)
                        y_nxt = DI;
                        p_nxt = func_nzflags(p, y_nxt);
                    end

                    8'b110?_??00:	// CPY (group 3)
                        p_nxt = func_compare(p, y, DI);

                    8'b111?_??00:	// CPX (group 3)
                        p_nxt = func_compare(p, x, DI);

                    8'b001?_??00: begin	// BIT (group 3)
                        p_nxt[P_N] = DI[7];
                        p_nxt[P_V] = DI[6];
                        p_nxt[P_Z] = (DI & acc) == 8'h00;
                    end

                    8'b????_??10:	// group 2 RMW instructions
                        cpu_sm_nxt = CPU_SM_RMW;

                    default:
                        ;
                endcase
            end

            // Perform read-modify-write instructions
            CPU_SM_RMW: begin
                A = {opaddr_h, opaddr_l};
                RW = 0;
                DO = operand;
                cpu_sm_nxt = CPU_SM_STORE;

                casez (instr[7:5])
                    3'b000: begin // ASL
                        operand_nxt = {operand[6:0], 1'b0};
                        p_nxt = func_nzflags(p, operand_nxt);
                        p_nxt[P_C] = operand[7];
                    end
                    3'b001: begin // ROL
                        operand_nxt = {operand[6:0], p[P_C]};
                        p_nxt = func_nzflags(p, operand_nxt);
                        p_nxt[P_C] = operand[7];
                    end
                    3'b010: begin // LSR
                        operand_nxt = {1'b0, operand[7:1]};
                        p_nxt = func_nzflags(p, operand_nxt);
                        p_nxt[P_C] = operand[0];
                    end
                    3'b011: begin // ROR
                        operand_nxt = {p[P_C], operand[7:1]};
                        p_nxt = func_nzflags(p, operand_nxt);
                        p_nxt[P_C] = operand[0];
                    end
                    3'b110: begin // DEC
                        operand_nxt = operand - 1;
                        p_nxt = func_nzflags(p, operand_nxt);
                    end
                    3'b111: begin // INC
                        operand_nxt = operand + 1;
                        p_nxt = func_nzflags(p, operand_nxt);
                    end

                    default: begin
                        // synthesis translate_off
                        if (!reset) begin
                            $display("[%t] Bad decode in RMW: %h",
                                     $time, instr);
                            $stop;
                        end
                        // synthesis translate_on
                    end
                endcase
            end

            // Store stage of store or read-modify-write instructions
            CPU_SM_STORE: begin
                A = {opaddr_h, opaddr_l};
                RW = 0;
                casez (instr)
                    8'b????_??01:
                        DO = acc;
                    8'b100?_??10:
                        DO = x;
                    8'b100?_??00:
                        DO = y;
                    default:
                        DO = operand;
                endcase

                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_INTR1: begin
                p_nxt[P_B] = 0;
                cpu_sm_nxt = CPU_SM_INTR2;
            end

            CPU_SM_INTR2: begin
                A = {8'h01, sp};
                sp_nxt = sp_dec;
                DO = pc[15:8];
                RW = 0;
                cpu_sm_nxt = CPU_SM_INTR3;
            end

            CPU_SM_INTR3: begin
                A = {8'h01, sp};
                sp_nxt = sp_dec;
                DO = pc[7:0];
                RW = 0;
                cpu_sm_nxt = CPU_SM_INTR4;
            end

            CPU_SM_INTR4: begin
                A = {8'h01, sp};
                sp_nxt = sp_dec;
                DO = p;
                RW = 0;
                p_nxt[P_B] = 1;
                p_nxt[P_I] = 1;

                // Decide here atomically are we doing an NMI?
                if (do_nmi) begin
                    {opaddr_h_nxt, opaddr_l_nxt} = NMI_VEC;
                    clr_do_nmi = 1;
                end
                else
                    {opaddr_h_nxt, opaddr_l_nxt} = IRQ_VEC;

                cpu_sm_nxt = CPU_SM_INTR5;
            end

            CPU_SM_INTR5: begin
                A = {opaddr_h, opaddr_l};
                opaddr_l_nxt = opaddr_l + 1;
                pc_nxt = {8'hXX, DI};
                cpu_sm_nxt = CPU_SM_INTR6;
            end

            CPU_SM_INTR6: begin
                A = {opaddr_h, opaddr_l};
                pc_nxt = {DI, pc[7:0]};
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_JSR1: begin
                A = {8'h01, sp};
                cpu_sm_nxt = CPU_SM_JSR2;
            end

            CPU_SM_JSR2: begin
                A = {8'h01, sp};
                DO = pc[15:8];
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_JSR3;
            end

            CPU_SM_JSR3: begin
                A = {8'h01, sp};
                DO = pc[7:0];
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_JMP;
            end

            CPU_SM_JMP: begin
                pc_nxt = {DI, opaddr_l};
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_JMPI1: begin
                opaddr_h_nxt = DI;
                cpu_sm_nxt = CPU_SM_JMPI2;
            end

            CPU_SM_JMPI2: begin
                A = {opaddr_h, opaddr_l};
                opaddr_l_nxt = opaddr_l + 1;
                pc_nxt = {8'hXX, DI};
                cpu_sm_nxt = CPU_SM_JMPI3;
            end

            CPU_SM_JMPI3: begin
                A = {opaddr_h, opaddr_l};
                pc_nxt = {DI, pc[7:0]};
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_RTSI1: begin
                A = {8'h01, sp};
                sp_nxt = sp_inc;
                if (instr[5])
                    cpu_sm_nxt = CPU_SM_RTSI3;
                else
                    cpu_sm_nxt = CPU_SM_RTI2;
            end

            CPU_SM_RTI2: begin
                A = {8'h01, sp};
                sp_nxt = sp_inc;
                p_nxt = DI;
                p_nxt[P_B] = 1;
                p_nxt[P_1] = 1;
                cpu_sm_nxt = CPU_SM_RTSI3;
            end

            CPU_SM_RTSI3: begin
                A = {8'h01, sp};
                sp_nxt = sp_inc;
                pc_nxt = {8'hXX, DI};
                cpu_sm_nxt = CPU_SM_RTSI4;
            end

            CPU_SM_RTSI4: begin
                A = {8'h01, sp};
                pc_nxt = {DI, pc[7:0]};
                if (instr[5])
                    cpu_sm_nxt = CPU_SM_RTS5;
                else
                    cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_RTS5: begin
                pc_nxt = pc_inc;
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_PUSH: begin
                A = {8'h01, sp};
                RW = 0;
                DO = instr[6] ? acc : p;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            CPU_SM_PULL1: begin
                A = {8'h01, sp};
                sp_nxt = sp_inc;
                cpu_sm_nxt = CPU_SM_PULL2;
            end

            CPU_SM_PULL2: begin
                A = {8'h01, sp};
                if (instr[6]) begin
                    acc_nxt = DI;
                    p_nxt = func_nzflags(p, acc_nxt);
                end
                else begin
                    p_nxt = DI;
                    p_nxt[P_B] = 1;
                    p_nxt[P_1] = 1;
                end
                cpu_sm_nxt = CPU_SM_FETCH;
            end

            default: begin
                // synthesis translate_off
                if (!reset) begin
                    $display("[%t] Bad CPU SM State: %h", $time, cpu_sm);
                    $stop;
                end
                // synthesis translate_on
            end
        endcase // case (cpu_sm)
    end // always @(*)

endmodule
