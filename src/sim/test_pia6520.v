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

module test_pia6520;

    // Register address offsets
    parameter [1:0]
        ADDR_PORTA =    2'b00,
        ADDR_CRA =      2'b01,
        ADDR_PORTB =    2'b10,
        ADDR_CRB =      2'b11;

    wire [7:0]  data_out;
    reg [7:0]   data_in;
    reg [1:0]   addr;
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
    reg         cb1_in;
    wire        cb2_out;
    reg         cb2_in;
    reg         clk;
    reg         reset;


    initial begin
        data_in = 'd0;
        addr = 'd0;
        strobe = 0;
        we = 0;
        porta_in = 'd0;
        portb_in = 'd0;
        ca1_in = 1;
        ca2_in = 1;
        cb1_in = 1;
        cb2_in = 1;
        clk = 0;
        reset = 1;

        repeat (20) @(posedge clk);
        reset <= 0;
    end

    always #50 clk = ~clk;

    pia6520
        pia6520_0(
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
                  .cb1_in(cb1_in),
                  .cb2_out(cb2_out),
                  .cb2_in(cb2_in),
                  .clk(clk),
                  .reset(reset)
        );

    task wrreg(input [1:0] a,
               input [7:0] d);
        begin
            data_in <= d;
            addr <= a;
            we <= 1;
            strobe <= 1;
            @(posedge clk);
            $display("[%t] wrreg(addr=%h, d=%h)", $time, a, d);
            strobe <= 0;
            we <= 0;
            data_in <= 8'hXX;
            addr <= 4'hX;
            @(posedge clk);
        end
    endtask

    task rdreg(input [1:0] a,
               output [7:0] d);
        begin
            addr <= a;
            strobe <= 1;
            @(posedge clk);
            strobe <= 0;
            d = data_out;
            $display("[%t] rdreg(addr=%h)=%h", $time, a, d);
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

    task porta_tests;
        begin
            /////////////////// Port A Tests ///////////////////////////////
            $display("[%t] PORT A Tests....", $time);
            wrreg(ADDR_CRA, 8'h00);
            wrreg(ADDR_PORTA, 8'hff);   // DDRA
            wrreg(ADDR_CRA, 8'h04);
            wrreg(ADDR_PORTA, 8'h55);
            if (porta_out !== 8'h55) begin
                $display("[%t] Unexpected: porta_out=%h", $time, porta_out);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);
            if (d8 !== 8'h55) begin
                $display("[%t] Unexpected: PORTA reg reads %h", $time, d8);
                $stop;
            end
            wrreg(ADDR_PORTA, 8'haa);
            if (porta_out !== 8'haa) begin
                $display("[%t] Unexpected: porta_out=%h", $time, porta_out);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);
            if (d8 !== 8'haa) begin
                $display("[%t] Unexpected: PORTA reg reads %h", $time, d8);
                $stop;
            end
            porta_in <= 8'h55;
            @(posedge clk);
            wrreg(ADDR_CRA, 8'h00);
            wrreg(ADDR_PORTA, 8'hf0);       // DDRA
            wrreg(ADDR_CRA, 8'h04);
            rdreg(ADDR_PORTA, d8);
            if (d8 !== 8'ha5) begin
                $display("[%t] Unexpected: PORTA reg reads %h", $time, d8);
                $stop;
            end
            wrreg(ADDR_CRA, 8'h00);
            wrreg(ADDR_PORTA, 8'h00);       // DDRA
            wrreg(ADDR_CRA, 8'h04);
            rdreg(ADDR_PORTA, d8);
            if (d8 !== 8'h55) begin
                $display("[%t] Unexpected: PORTA reg reads %h", $time, d8);
                $stop;
            end
            porta_in <= 8'haa;
            @(posedge clk);
            rdreg(ADDR_PORTA, d8);
            if (d8 !== 8'haa) begin
                $display("[%t] Unexpected: PORTA reg reads %h", $time, d8);
                $stop;
            end

            /////////////// CA1 input //////////////////////////////////
            wrreg(ADDR_CRA, 8'h04);     // CA1 interrupt disabled
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h04) begin     // check that IRQA1/A2 are clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);             // No IRQ but..
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h84) begin     // IRQA1 should be set!
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // Clear IRQA1
            @(posedge clk);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h04) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            if (d8 !== 8'h04) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end

            wrreg(ADDR_CRA, 8'h05);     // CA1 negative transition
            ca1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h85) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h05) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);

            wrreg(ADDR_CRA, 8'h07);     // CA1 positive transition
            ca1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            ca1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h87) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h07) begin
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end

            //////////////// CA2 input //////////////////////////////////
            wrreg(ADDR_CRA, 8'h04);     // CA2 interrupt disabled.
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h04) begin     // check that IRQA1/A2 are clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);             // no interrupt but...
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h44) begin     // check that IRQA2 is set
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // clear interrupt
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h04) begin     // check that IRQA2 is clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca2_in <= 1;
            repeat (4) @(posedge clk);
            if (d8 !== 8'h04) begin     // check that IRQA2 is clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            checkirq(1'b0);

            wrreg(ADDR_CRA, 8'h0c);     // CA2 input negative transition
            ca2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h4c) begin     // check that IRQA2 is set
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // clear interrupt.
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h0c) begin     // check that IRQA2 is clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            ca2_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);


            wrreg(ADDR_CRA, 8'h1c);     // CA2 input positive transition
            ca2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            ca2_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h5c) begin     // check IRQA2 is set
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h1c) begin     // check IRQA2 is clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end

            ////////////////////// CA2 output /////////////////////////
            // CA2 set high on active transition of CA1 and set low
            // by reading PORTA.

            wrreg(ADDR_CRA, 8'h24); // CA1 active transition is negative
            if (ca2_out !== 1'b0) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end
            ca1_in <= 0;
            repeat (4) @(posedge clk);
            if (ca2_out !== 1'b1) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end
            checkirq(1'b0);
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'ha4) begin // IRQA1 should be set
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);  // Clear IRQA1 and CA2 out
            repeat (4) @(posedge clk);
            if (ca2_out !== 1'b0) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end
            rdreg(ADDR_CRA, d8);
            if (d8 !== 8'h24) begin // IRQA1 should be clear
                $display("[%t] Unexpected CRA value: %h", $time, d8);
                $stop;
            end

            // CA2 pulses low one cycle after PORTA is read.
            wrreg(ADDR_CRA, 8'h2c);
            repeat (4) @(posedge clk);
            if (ca2_out !== 1'b1) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end
            rdreg(ADDR_PORTA, d8);      // should pulse CA2 out negative
            // XXX: Check for pulse in here somehow but it's not implemented.
            // The pia will need the "slow clock" so that the pulse is 1us
            // instead of clk period.
            repeat (10) @(posedge clk);
            if (ca2_out !== 1'b1) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end

            wrreg(ADDR_CRA, 8'h34);     // CA2 manual low
            repeat (2) @(posedge clk);
            if (ca2_out !== 1'b0) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end

            wrreg(ADDR_CRA, 8'h3c);     // CA2 manual high
            repeat (2) @(posedge clk);
            if (ca2_out !== 1'b1) begin
                $display("[%t] Unexpected ca2_out=%b", $time, ca2_out);
                $stop;
            end

            wrreg(ADDR_CRA, 8'h04);
        end
    endtask // porta_tests

    task portb_tests;
        begin
            /////////////////// Port B Tests ///////////////////////////////
            $display("[%t] PORT B Tests....", $time);
            wrreg(ADDR_CRB, 8'h00);
            wrreg(ADDR_PORTB, 8'hff);   // DDRB
            wrreg(ADDR_CRB, 8'h04);
            wrreg(ADDR_PORTB, 8'h55);
            if (portb_out !== 8'h55) begin
                $display("[%t] Unexpected: portb_out=%h", $time, portb_out);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);
            if (d8 !== 8'h55) begin
                $display("[%t] Unexpected: PORTB reg reads %h", $time, d8);
                $stop;
            end
            wrreg(ADDR_PORTB, 8'haa);
            if (portb_out !== 8'haa) begin
                $display("[%t] Unexpected: portb_out=%h", $time, portb_out);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);
            if (d8 !== 8'haa) begin
                $display("[%t] Unexpected: PORTB reg reads %h", $time, d8);
                $stop;
            end
            portb_in <= 8'h55;
            @(posedge clk);
            wrreg(ADDR_CRB, 8'h00);
            wrreg(ADDR_PORTB, 8'hf0);       // DDRB
            wrreg(ADDR_CRB, 8'h04);
            rdreg(ADDR_PORTB, d8);
            if (d8 !== 8'ha5) begin
                $display("[%t] Unexpected: PORTB reg reads %h", $time, d8);
                $stop;
            end
            wrreg(ADDR_CRB, 8'h00);
            wrreg(ADDR_PORTB, 8'h00);       // DDRB
            wrreg(ADDR_CRB, 8'h04);
            rdreg(ADDR_PORTB, d8);
            if (d8 !== 8'h55) begin
                $display("[%t] Unexpected: PORTB reg reads %h", $time, d8);
                $stop;
            end
            portb_in <= 8'haa;
            @(posedge clk);
            rdreg(ADDR_PORTB, d8);
            if (d8 !== 8'haa) begin
                $display("[%t] Unexpected: PORTB reg reads %h", $time, d8);
                $stop;
            end

            /////////////// CB1 input //////////////////////////////////
            wrreg(ADDR_CRB, 8'h04);     // CB1 interrupt disabled
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h04) begin     // check that IRQB1/B2 are clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);             // No IRQ but..
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h84) begin     // IRQB1 should be set!
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // Clear IRQB1
            @(posedge clk);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h04) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            if (d8 !== 8'h04) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end

            wrreg(ADDR_CRB, 8'h05);     // CB1 negative transition
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h85) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h05) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);

            wrreg(ADDR_CRB, 8'h07);     // CB1 positive transition
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            cb1_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h87) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h07) begin
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end

            //////////////// CB2 input //////////////////////////////////
            wrreg(ADDR_CRB, 8'h04);     // CB2 interrupt disabled.
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h04) begin     // check that IRQB1/B2 are clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);             // no interrupt but...
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h44) begin     // check that IRQB2 is set
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // clear interrupt
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h04) begin     // check that IRQB2 is clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb2_in <= 1;
            repeat (4) @(posedge clk);
            if (d8 !== 8'h04) begin     // check that IRQB2 is clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            checkirq(1'b0);

            wrreg(ADDR_CRB, 8'h0c);     // CB2 input negative transition
            cb2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h4c) begin     // check that IRQB2 is set
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // clear interrupt.
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h0c) begin     // check that IRQB2 is clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb2_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b0);


            wrreg(ADDR_CRB, 8'h1c);     // CB2 input positive transition
            cb2_in <= 0;
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            cb2_in <= 1;
            repeat (4) @(posedge clk);
            checkirq(1'b1);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h5c) begin     // check IRQB2 is set
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            rdreg(ADDR_PORTB, d8);      // clear interrupt
            @(posedge clk);
            checkirq(1'b0);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h1c) begin     // check IRQB2 is clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end

            ////////////////////// CB2 output /////////////////////////
            // CB2 is set low by a write PORTB and is set high by an
            // active transition on CB1.

            wrreg(ADDR_CRB, 8'h24); // CB1 active transition is negative
            repeat (4) @(posedge clk);
            if (cb2_out !== 1'b1) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end
            wrreg(ADDR_PORTB, 8'h88);   // This sets CB2 low
            repeat (4) @(posedge clk);
            checkirq(1'b0);
            if (cb2_out !== 1'b0) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'h24) begin     // IRQB1 should be clear
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end
            cb1_in <= 0;
            repeat (4) @(posedge clk);
            if (cb2_out !== 1'b1) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end
            checkirq(1'b0);
            rdreg(ADDR_CRB, d8);
            if (d8 !== 8'ha4) begin     // IRQB1 should be set
                $display("[%t] Unexpected CRB value: %h", $time, d8);
                $stop;
            end

            // CB2 pulses low one cycle after PORTB is read.
            wrreg(ADDR_CRB, 8'h2c);
            repeat (4) @(posedge clk);
            if (cb2_out !== 1'b1) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end
            wrreg(ADDR_PORTB, 8'h99);       // should pulse CB2 out negative
            // XXX: Check for pulse in here somehow.  Although implemented,
            // the pia needs to have a "slow clock" so that the pulse is
            // 1us instead of one system clock period.
            repeat (10) @(posedge clk);
            if (cb2_out !== 1'b1) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end

            wrreg(ADDR_CRB, 8'h34);     // CB2 manual low
            repeat (2) @(posedge clk);
            if (cb2_out !== 1'b0) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end

            wrreg(ADDR_CRB, 8'h3c);     // CB2 manual high
            repeat (2) @(posedge clk);
            if (cb2_out !== 1'b1) begin
                $display("[%t] Unexpected cb2_out=%b", $time, cb2_out);
                $stop;
            end

            wrreg(ADDR_CRB, 8'h04);
        end
    endtask // portb_tests

    initial begin
        @(negedge reset);
        repeat (10) @(posedge clk);

        porta_tests;
        portb_tests;

        // Done!
        repeat (20) @(posedge clk);
        $display("[%t] TEST DONE!", $time);
        $finish;
    end

endmodule // test_pia6520
