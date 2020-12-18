`timescale 1ns / 1ps
//
// Copyright (c) 2017 Thomas Skibo.
// All rights reserved.
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
////////////////////
//
// This is a testbench to run Klaus Dormann's awesome 6502 test suite on
// my 6502 implementation.
//
// See https://github.com/Klaus2m5/6502_65C02_functional_tests
//
// From the repository, take the binary in bin_files/6502_function_test.bin
// and convert it into a .mem file using:
//
// hexdump -v -e '/1 "%02X\n"' 6502_function_test.bin > 6502_function_test.mem
//
// Be sure to add the .mem file to your project so Vivado can find it.  The
// simulation time is about 75s (at 1Mhz).
//

module test_cpu6502;

    wire [15:0] addr;
    wire [7:0]  data_out;
    wire        we;
    reg [7:0]   data_in;
    reg         rdy;
    reg         irq;
    reg         nmi;
    reg         reset;
    reg         clk;


    initial begin
        rdy = 1;
        irq = 0;
        nmi = 0;
        reset = 1;
        clk = 0;
        repeat (20) @(posedge clk);
        reset <= 0;
    end

    // A 1Mhz clock
    always #500 clk = ~clk;

    // Initialize memory with test.
    reg [7:0] mem[65535:0];
    initial begin
        $readmemh("6502_functional_test.mem", mem);

        // Insert start address into reset vector.
        mem[16'hfffc] = 8'h00;
        mem[16'hfffd] = 8'h04;
    end

    // Implement memory reads and writes.
    always @(addr)
        data_in <= mem[addr];
    always @(posedge clk)
        if (we)
            mem[addr] <= data_out;

    // Detect infinite loop, either a two or three byte instruction.
    reg [95:0] addr_321;
    always @(posedge clk) begin
        if (!we && !reset && addr !== addr_321[15:0]) begin
            addr_321 = {addr_321[79:0], addr};
            if (addr_321[95:48] == addr_321[47:0] ||
                (addr_321[95:64] == addr_321[63:32] &&
                 addr_321[63:32] == addr_321[31:0])) begin
                $display("[%t] Infinite loop at %h", $time, addr_321[95:80]);
                $stop;
            end
        end
    end

    cpu6502 cpu6502_0(
                      .addr(addr),
                      .data_out(data_out),
                      .we(we),
                      .data_in(data_in),
                      .rdy(rdy),
                      .irq(irq),
                      .nmi(nmi),
                      .reset(reset),
                      .clk(clk)
    );

endmodule // test_cpu6502
