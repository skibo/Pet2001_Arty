`timescale 1ns / 1ps
//
// Copyright (c) 2020 Thomas Skibo.
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


module test_via6522;

    // Register address offsets
    localparam [3:0]
        ADDR_PORTB =            4'h0,
        ADDR_PORTA =            4'h1,
        ADDR_DDRB =             4'h2,
        ADDR_DDRA =             4'h3,
        ADDR_TIMER1_LO =        4'h4,
        ADDR_TIMER1_HI =        4'h5,
        ADDR_TIMER1_LATCH_LO =  4'h6,
        ADDR_TIMER1_LATCH_HI =  4'h7,
        ADDR_TIMER2_LO =        4'h8,
        ADDR_TIMER2_HI =        4'h9,
        ADDR_SR =               4'ha,
        ADDR_ACR =              4'hb,
        ADDR_PCR =              4'hc,
        ADDR_IFR =              4'hd,
        ADDR_IER =              4'he,
        ADDR_PORTA_NH =         4'hf;

    wire [7:0]  data_out;
    reg [7:0]   data_in;
    reg [3:0]   addr;
    reg         strobe;
    reg         we;
    wire        irq;
    wire [7:0]  porta_out;
    reg [7:0]   porta_in;
    wire [7:0]  portb_out;
    reg [7:0]   portb_in;
    reg         ca1_in;
    wire        ca2_out;
    reg         ca2_in;
    wire        cb1_out;
    reg         cb1_in;
    wire        cb2_out;
    reg [7:0]   cb2_in_shifter;
    wire        cb2_in = cb2_in_shifter[7];
    reg [7:0]   cb2_out_shifter;
    reg         slow_clock;
    reg         clk;
    reg         reset;


    initial begin
        strobe = 0;
        we = 0;
        porta_in = 'd0;
        portb_in = 'd0;
        ca1_in = 0;
        ca2_in = 0;
        cb1_in = 1;
        cb2_in_shifter = 8'h55;
        slow_clock = 0;
        clk = 0;
        reset = 1;

        repeat (20) @(posedge clk);
        reset <= 0;
    end

    always #50 clk = ~clk;
    always begin
        repeat (9) @(posedge clk);
        slow_clock <= 1;
        @(posedge clk);
        slow_clock <= 0;
    end

    always @(posedge cb1_out or negedge cb1_in)
        cb2_in_shifter <= {cb2_in_shifter[6:0], cb2_in_shifter[7]};
    always @(posedge cb1_out or posedge cb1_in)
        cb2_out_shifter <= {cb2_out_shifter[6:0], cb2_out};

    via6522
        via6522_0(
                  .data_out(data_out),
                  .data_in(data_in),
                  .addr(addr),
                  .strobe(strobe),
                  .we(we),
                  .irq(irq),
                  .porta_out(porta_out),
                  .porta_in(porta_in),
                  .portb_out(portb_out),
                  .portb_in(portb_in),
                  .ca1_in(ca1_in),
                  .ca2_out(ca2_out),
                  .ca2_in(ca2_in),
                  .cb1_out(cb1_out),
                  .cb1_in(cb1_in),
                  .cb2_out(cb2_out),
                  .cb2_in(cb2_in),
                  .slow_clock(slow_clock),
                  .clk(clk),
                  .reset(reset)
        );

    task wrreg(input [3:0] a,
               input [7:0] d);
        begin
            data_in <= d;
            addr <= a;
            we <= 1;
            strobe <= 1;
            @(posedge clk);
            strobe <= 0;
            we <= 0;
            data_in <= 8'hXX;
            addr <= 4'hX;
            @(posedge clk);
        end
    endtask

    task rdreg(input [3:0] a,
               output [7:0] d);
        begin
            addr <= a;
            strobe <= 1;
            @(posedge clk);
            strobe <= 0;
            d = data_out;
            @(posedge clk);
        end
    endtask

    task checkirq(input i);
        begin
            $display("[%t] Check irq=%b", $time, i);
            if (irq !== i) begin
                $display("[%t] IRQ expected to be %b is %b", $time, i, irq);
                $stop;
            end
        end
    endtask

    reg [7:0] d8;
    reg [7:0] d8_1;
    initial begin
        @(negedge reset);
        repeat (10) @(posedge clk);

        /////////////////// Timer1 Tests ///////////////////////////////
        $display("[%t] Timer 1 Tests......", $time);

        wrreg(ADDR_IFR, 8'h7f);     // clear int flags
        wrreg(ADDR_IER, 8'hc0);     // enable T1 interrupt
        wrreg(ADDR_ACR, 8'h00);     // set mode ("one shot")

        @(posedge slow_clock);
        @(posedge clk);

        wrreg(ADDR_TIMER1_LO, 8'h50);
        wrreg(ADDR_TIMER1_HI, 8'h01);

        repeat (337) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b0);
        rdreg(ADDR_TIMER1_LO, d8);
        rdreg(ADDR_TIMER1_HI, d8_1);
        $display("[%t] TIMER T1: %h%h", $time, d8_1, d8);
        @(posedge slow_clock);
        repeat (3) @(posedge clk);
        checkirq(1'b1);

        // clear interrupt.
        rdreg(ADDR_TIMER1_LO, d8);
        @(posedge clk);
        checkirq(1'b0);

        // check true one-shot by waiting for timer roll-over
        repeat (350) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b0);

        wrreg(ADDR_ACR, 8'hc0);     // set T1 mode free-running, PB7 out
        wrreg(ADDR_TIMER1_LO, 8'h50);
        wrreg(ADDR_TIMER1_HI, 8'h01);

        repeat (350) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b1);

        if (portb_out[7] !== 1'b1) begin
            $display("[%t] Expecting PB[7] to toggle to 1.", $time);
            $stop;
        end

        // clear interrupt
        wrreg(ADDR_IFR, 8'h40);
        @(posedge clk);
        checkirq(1'b0);

        // Fires again?
        repeat (350) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b1);

        if (portb_out[7] !== 1'b0) begin
            $display("[%t] Expecting PB[7] to toggle to 0.", $time);
            $stop;
        end

        // clear interrupt by reading T1L
        rdreg(ADDR_TIMER1_LO, d8);
        @(posedge clk);
        checkirq(1'b0);

        // clear interrupt enable.
        wrreg(ADDR_IER, 8'h40);

        /////////////////// Timer2 Tests ///////////////////////////////
        $display("[%t] Timer 2 Tests......", $time);

        wrreg(ADDR_ACR, 8'h00);     // set mode ("no shift-register")
        wrreg(ADDR_IER, 8'hA0);     // enable T2 interrupt.

        @(posedge slow_clock);
        @(posedge clk);

        wrreg(ADDR_TIMER2_LO, 8'h50);
        wrreg(ADDR_TIMER2_HI, 8'h01);

        repeat (337) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b0);
        @(posedge slow_clock);
        repeat (3) @(posedge clk);
        checkirq(1'b1);

        // Test that T2 did not reload in this mode.
        rdreg(ADDR_TIMER2_LO, d8);
        rdreg(ADDR_TIMER2_HI, d8_1);
        $display("[%t] TIMER T2: %h%h", $time, d8_1, d8);
        if (d8 !== 8'hfe || d8_1 !== 8'hff) begin
            $display("[%t] unexpected T2 value: %h%h", $time, d8_1, d8);
            $stop;
        end


        ///////////////// Shift Register Tests ////////////////////////
        $display("[%t] Shift Register Tests.......", $time);

        $display("[%t] Mode 001: Shift in by Timer2", $time);
        wrreg(ADDR_ACR, 8'h04);     // set mode ("shift register in by T2")
        wrreg(ADDR_IER, 8'h84);     // enable SR interrupt.
        wrreg(ADDR_TIMER2_LO, 8'h10);

        cb2_in_shifter = 8'hb9;
        wrreg(ADDR_SR, 8'h00);      // start SR
        @(negedge cb1_out);

        repeat (7) begin
            @(posedge cb1_out);
            @(posedge clk);
        end
        checkirq(1'b0);
        @(posedge cb1_out);
        @(posedge clk);
        @(posedge clk);
        checkirq(1'b1);

        rdreg(ADDR_SR, d8);     // actually triggers SR again.
        $display("[%t] SR=%h", $time, d8);
        if (d8 !== 8'hb9) begin
            $display("[%t] unexpected SR value.", $time);
            $stop;
        end

        // Let second trigger run...
        repeat (300) @(posedge slow_clock);
        @(posedge clk);
        checkirq(1'b1);
        wrreg(ADDR_IFR, 8'h04);
        @(posedge clk);
        checkirq(1'b0);

        $display("[%t] Mode 010: Shift in by System Clock.", $time);
        wrreg(ADDR_ACR, 8'h08);     // set mode ("shift register in sys clk")
        cb2_in_shifter = 8'hc5;
        rdreg(ADDR_SR, d8);         // start SR
        @(negedge cb1_out);

        repeat (7) begin
            @(posedge cb1_out);
            @(posedge clk);
        end
        checkirq(1'b0);
        @(posedge cb1_out);
        @(posedge clk);
        @(posedge clk);
        checkirq(1'b1);

        rdreg(ADDR_SR, d8);     // actually triggers SR again.
        $display("[%t] SR=%h", $time, d8);
        if (d8 !== 8'hc5) begin
            $display("[%t] unexpected SR value.", $time);
            $stop;
        end

        // Let second trigger run...
        repeat (16) @(posedge slow_clock);
        repeat (3) @(posedge clk);
        checkirq(1'b1);
        wrreg(ADDR_IFR, 8'h04);
        @(posedge clk);
        checkirq(1'b0);

        $display("[%t] Mode 011: Shift in by external clock.", $time);
        wrreg(ADDR_ACR, 8'h0c);     // set mode ("shift reg in external clk")
        wrreg(ADDR_SR, 8'h00);      // start SR

        // NOTE: in external clock mode, the value clocked on CB2 is this value
        // rotated left.  So, 8'h87 is the correct answer at the end of the
        // test.
        cb2_in_shifter = 8'hc3;

        // Wiggle cb1_in.
        repeat (7) begin
            repeat (4) @(posedge clk);
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            cb1_in <= 1;
        end
        repeat (4) @(posedge clk);
        checkirq(1'b0);
        cb1_in <= 0;
        repeat (4) @(posedge clk);
        cb1_in <= 1;
        repeat (3) @(posedge clk);
        checkirq(1'b1);
        wrreg(ADDR_IFR, 8'h04);
        @(posedge clk);
        checkirq(1'b0);

        rdreg(ADDR_SR, d8);     // actually triggers SR again.
        $display("[%t] SR=%h", $time, d8);
        if (d8 !== 8'h87) begin
            $display("[%t] unexpected SR value.", $time);
            $stop;
        end

        // Let second trigger run...
        repeat (8) begin
            repeat (4) @(posedge clk);
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            cb1_in <= 1;
        end
        repeat (3) @(posedge clk);
        checkirq(1'b1);
        wrreg(ADDR_IFR, 8'h04);
        @(posedge clk);
        checkirq(1'b0);

        repeat (20) @(posedge clk);

        $display("[%t] Mode 101: Shift out by Timer2", $time);
        wrreg(ADDR_ACR, 8'h14);     // set mode ("shift register out by T2")
        wrreg(ADDR_IER, 8'h84);     // enable SR interrupt.
        wrreg(ADDR_TIMER2_LO, 8'h10);

        wrreg(ADDR_SR, 8'he7);      // start SR
        @(negedge cb1_out);

        repeat (7) begin
            @(posedge cb1_out);
            @(posedge clk);
        end
        checkirq(1'b0);
        @(posedge cb1_out);
        @(posedge clk);
        @(posedge clk);
        checkirq(1'b1);

        $display("[%t] CB2 serial output: %h", $time, cb2_out_shifter);
        if (cb2_out_shifter !== 8'he7) begin
            $display("[%t] unexpected CB2 serial output.", $time);
            $stop;
        end

        repeat (20) @(posedge clk);

        $display("[%t] Mode 110: Shift out by system clock.", $time);
        wrreg(ADDR_ACR, 8'h18);     // set mode ("shift register out sys clk")

        wrreg(ADDR_SR, 8'hc3);
        @(negedge cb1_out);

        repeat (7) begin
            @(posedge cb1_out);
            @(posedge clk);
        end
        checkirq(1'b0);
        @(posedge cb1_out);
        @(posedge clk);
        @(posedge clk);
        checkirq(1'b1);

        $display("[%t] CB2 serial output: %h", $time, cb2_out_shifter);
        if (cb2_out_shifter !== 8'hc3) begin
            $display("[%t] unexpected CB2 serial output.", $time);
            $stop;
        end

        repeat (20) @(posedge clk);

        $display("[%t] Mode 111: Shift out by external clock.", $time);
        wrreg(ADDR_ACR, 8'h1c);     // set mode ("shift reg out external clk")
        wrreg(ADDR_SR, 8'h3e);      // start SR

        // Wiggle cb1_in
        repeat (7) begin
            repeat (4) @(posedge clk);
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            cb1_in <= 1;
        end
        repeat (4) @(posedge clk);
        checkirq(1'b0);
        cb1_in <= 0;
        repeat (4) @(posedge clk);
        cb1_in <= 1;
        repeat (3) @(posedge clk);
        checkirq(1'b1);
        wrreg(ADDR_IFR, 8'h04);
        @(posedge clk);
        checkirq(1'b0);

        $display("[%t] CB2 serial output: %h", $time, cb2_out_shifter);
        if (cb2_out_shifter !== 8'h3e) begin
            $display("[%t] unexpected CB2 serial output.", $time);
            $stop;
        end

        repeat (20) @(posedge clk);

        $display("[%t] mode 100: Shift out by T2 free-running.", $time);
        wrreg(ADDR_ACR, 8'h10);     // set mode ("free-running SR")

        // This writes the latch only.  T2 has to underflow and then
        // it should cycle over 82 slow clocks.  Write SR to activate
        // cb1_out.
        wrreg(ADDR_TIMER2_LO, 8'h50);
        wrreg(ADDR_SR, 8'h0f);

        @(negedge cb1_out);
        @(posedge clk);

        rdreg(ADDR_TIMER2_LO, d8);
        if (d8 !== 8'h50) begin
            $display("[%t] unexpected T2L value: %h", $time, d8);
            $stop;
        end

        // Done!
        repeat (20) @(posedge clk);
        $display("[%t] TEST DONE!", $time);
        $finish;
    end

endmodule // test_via6522
