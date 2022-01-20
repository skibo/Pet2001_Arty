`timescale 1ns / 1ps
//
// Copyright (c) 2011, 2021 Thomas Skibo.
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

// Sanity check pet2001ps2_key.  Not exhaustive.

module test_pet2001ps2_key;

    // Inputs
    reg [3:0] keyrow;
    reg       ps2_clk;
    reg       ps2_data;
    reg       clk;
    reg       reset;

    // Outputs
    wire [7:0] keyin;

    // Instantiate the Unit Under Test (UUT)
    pet2001ps2_key
        uut (
             .keyin(keyin),
             .keyrow(keyrow),
             .ps2_clk(ps2_clk),
             .ps2_data(ps2_data),
             .clk(clk),
             .reset(reset)
        );

    // Way fast PS/2 rate.
    parameter PS2_CLK_RATE = 20;

    task putbit;
        input bit;
        begin
            ps2_data <= #1 bit;
            repeat (PS2_CLK_RATE) @(posedge clk);
            ps2_clk <= #1 0;
            repeat (PS2_CLK_RATE * 2) @(posedge clk);
            ps2_clk <= #1 1;
            repeat (PS2_CLK_RATE) @(posedge clk);
        end
    endtask

    task putbyte;
        input [7:0] b;
        integer     i;
        reg         parity;
        begin
            parity = ~^{b};
            putbit(0);
            for (i=0; i<8; i=i+1)
                putbit(b[i]);
            putbit(parity);
            putbit(1);

            repeat (PS2_CLK_RATE * 2) @(posedge clk);
        end
    endtask // putbyte

    reg [7:0] expctrows[15:0];

    task checkrows;
        integer i;
        begin
            for (i=0; i<16; i=i+1) begin
                keyrow <= 4'd0 + i;
                @(posedge clk);
                $display("[%t] row: %b keyin: %b", $time, keyrow, keyin);
                if (keyin !== expctrows[i]) begin
                    $display("[%t] checkrows: INCORRECT row expecting %b",
                             $time, expctrows[i]);
                    $stop;
                end
            end
            $display("------------------");
        end
    endtask // checkrows

    initial begin:test0
        integer i;

        // Initialize Inputs
        keyrow = 0;
        ps2_clk = 1;
        ps2_data = 0;
        clk = 0;
        reset = 1;

        // Intialize check row data
        for (i=0; i<16; i=i+1)
            expctrows[i] = 8'hff;

        // Wait 100 ns for global reset to finish
        #100;

        // Add stimulus here
        repeat (10) @(posedge clk);
        reset <= 0;

        // Let reset sequence happen.
        repeat (20) @(posedge clk);

        $display("Initial row state:");
        checkrows();

        putbyte(8'h1A); // press Z
        $display("Press Z");
        expctrows[7] = 8'hfe;
        checkrows();
        putbyte(8'hF0);
        putbyte(8'h1A); // release Z
        expctrows[7] = 8'hff;
        $display("Release Z");
        checkrows();

        putbyte(8'h1A); // press Z
        expctrows[7] = 8'hfe;
        putbyte(8'h2C); // press T
        expctrows[3] = 8'hfb;
        $display("Press Z and T");
        checkrows();

        putbyte(8'h2C); // press T again
        putbyte(8'hF0); // release T
        putbyte(8'h2C);
        expctrows[3] = 8'hff;
        $display("Release T (still Z?)");
        checkrows();

        putbyte(8'hF0);
        putbyte(8'h1A); // release Z
        expctrows[7] = 8'hff;
        $display("Release Z");
        checkrows();

        $display("[%t] SUCCESS!", $time);
        $finish;
    end // initial begin

    always #5.0 clk = ~clk;

endmodule
