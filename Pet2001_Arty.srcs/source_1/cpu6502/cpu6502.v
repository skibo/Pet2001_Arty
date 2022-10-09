`timescale 1ns / 1ps
//
// Copyright (c) 2022 Thomas Skibo.
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
    reg [7:0]           data_in_r;
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

    // Address modes
    localparam [3:0]
        ADDR_MODE_IMPLIED =     0,
        ADDR_MODE_IMMEDIATE =   1,
        ADDR_MODE_ZEROPG =      2,
        ADDR_MODE_ZEROPG_X =    3,
        ADDR_MODE_ZEROPG_Y =    4,
        ADDR_MODE_ABS =         5,
        ADDR_MODE_ABS_X =       6,
        ADDR_MODE_ABS_Y =       7,
        ADDR_MODE_INDIRECT_X =  10,
        ADDR_MODE_INDIRECT_Y =  11,
        ADDR_MODE_ACC =         12,
        ADDR_MODE_RELATIVE =    13;


    // Decode address mode of an instruction.
    function [3:0] addr_mode_func(input [7:0] instr);
        begin
            casez (instr)
                8'b0000_0000:   // BRK
                    addr_mode_func = ADDR_MODE_IMMEDIATE; // close enough
                8'b0010_0000:   // JSR
                    addr_mode_func = ADDR_MODE_ABS;
                8'b01?0_0000:   // RTI/RTS
                    addr_mode_func = ADDR_MODE_IMPLIED;
                8'b???1_0000:   // Branches
                    addr_mode_func = ADDR_MODE_RELATIVE;
                8'b???1_1000:   // Set/Clear instructions
                    addr_mode_func = ADDR_MODE_IMPLIED;
                8'b???0_1000:   // Other single-byte instructions
                    addr_mode_func = ADDR_MODE_IMPLIED;
                8'b1???_1010:   // TXA,TXS,TAX,TSX,DEX,NOP
                        addr_mode_func = ADDR_MODE_IMPLIED;
                8'b????_??01:   // Group one instructions
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

                8'b????_???0:   // Group two and three instructions
                    case (instr[4:2])
                        3'b000:  addr_mode_func = ADDR_MODE_IMMEDIATE;
                        3'b001:  addr_mode_func = ADDR_MODE_ZEROPG;
                        3'b010:  addr_mode_func = ADDR_MODE_ACC;
                        3'b011:  addr_mode_func = ADDR_MODE_ABS;
                        3'b101:
                            if (instr == 8'h96 || instr == 8'hb6) // STX/LDX
                                addr_mode_func = ADDR_MODE_ZEROPG_Y;
                            else
                                addr_mode_func = ADDR_MODE_ZEROPG_X;
                        3'b111:
                            if (instr == 8'hbe) // LDX
                                addr_mode_func = ADDR_MODE_ABS_Y;
                            else
                                addr_mode_func = ADDR_MODE_ABS_X;
                        default: begin
                            // synthesis translate_off
                            if (!reset) begin
                                $display("[%t] Instruction decode fail? %h",
                                         $time, instr);
                                $stop;
                            end
                            // synthesis translate_on
                        end
                    endcase // case (instr[4:2])
                default: begin
                    addr_mode_func = 4'hX;
                    // synthesis translate_off
                    if (!reset) begin
                        $display("[%t] Instruction decode fail? %h", $time,
                                 instr);
                        $stop;
                    end
                    // synthesis translate_on
                end
            endcase // case (instr)
        end
    endfunction // addr_mode_func

    wire [3:0] addr_mode = addr_mode_func(instr);

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

            {borrow, result} = ({1'b0, operand1} - operand2);
            p_new[P_C] = ~borrow;
            p_new[P_N] = result[7];
            p_new[P_Z] = (result == 8'h00);

            func_compare = p_new;
        end
    endfunction

    wire [15:0] pc_inc = pc + 1'b1;
    wire [15:0] pc_dec = pc - 1'b1;
    wire [7:0]  sp_inc = sp + 1'b1;
    wire [7:0]  sp_dec = sp - 1'b1;

    /////////////////////////////////////////////////////
    // Main CPU State machine
    /////////////////////////////////////////////////////
    reg [4:0]      cpu_sm;

    localparam [4:0]
        CPU_SM_RESET =          0,
        CPU_SM_VECTOR1 =        1,
        CPU_SM_VECTOR2 =        2,
        CPU_SM_STALL =          3,
        CPU_SM_DECODE =         4,
        CPU_SM_BRANCH =         5,
        CPU_SM_FETCH_I1 =       6,
        CPU_SM_FETCH_I2 =       7,
        CPU_SM_FETCH_IND1 =     8,
        CPU_SM_FETCH_IND2 =     9,
        CPU_SM_EXECUTE =        10,
        CPU_SM_STORE =          11,
        CPU_SM_JSR1 =           12,
        CPU_SM_JSR2 =           13,
        CPU_SM_INTR1 =          17,
        CPU_SM_INTR2 =          18,
        CPU_SM_INTR3 =          19,
        CPU_SM_INTR4 =          20,
        CPU_SM_RTI =            21,
        CPU_SM_RTSI1 =          22,
        CPU_SM_RTSI2 =          23;

    // combinatorial outputs of always @(*) block below.
    reg [4:0]      cpu_sm_nxt;
    reg [15:0]     pc_nxt;
    reg [7:0]      sp_nxt;
    reg [7:0]      p_nxt;
    reg [7:0]      acc_nxt;
    reg [7:0]      x_nxt;
    reg [7:0]      y_nxt;
    reg [7:0]      instr_nxt;
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

            data_in_r <=    DI;
            instr <=        instr_nxt;
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
                pc_nxt = RESET_VEC;
                A = RESET_VEC;
                sp_nxt = 8'hff;
                p_nxt = 8'h24;
                if (!reset) begin
                    pc_nxt = RESET_VEC + 1;
                    cpu_sm_nxt = CPU_SM_VECTOR1;
                end
            end

            // Fetched low byte of RESET, NMI, or IRQ vector.
            // Vector address is in pc.
            CPU_SM_VECTOR1: begin
                opaddr_l_nxt = data_in_r;
                pc_nxt = pc_inc;
                cpu_sm_nxt = CPU_SM_VECTOR2;
            end

            // Fetched high byte of RESET, NMI, or IRQ vector.
            CPU_SM_VECTOR2: begin
                pc_nxt = {data_in_r, opaddr_l};
                cpu_sm_nxt = CPU_SM_STALL;
            end

            // If PC has changed, we need to stall.
            CPU_SM_STALL: begin
                instr_nxt = DI;
                SYNC = 1;
                pc_nxt = pc_inc;
                cpu_sm_nxt = CPU_SM_DECODE;
            end

            // Decode opcode and execute many single byte instructions.
            CPU_SM_DECODE:
                if (do_nmi || (!irq_r && !p[P_I])) begin // IRQ, NMI?
                    pc_nxt = pc_dec;
                    cpu_sm_nxt = CPU_SM_INTR1;
                end
                else begin
                    pc_nxt = pc_inc;
                    casez (instr)
                        8'b0000_0000: begin     // BRK
                            p_nxt[P_B] = 1;
                            cpu_sm_nxt = CPU_SM_INTR1;
                        end

                        8'b0010_0000:           // JSR
                            cpu_sm_nxt = CPU_SM_FETCH_I1;

                        8'b01?0_0000: begin     // RTI/RTS
                            A = {8'h01, sp_inc};
                            sp_nxt = sp_inc;
                            if (instr[5])
                                cpu_sm_nxt = CPU_SM_RTSI1;
                            else
                                cpu_sm_nxt = CPU_SM_RTI;
                        end

                        8'b???1_0000:           // Branches
                            cpu_sm_nxt = CPU_SM_BRANCH;

                        8'b???1_1000: begin // Flag Set/Clear, TYA instrs
                            case (instr[7:6])
                                2'b00: p_nxt[P_C] = instr[5];   // CLC / SEC
                                2'b01: p_nxt[P_I] = instr[5];   // CLI / SEI
                                2'b10:
                                    if (instr[5])
                                        p_nxt[P_V] = 0;         // CLV
                                    else begin                  // TYA
                                        acc_nxt = y;
                                        p_nxt = func_nzflags(p, acc_nxt);
                                    end
                                2'b11: p_nxt[P_D] = instr[5];   // CLD / SED
                            endcase
                            instr_nxt = DI;
                            SYNC = 1;
                        end

                        8'b0??0_1000: begin     // PHP/PLP/PHA/PLA
                            pc_nxt = pc;
                            if (instr[5]) begin
                                // Pull
                                A = {8'h01, sp_inc};
                                sp_nxt = sp_inc;
                                cpu_sm_nxt = CPU_SM_EXECUTE;
                            end
                            else begin
                                // Push
                                A = {8'h01, sp};
                                DO = instr[6] ? acc : (p | (8'h01 << P_B));
                                RW = 0;
                                sp_nxt = sp_dec;
                                cpu_sm_nxt = CPU_SM_STORE;
                            end
                        end

                        8'b1??0_1000: begin // Other one byte instrs
                            case (instr[6:5])
                                2'b00: begin // DEY
                                    y_nxt = y - 1;
                                    p_nxt = func_nzflags(p, y_nxt);
                                end
                                2'b01: begin // TAY
                                    y_nxt = acc;
                                    p_nxt = func_nzflags(p, y_nxt);
                                end
                                2'b10: begin // INY
                                    y_nxt = y + 1;
                                    p_nxt = func_nzflags(p, y_nxt);
                                end
                                2'b11: begin // INX
                                    x_nxt = x + 1;
                                    p_nxt = func_nzflags(p, x_nxt);
                                end
                            endcase
                            instr_nxt = DI;
                            SYNC = 1;
                        end

                        8'b1???_1010: begin // TXA,TXS,TAX,TSX,DEX,NOP
                            case (instr[6:4])
                                3'b000: begin       // TXA
                                    acc_nxt = x;
                                    p_nxt = func_nzflags(p, acc_nxt);
                                end
                                3'b001: sp_nxt = x; // TXS
                                3'b010: begin       // TAX
                                    x_nxt = acc;
                                    p_nxt = func_nzflags(p, x_nxt);
                                end
                                3'b011: begin       // TSX
                                    x_nxt = sp;
                                    p_nxt = func_nzflags(p, x_nxt);
                                end
                                3'b100: begin       // DEX
                                    x_nxt = x - 1;
                                    p_nxt = func_nzflags(p, x_nxt);
                                end
                                default: ;
                            endcase
                            instr_nxt = DI;
                            SYNC = 1;
                        end

                        8'b????_??01: begin // Group one instructions
                            if (addr_mode == ADDR_MODE_IMMEDIATE)
                                cpu_sm_nxt = CPU_SM_EXECUTE;
                            else
                                cpu_sm_nxt = CPU_SM_FETCH_I1;
                        end

                        8'b????_??10: begin // Group two instructions
                            if (addr_mode == ADDR_MODE_ACC) begin
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
                                instr_nxt = DI;
                                SYNC = 1;
                            end
                            else if (addr_mode == ADDR_MODE_IMMEDIATE)
                                cpu_sm_nxt = CPU_SM_EXECUTE; // LDX #imm
                            else
                                cpu_sm_nxt = CPU_SM_FETCH_I1;
                        end

                        8'b????_??00: begin // Group three instructions
                            if (addr_mode == ADDR_MODE_IMMEDIATE)
                                cpu_sm_nxt = CPU_SM_EXECUTE;
                            else
                                cpu_sm_nxt = CPU_SM_FETCH_I1;
                        end

                        default: begin
                            // synthesis translate_off
                            if (!reset) begin
                                $display("[%t] Instruction decode fail? %h",
                                         $time, instr);
                                $stop;
                            end
                            // synthesis translate_on
                        end
                    endcase // case (instr)
                end // CPU_SM_DECODE

            // Execute conditional branches.
            CPU_SM_BRANCH: begin:br
                reg do_branch;

                case (instr[7:6])
                    2'b00: do_branch = (p[P_N] == instr[5]);
                    2'b01: do_branch = (p[P_V] == instr[5]);
                    2'b10: do_branch = (p[P_C] == instr[5]);
                    2'b11: do_branch = (p[P_Z] == instr[5]);
                endcase

                if (do_branch) begin
                    pc_nxt = pc + {{8{data_in_r[7]}}, data_in_r};
                    cpu_sm_nxt = CPU_SM_STALL;
                end
                else begin
                    instr_nxt = DI;
                    SYNC = 1;
                    pc_nxt = pc_inc;
                    cpu_sm_nxt = CPU_SM_DECODE;
                end
            end

            // Fetch first byte of operand
            CPU_SM_FETCH_I1: begin
                opaddr_h_nxt = 8'h00;

                // Calculate address output (other than absolute
                // which uses the pc).
                case (addr_mode)
                    ADDR_MODE_ZEROPG:       A = {8'h00, data_in_r};
                    ADDR_MODE_ZEROPG_X:     A = {8'h00, data_in_r + x};
                    ADDR_MODE_ZEROPG_Y:     A = {8'h00, data_in_r + y};
                    ADDR_MODE_INDIRECT_X:   A = {8'h00, data_in_r + x};
                    ADDR_MODE_INDIRECT_Y:   A = {8'h00, data_in_r};
                    default: ;
                endcase

                case (addr_mode)
                    ADDR_MODE_ZEROPG,
                    ADDR_MODE_ZEROPG_X,
                    ADDR_MODE_ZEROPG_Y: begin
                        opaddr_l_nxt = A[7:0];
                        cpu_sm_nxt = CPU_SM_EXECUTE;
                    end
                    ADDR_MODE_INDIRECT_X,
                        ADDR_MODE_INDIRECT_Y: begin
                            opaddr_l_nxt = A[7:0];
                            cpu_sm_nxt = CPU_SM_FETCH_IND1;
                        end
                    ADDR_MODE_ABS,
                        ADDR_MODE_ABS_X,
                        ADDR_MODE_ABS_Y: begin
                            opaddr_l_nxt = data_in_r;
                            pc_nxt = pc_inc;
                            cpu_sm_nxt = CPU_SM_FETCH_I2;
                        end
                    default: begin
                        // synthesis translate_off
                        if (!reset) begin
                            $display("[%t] CPU_SM_FETCH_I1: decode fail? %h",
                                     $time, instr);
                            $stop;
                        end
                        // synthesis translate_on
                    end
                endcase
            end // CPU_SM_FETCH_I1

            // Fetch second byte of operand.
            CPU_SM_FETCH_I2: begin
                case (addr_mode)
                    ADDR_MODE_ABS:      A = {data_in_r, opaddr_l};
                    ADDR_MODE_ABS_X:    A = {data_in_r, opaddr_l} + x;
                    ADDR_MODE_ABS_Y:    A = {data_in_r, opaddr_l} + y;
                    default: begin
                        // synthesis translate_off
                        if (!reset) begin
                            $display("[%t] CPU_SM_FETCH_I2: decode fail? %h",
                                     $time, instr);
                            $stop;
                        end
                        // synthesis translate_on
                    end
                endcase

                {opaddr_h_nxt, opaddr_l_nxt} = A;

                // Hand JMP and JSR here.
                case (instr)
                    8'h20: begin // JSR
                        // Push high byte of PC
                        A = {8'h01, sp};
                        DO = pc_dec[15:8];
                        RW = 0;
                        pc_nxt = pc_dec;
                        sp_nxt = sp_dec;
                        cpu_sm_nxt = CPU_SM_JSR1;
                    end
                    8'h4c: begin // JMP abs
                        pc_nxt = {data_in_r, opaddr_l};
                        cpu_sm_nxt = CPU_SM_STALL;
                    end
                    8'h6c: // JMP (ind)
                        cpu_sm_nxt = CPU_SM_FETCH_IND1;
                    default:
                        cpu_sm_nxt = CPU_SM_EXECUTE;
                endcase
            end // CPU_SM_FETCH_I2

            // Fetch low byte of address in indirect instructions.
            CPU_SM_FETCH_IND1: begin
                A = {opaddr_h, opaddr_l + 1'b1};
                opaddr_l_nxt = data_in_r;
                cpu_sm_nxt = CPU_SM_FETCH_IND2;
            end

            // Fetch high byte of address in indirect instructions.
            CPU_SM_FETCH_IND2: begin
                if (instr == 8'h6c) begin // JMP (ind)
                    pc_nxt = {data_in_r, opaddr_l};
                    cpu_sm_nxt = CPU_SM_STALL;
                end
                else begin
                    if (addr_mode == ADDR_MODE_INDIRECT_Y)
                        A = {data_in_r, opaddr_l} + y;
                    else
                        A = {data_in_r, opaddr_l};
                    {opaddr_h_nxt, opaddr_l_nxt} = A;
                    cpu_sm_nxt = CPU_SM_EXECUTE;
                end
            end

            // Execute most instructions after fetching operand
            CPU_SM_EXECUTE: begin
                // By default, go back to decode state.  Some cases overide
                // this.
                instr_nxt = DI;
                SYNC = 1;
                pc_nxt = pc_inc;
                cpu_sm_nxt = CPU_SM_DECODE;

                casez (instr)
                    8'b0?10_1000:       // PLA/PLP instructions
                        if (instr[6]) begin
                            acc_nxt = data_in_r;
                            p_nxt = func_nzflags(p, acc_nxt);
                        end
                        else begin
                            p_nxt = data_in_r;
                            p_nxt[P_B] = 0;
                            p_nxt[P_1] = 1;
                        end

                    8'b100?_??01: begin // STA
                        instr_nxt = instr;
                        SYNC = 0;
                        A = {opaddr_h, opaddr_l};
                        DO = acc;
                        RW = 0;
                        pc_nxt = pc;
                        cpu_sm_nxt = CPU_SM_STORE;
                    end

                    8'b????_??01: begin // Group one instructions (except STA)
                        // ALU instructions
                        case (instr[7:5])
                            3'b000: acc_nxt = acc | data_in_r; // OR
                            3'b001: acc_nxt = acc & data_in_r; // AND
                            3'b010: acc_nxt = acc ^ data_in_r; // EOR
                            3'b011: begin // ADC
                                if (p[P_D]) begin:bcd_adc
                                    // Decimal mode
                                    reg [4:0] nyb_l;
                                    reg [4:0] nyb_h;

                                    nyb_l = {1'b0, acc[3:0]} + data_in_r[3:0] +
                                            p[P_C];
                                    if (nyb_l > 5'd9)
                                        nyb_l = nyb_l + 5'd6;
                                    nyb_h = {1'b0, acc[7:4]} + data_in_r[7:4] +
                                            nyb_l[4];
                                    if (nyb_h > 5'd9)
                                        nyb_h = nyb_h + 5'd6;
                                    acc_nxt = {nyb_h[3:0], nyb_l[3:0]};
                                    p_nxt[P_C] = nyb_h[4];
                                end
                                else
                                    {p_nxt[P_C], acc_nxt} = {1'b0, acc} +
                                                            data_in_r + p[P_C];
                                p_nxt[P_V] = acc[7] == data_in_r[7] &&
                                             acc[7] != acc_nxt[7];
                            end // ADC
                            3'b101: // LDA
                                acc_nxt = data_in_r; // LDA
                            3'b110: // CMP
                                p_nxt = func_compare(p, acc,  data_in_r);
                            3'b111: begin // SBC
                                if (p[P_D]) begin:bcd_sbc
                                    // Decimal mode
                                    reg [4:0] nyb_l;
                                    reg [4:0] nyb_h;

                                    nyb_l = {1'b0, acc[3:0]} - data_in_r[3:0] -
                                            !p[P_C];
                                    if (nyb_l[4])
                                        nyb_l = nyb_l - 5'd6;
                                    nyb_h = {1'b0, acc[7:4]} - data_in_r[7:4] -
                                            nyb_l[4];
                                    if (nyb_h[4])
                                        nyb_h = nyb_h - 5'd6;

                                    acc_nxt = {nyb_h[3:0], nyb_l[3:0]};
                                    p_nxt[P_C] = ~nyb_h[4];
                                end
                                else begin:sbc
                                    reg borrow;
                                    {borrow, acc_nxt} = {1'b0, acc} -
                                                        data_in_r - !p[P_C];
                                    p_nxt[P_C] = ~borrow;
                                end
                                p_nxt[P_V] = acc[7] != data_in_r[7] &&
                                             acc[7] != acc_nxt[7];
                            end // SBC
                            default: ;
                        endcase

                        // Set N and Z flags except for CMP
                        if (instr[7:5] != 3'b110)
                            p_nxt = func_nzflags(p_nxt, acc_nxt);
                    end

                    8'b101?_??10: begin         // LDX
                        x_nxt = data_in_r;
                        p_nxt = func_nzflags(p, x_nxt);
                    end

                    8'b????_??10: begin // Group two instructions (ex LDX)

                        instr_nxt = instr;
                        SYNC = 0;
                        RW = 0;
                        A = {opaddr_h, opaddr_l};

                        case (instr[7:5])
                            3'b000: // ASL
                                {p_nxt[P_C], DO} = {data_in_r, 1'b0};
                            3'b001: // ROL
                                {p_nxt[P_C], DO} = {data_in_r, p[P_C]};
                            3'b010: // LSR
                                {DO, p_nxt[P_C]} = {1'b0, data_in_r};
                            3'b011: // ROR
                                {DO, p_nxt[P_C]} = {p[P_C], data_in_r};
                            3'b100: // STX
                                DO = x;
                            3'b110: // DEC
                                DO = data_in_r - 1;
                            3'b111: // INC
                                DO = data_in_r + 1;
                            default: ;
                        endcase

                        if (instr[7:5] != 3'b100) // !STX
                            p_nxt = func_nzflags(p_nxt, DO);

                        pc_nxt = pc;
                        cpu_sm_nxt = CPU_SM_STORE;
                    end

                    8'b????_??00:   // Group three instructions
                        case (instr[7:5])
                            3'b001: begin // BIT
                                p_nxt[P_N] = data_in_r[7];
                                p_nxt[P_V] = data_in_r[6];
                                p_nxt[P_Z] = (acc & data_in_r) == 0;
                            end
                            3'b100: begin // STY
                                SYNC = 0;
                                instr_nxt = instr;
                                A = {opaddr_h, opaddr_l};
                                DO = y;
                                RW = 0;
                                pc_nxt = pc;
                                cpu_sm_nxt = CPU_SM_STORE;
                            end
                            3'b101: begin // LDY
                                y_nxt = data_in_r;
                                p_nxt = func_nzflags(p, y_nxt);
                            end
                            3'b110: // CPY
                                p_nxt = func_compare(p, y, data_in_r);
                            3'b111: // CPX
                                p_nxt = func_compare(p, x, data_in_r);
                            default: ;
                        endcase

                    default: begin
                        // synthesis translate_off
                        if (!reset) begin
                            $display("[%t] CPU_SM_EXECUTE: decode failure? %h",
                                     $time, instr);
                            $stop;
                        end
                        // synthesis translate_on
                    end
                endcase
            end // CPU_SM_EXECUTE

            CPU_SM_STORE: begin
                pc_nxt = pc_inc;
                instr_nxt = DI;
                SYNC = 1;
                cpu_sm_nxt = CPU_SM_DECODE;
            end

            CPU_SM_JSR1: begin
                // Push low byte of PC
                A = {8'h01, sp};
                DO = pc[7:0];
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_JSR2;
            end

            CPU_SM_JSR2: begin
                // Jump to address in operand.
                pc_nxt = {opaddr_h, opaddr_l};
                cpu_sm_nxt = CPU_SM_STALL;
            end

            CPU_SM_INTR1: begin
                // Push high byte of PC
                A = {8'h01, sp};
                DO = pc[15:8];
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_INTR2;
            end

            CPU_SM_INTR2: begin
                // Push low byte of PC
                A = {8'h01, sp};
                DO = pc[7:0];
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_INTR3;
            end

            CPU_SM_INTR3: begin
                // Push processor status
                A = {8'h01, sp};
                DO = p;
                RW = 0;
                sp_nxt = sp_dec;
                cpu_sm_nxt = CPU_SM_INTR4;
            end

            CPU_SM_INTR4: begin
                // Read interrupt vector
                pc_nxt = (do_nmi ? NMI_VEC : IRQ_VEC);
                A = pc_nxt;
                p_nxt[P_I] = 1;
                p_nxt[P_B] = 0;
                p_nxt[P_D] = 0; // like a 65c02!
                clr_do_nmi = do_nmi;
                pc_nxt = pc_nxt + 1;
                cpu_sm_nxt = CPU_SM_VECTOR1;
            end

            CPU_SM_RTI:  begin
                // Read processor status off of stack
                A = {8'h01, sp_inc};
                p_nxt = data_in_r;
                p_nxt[P_B] = 0;
                p_nxt[P_1] = 1;
                sp_nxt = sp_inc;
                cpu_sm_nxt = CPU_SM_RTSI1;
            end

            CPU_SM_RTSI1: begin
                // Read low byte of return address
                A = {8'h01, sp_inc};
                pc_nxt[7:0] = data_in_r;
                sp_nxt = sp_inc;
                cpu_sm_nxt = CPU_SM_RTSI2;
            end

            CPU_SM_RTSI2: begin
                // Read high byte of return address from stack
                pc_nxt = {data_in_r, pc[7:0]};
                if (instr[5]) // Increment address if RTS
                    pc_nxt = pc_nxt + 1;
                cpu_sm_nxt = CPU_SM_STALL;
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
