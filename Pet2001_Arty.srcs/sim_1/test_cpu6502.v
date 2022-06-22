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

//
// This is a testbench to run Klaus Dormann's awesome 6502 test suite on
// my 6502 implementation.
//
// See https://github.com/Klaus2m5/6502_65C02_functional_tests
//
// From the repository, take the binary in bin_files/6502_functional_test.bin
// and convert it into a .mem file using:
//
// hexdump -v -e '/1 "%02X\n"' 6502_functional_test.bin \
//    > 6502_functional_test.mem
//
// Be sure to add the .mem file to your project so Vivado can find it.
//
// The simulation runs until it detects that the 6502 is in a tight infinite
// loop which is what happens when the functional tests either detect a
// problem or when the tests succeed.  You should download the listing file
// from the same location as the binary so you can look up where the test
// has stopped.
//
// The simulation time of a successful test is about 78s (at 1Mhz).
//

module test_cpu6502;

    reg         PHI;
    reg         RES_;
    reg         RDY;
    reg         NMI_;
    reg         IRQ_;
    wire [7:0]   DI;
    wire [7:0]  DO;
    wire        RW;
    wire        SYNC;
    wire [15:0] A;

    parameter MEMFILE = "6502_functional_test.mem";
    parameter TESTRDY = 0;

    integer     cycles;
    integer     instrs;

    initial begin
        cycles = 0;
        instrs = 0;

        PHI = 0;
        RES_ = 0;
        RDY = 1;
        NMI_ = 1;
        IRQ_ = 1;

        repeat (5) @(posedge PHI);

        RES_ <= 1;
    end

    always #500 PHI = !PHI;

    always @(posedge PHI)
        if (RES_) begin
            cycles = cycles + 1;
            if (SYNC && RDY)
                instrs = instrs + 1;
        end

    cpu6502 cpu6502_0(
                      .A(A),
                      .RW(RW),
                      .DO(DO),
                      .DI(DI),
                      .RDY(RDY),
                      .SYNC(SYNC),
                      .IRQ_(IRQ_),
                      .NMI_(NMI_),
                      .RES_(RES_),
                      .PHI(PHI)
                  );

    // Simple memory.
    reg [7:0] mem[65535:0];
    reg [7:0] dout;

    initial begin
        $readmemh(MEMFILE, mem);

        // Put start address in RESET vector
        mem[16'hfffc] = 8'h00;
        mem[16'hfffd] = 8'h04;
    end

    always @(*)
        dout <= mem[A];

    // Only present good data when RDY is high.
    assign DI = RDY ? dout : 8'hXX;

    always @(posedge PHI)
        if (!RW)
            mem[A] <= DO;

    generate
        if (TESTRDY == 1) begin
            always @(posedge PHI)
                RDY <= $urandom;
        end
        else if (TESTRDY == 2) begin
            always @(posedge PHI) begin
                RDY <= 0;
                repeat (3) @(posedge PHI);
                RDY <= 1;
            end
        end
    endgenerate

    // Implement a magic location for setting IRQ and NMI signals.
    always @(posedge PHI)
        if (!RW && A == 16'hdead) begin
            IRQ_ <= DO[0];
            NMI_ <= DO[1];
        end

    always @(negedge IRQ_) $display("[%t] IRQ Triggered!", $time);

    always @(negedge NMI_) $display("[%t] NMI Triggered!", $time);

    // Detect infinite loop
    reg [15:0] addr_last;
    always @(posedge PHI)
        if (SYNC && RDY && RW) begin
            if (A == addr_last) begin
                $display("[%t] DETECTED INFINITE LOOP: %h", $time, A);
                $display("     cycles: %0d   instrs: %0d", cycles, instrs);
                $finish;
            end
            addr_last = A;
        end

    always #500000000 $display("Simulation Time: %d ms", $time / 1000000);

endmodule // test_cpu6502
