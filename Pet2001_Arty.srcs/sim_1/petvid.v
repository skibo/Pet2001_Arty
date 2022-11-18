`timescale 1ns / 1ps
////////////////
//
// petvid.v
//
//  Incomplete and crude simulation of Commodore PET video logic.  I hastily
//  coded these models for 7400-series TTL chips and so they should not be
//  relied upon as accurate!
//
//  This simulation is derived from the PET schematic found at:
// ftp://www.zimmers.net/pub/cbm/firmware/computers/pet/schematics/2001/320008-3.gif
//
//  Except for signals and buses that are named on the schematic, node
//  names correspond to the chip name and pin number that drives the node.
//
//  Note: I know putting all these modules into one file is bad form.  It's
//  just a hack.
//
////////////////

//
// Copyright (c) 2015, 2017, 2022  Thomas Skibo. <ThomasSkibo@yahoo.com>
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

// Half a 74107
module jk(output reg q,
          output q_,
          input  j,
          input  k,
          input  c_,
          input  clk);

    initial
        q = 0;

    always @(negedge c_)
        q <= 1'b0;

    always @(negedge clk)
        if (c_)
            case ({j,k})
                2'b00: ;
                2'b01: q <= 0;
                2'b10: q <= 1'b1;
                2'b11: q <= ~q;
            endcase

    assign q_ = ~q;
endmodule

// 7493 4-bit binary counters
module c7493(output reg qa, // pin 12
             output reg qb, // pin 9
             output reg qc, // pin 8
             output reg qd, // pin 11
             input r01,     // pin 2
             input r02,     // pin 3
             input cka,     // pin 14
             input ckb);    // pin 1

    initial begin
        qa = 0;
        qb = 0;
        qc = 0;
        qd = 0;
    end

    always @(*)
        if (r01 && r02)
            {qd, qc, qb, qa} = 4'b0000;

    always @(negedge cka)
        if (!r01 || !r02)
            qa <= ~qa;

    always @(negedge ckb)
        if (!r01 || !r02)
            {qd, qc, qb} <= {qd, qc, qb} + 1'b1;

endmodule // c7493

// 74100 latches
module l74100(output reg q1,
              output reg q2,
              output reg q3,
              output reg q4,
              output reg q5,
              output reg q6,
              output reg q7,
              output reg q8,
              input      d1,
              input      d2,
              input      d3,
              input      d4,
              input      d5,
              input      d6,
              input      d7,
              input      d8,
              input      g1,
              input      g2);

    initial begin
        q1 = 1'b0;
        q2 = 1'b0;
        q3 = 1'b0;
        q4 = 1'b0;
        q5 = 1'b0;
        q6 = 1'b0;
        q7 = 1'b0;
        q8 = 1'b0;
    end

    always @(*)
        if (g1)
            {q4, q3, q2, q1} = {d4, d3, d2, d1};

    always @(*)
        if (g2)
            {q8, q7, q6, q5} = {d8, d7, d6, d5};

endmodule // l74100

// 74177 presettable decade and binary counters/latches
module c74177(output reg qa,    // pin 5
              output reg qb,    // pin 9
              output reg qc,    // pin 3
              output reg qd,    // pin 12
              input      a,     // pin 4
              input      b,     // pin 10
              input      c,     // pin 3
              input      d,     // pin 11
              input      load_, // pin 1
              input      clr_,  // pin 13
              input      clk1,  // pin 8
              input      clk2); // pin 6

    initial begin
        qa = 1'b0;
        qb = 1'b0;
        qc = 1'b0;
        qd = 1'b0;
    end

    always @(negedge load_)
        if (!load_ && clr_)
            {qa, qb, qc, qd} <= {a, b, c, d};

    always @(negedge clr_)
        if (!clr_)
            {qa, qb, qc, qd} <= 4'b0000;

    always @(negedge clk1)
        if (load_ && clr_)
            qa <= ~qa;

    always @(negedge clk2)
        if (load_ && clr_)
            {qd, qc, qb} <= {qd, qc, qb} + 1'b1;

endmodule // c74177

// Half a 7474 D-type flip flop
module h7474(output reg q,
             output q_,
             input d,
             input pre_,
             input clr_,
             input clk);

    always @(negedge pre_ or negedge clr_ or posedge clk)
        if (!pre_ && !clr_)
            q <= 1'bX;
        else if (!pre_)
            q <= 1'b1;
        else if (!clr_)
            q <= 1'b0;
        else
            q <= d;

    assign q_ = ~q;

endmodule // h7474

// Character ROM (not including chip selects 1-5).
module c6540(output reg [7:0]   D,
             input [10:0]       A,
             input              clk);

    reg [7:0]   mem[2047:0];
    initial $readmemh("charrom.mem", mem);

    always @(posedge clk)
        D <= mem[A];

endmodule // c6540

// 74157 quad 2-line to 1-line data selectors/multiplexors.
module c74157(output [3:0] Y,
              input [3:0] A,
              input [3:0] B,
              input       S,
              input       G_);

    assign Y = (A & {4{!S && !G_}}) | (B & {4{S && !G_}});

endmodule // c74157

// 74165 8-bit shift register.
module c74165(output      q,
              output      q_,
              input [7:0] D, // HGFEDCBA on data sheet
              input       ld_,
              input       clk_inh,
              input       ser,
              input       clk);

    reg [7:0]   sr;

    always @(negedge ld_ or D)
        if (!ld_)
            sr <= D;

    always @(posedge clk)
        if (ld_ && !clk_inh)
            sr <= {sr[6:0], ser};

    assign q = sr[7];
    assign q_ = ~sr[7];

endmodule // c74165

// Half a 74LS244 octal 3-state buffer
module h74244(output [3:0] Y,
              input [3:0]  A,
              input        G_);
    assign Y = G_ ? 4'bZZZZ : A;
endmodule // h74244

// 6550 * 2, Video RAMs
module c6550s(output [7:0] DB,
              input [9:0]  A,
              input        RW,
              input        clk);

    reg [7:0]   mem[1023:0];

    always @(posedge clk)
        if (!RW)
            mem[A] <= DB;

    assign DB = RW ? mem[A] : 8'hZZ;

endmodule // c6550s

// Top module.
module petvid;

    // 8 Mhz clock generation.
    reg     clk8mhz;
    initial clk8mhz = 1'b0;
    always #62.5 clk8mhz = ~clk8mhz;

    // External signals
    reg [9:0]   BA;     // address from other schematic page
    wire [7:0]  BD;     // data to/from other schematic page
    reg [7:0]   wrdata; // for simulating video RAM writes.
    reg         sel8;   // signal from right on page, address select video ram
    reg         rnw_ne; // signal from right on page, read/write_ video ram
    reg         graphic; // controls character set, from VIA.lCA2
    reg         blanktv; // set low to turn off video, from PIA1.CA2.
    initial begin
        BA = 10'bxx_xxxx_xxxx;
        sel8 = 0;
        rnw_ne = 1;
        graphic = 0;
        blanktv = 1;
    end

    // Drive BD from processor board.
    assign BD = (sel8 && !rnw_ne) ? wrdata : 8'hZZ;

    // Task to emulate cpu writing video memory.
    task wrmem(input [9:0] a,
               input [7:0] d);
        begin
            @(negedge phi2);
            BA <= a;
            wrdata = d;
            sel8 <= 1;

            @(negedge phi2);
            rnw_ne <= 0;

            @(negedge phi2);
            BA <= 10'bxx_xxxx_xxxx;
            sel8 <= 0;
            rnw_ne <= 1;

            @(posedge phi2);
        end
    endtask

    // Task to emulate cpu reading video memory.  Data ignored.
    task rdmem(input [9:0] a);
        begin
            @(negedge phi2);
            BA <= a;
            sel8 <= 1;

            @(negedge phi2);
            BA <= 10'bxx_xxxx_xxxx;
            sel8 <= 0;

            @(posedge phi2);
        end
    endtask

    initial begin:clrscrn
        integer i;

        repeat (3000) @(posedge phi0);

        // Emulate cpu clearing screen and writing opening banner.
        @(posedge phi0);
        blanktv <= 0;

        for (i = 0; i < 1024; i = i + 1)
            wrmem(10'd000 + i, 8'h20);

        blanktv <= 1;

        // Time these writes to see snow effect.
        repeat (1000) @(posedge phi0);

        wrmem(10'h000, 8'h2a);  // *
        wrmem(10'h001, 8'h2a);  // *
        wrmem(10'h002, 8'h2a);  // *
        wrmem(10'h004, 8'h03);  // C
        wrmem(10'h005, 8'h0f);  // O
        wrmem(10'h006, 8'h0d);  // M
        wrmem(10'h007, 8'h0d);  // M
        wrmem(10'h008, 8'h0f);  // O
        wrmem(10'h009, 8'h04);  // D
        wrmem(10'h00a, 8'h0f);  // O
        wrmem(10'h00b, 8'h12);  // R
        wrmem(10'h00c, 8'h05);  // E
        wrmem(10'h00e, 8'h02);  // B
        wrmem(10'h00f, 8'h01);  // A
        wrmem(10'h010, 8'h13);  // S
        wrmem(10'h011, 8'h09);  // I
        wrmem(10'h012, 8'h03);  // C
        wrmem(10'h014, 8'h2a);  // *
        wrmem(10'h015, 8'h2a);  // *
        wrmem(10'h016, 8'h2a);  // *

        // This read creates snow effect too.
        repeat (100) @(posedge phi0);
        rdmem(10'h016);
    end

    // clock is output of E2 pin 6 (AND)
    wire        e2_6 = clk8mhz;
    wire        tp3_2 = 1'b1;
    wire        d9_6 = !tp3_2;

    // Nets are named after their driver.
    wire        c9_8, c9_11, c9_12;
    wire        d9_4 = !c9_11;

    wire        c8_2, c8_3;
    wire        d8_8 = !(e2_6 && c8_3); // NAND at D8

    wire        c8_5, phi0;
    wire        phi1 = !phi0; // XXX: just an approximation of phi1 and phi2
    wire        phi2 = phi0;
    wire        bphi2 = phi2; // "buffered phi2", looks like B02 on schematic.

    wire        c7_2, c7_3;

    wire        b6_2, b6_3, b6_5, b6_6;
    wire        tp3_4 = 1'b1;

    wire        b5_8, b5_9, b5_11, b5_12;

    wire        c5_2;
    wire        dis_on, dis_off;
    wire        tp3_1 = 1'b1;

    wire        c7_5, c7_6;
    wire        c6_6 = b5_8 && c7_5; // AND at C6
    wire        c6_3 = b5_11 && c7_6; // AND at C6

    wire        d5_3, d5_5;
    wire        d6_5, d6_9, d6_2, d6_12;
    wire        d7_5, d7_9, d7_2, d7_12;
    wire        d8_3, d8_6;

    wire        c6_11 = dis_off && d8_6; // AND at C6

    wire        e6_5, e6_4, e6_19, e6_20;
    wire        e6_8, e6_9, e6_18, e6_17;
    wire        e8_6, e8_8;

    wire        a1_9, a1_8, a1_11;
    wire        b1_8 = !(a1_9 && a1_8 && a1_11 && dis_on);  // NAND B1

    wire        c2_8 = !(c7_2 && b1_8); // NAND

    wire        c2_11 = !(sel8 && rnw_ne); // NAND

    wire [9:0]  SA;
    wire        d2_7, d2_4; // d2_4 is a no-connect
    wire [7:0]  SD;

    wire        c1_5, c1_8, c1_9;

    wire        b2_9, b2_7;
    wire [7:0]  charromd;
    wire        c2_3 = !(b2_9 && c1_9);     // NAND
    wire        c2_6 = !(b2_7 && c1_8);     // NAND
    wire        e2_3 = (c2_6 && c2_3);      // OR with inverted inputs XXX

    wire        vert_drive = !(b6_6 && b6_2); // NAND at D8_11
    wire        horz_drive = c5_2;
    wire        sync = b6_5 && b6_3;    // AND at C6_8, also called video_on

    // Big NAND at E9
    wire        video_drive = !(sync && blanktv && e2_3 && dis_on);

    // This bus does not appear on schematic but it represents the
    // video address fed to address multiplexers.
    wire [9:0] vaddr = { d7_12, d7_2, d7_9, d7_5,
                         d6_12, d6_2, d6_9, d6_5,
                         d5_3, d5_5};

    jk b6_a(.q(b6_3),
            .q_(b6_2),
            .j(b6_6),
            .k(b6_5),
            .c_(tp3_4),
            .clk(c7_3));

    jk b6_b(.q(b6_5),
            .q_(b6_6),
            .j(b6_3),
            .k(b6_2),
            .c_(tp3_4),
            .clk(c7_3));

    // Ripple counter C9
    c7493 c9(.cka(c9_11),
             .ckb(e2_6),
             .r01(d9_6),
             .r02(d9_6),
             .qa(c9_12),
             .qb(),
             .qc(c9_8),
             .qd(c9_11));

    jk c8_a(.q(c8_3),
            .q_(c8_2),
            .j(tp3_2),
            .k(1'b0),
            .c_(d8_8),
            .clk(c9_11));

    jk c8_b(.q(c8_5),
            .q_(phi0),
            .j(c9_11),
            .k(d9_4),
            .c_(tp3_2),
            .clk(e2_6));

    jk c7_a(.q(c7_3),
            .q_(c7_2),
            .j(c6_11),
            .k(tp3_2),
            .c_(tp3_2),
            .clk(c9_8));

    // Ripple counter B5
    c7493 b5(.cka(c9_12),
             .ckb(b5_12),
             .r01(d9_6),
             .r02(d9_6),
             .qa(b5_12),
             .qb(b5_9),
             .qc(b5_8),
             .qd(b5_11));

    jk c5_a(.q(),
            .q_(c5_2),
            .j(dis_on),
            .k(dis_off),
            .c_(tp3_1),
            .clk(b5_9));

    jk c5_b(.q(dis_on),
            .q_(dis_off),
            .j(c6_6),
            .k(c6_3),
            .c_(tp3_1),
            .clk(c9_12));

    jk c7_b(.q(c7_5),
            .q_(c7_6),
            .j(tp3_2),
            .k(tp3_2),
            .c_(tp3_2),
            .clk(b5_11));

    jk d5_a(.q(d5_3),
            .q_(),
            .j(tp3_1),
            .k(tp3_1),
            .c_(dis_on),
            .clk(d5_5));

    jk d5_b(.q(d5_5),
            .q_(),
            .j(tp3_1),
            .k(tp3_1),
            .c_(dis_on),
            .clk(c8_3));

    // Counters
    c74177 d6(.qa(d6_5),
              .qb(d6_9),
              .qc(d6_2),
              .qd(d6_12),
              .a(e6_5),
              .b(e6_4),
              .c(e6_19),
              .d(e6_20),
              .load_(dis_on),
              .clr_(c7_2),
              .clk1(d5_3),  // XXX: called cl2 in schematic
              .clk2(d6_5)); // XXX: called cl1 in schematic

    c74177 d7(.qa(d7_5),
              .qb(d7_9),
              .qc(d7_2),
              .qd(d7_12),
              .a(e6_8),
              .b(e6_9),
              .c(e6_18),
              .d(e6_17),
              .load_(dis_on),
              .clr_(c7_2),
              .clk1(d6_12),   // XXX: called cl2 in schematic
              .clk2(d7_5));   // XXX: called cl1 in schematic

    l74100 e6(.q1(e6_5),
              .q2(e6_4),
              .q3(e6_19),
              .q4(e6_20),
              .q5(e6_8),
              .q6(e6_9),
              .q7(e6_18),
              .q8(e6_17),
              .d1(d6_5),
              .d2(d6_9),
              .d3(d6_2),
              .d4(d6_12),
              .d5(d7_5),
              .d6(d7_9),
              .d7(d7_2),
              .d8(d7_12),
              .g1(c2_8),
              .g2(c2_8));

    // Video RAM address MUXes
    c74157 d2(.Y({SA[1:0], d2_7, d2_4}),
              .A({d5_3, d5_5, 2'b11}),
              .B({BA[1:0], rnw_ne, 1'b1}),
              .S(sel8),
              .G_(1'b0));

    c74157 d3(.Y(SA[5:2]),
              .A({d6_12, d6_2, d6_9, d6_5}),
              .B(BA[5:2]),
              .S(sel8),
              .G_(1'b0));

    c74157 d4(.Y(SA[9:6]),
              .A({d7_12, d7_2, d7_9, d7_5}),
              .B(BA[9:6]),
              .S(sel8),
              .G_(1'b0));

    // Video data bus drivers
    h74244 b3_a(.Y(BD[3:0]),
                .A(SD[3:0]),
                .G_(c2_11));

    h74244 b3_b(.Y(SD[3:0]),
                .A(BD[3:0]),
                .G_(d2_7));

    h74244 b4_a(.Y(BD[7:4]),
                .A(SD[7:4]),
                .G_(c2_11));

    h74244 b4_b(.Y(SD[7:4]),
                .A(BD[7:4]),
                .G_(d2_7));

    h7474 c1_a(.q(c1_5),
               .q_(),
               .d(SD[7]),
               .pre_(1'b1),
               .clr_(1'b1),
               .clk(c8_5));

    h7474 c1_b(.q(c1_9),
               .q_(c1_8),
               .d(c1_5),
               .pre_(1'b1),
               .clr_(1'b1),
               .clk(c8_3));

    // Video RAM
    c6550s c3c4(.DB(SD),
                .A(SA),
                .RW(d2_7),
                .clk(bphi2));

    // Shift register for pixels
    c74165 b2(.q(b2_9),
              .q_(b2_7),
              .D(charromd),
              .ld_(c8_2),
              .clk_inh(1'b0),
              .ser(1'b0),
              .clk(clk8mhz));

    // Character ROM
    c6540 a2(.D(charromd),
             .A({graphic, SD[6:0], a1_11, a1_8, a1_9}),
             .clk(c8_5));

    // Logic at very bottom of page.
    assign        e8_6 = !(e6_8 && e6_9 && e6_18 && e6_17);
    assign        e5_10 = !e8_6;
    assign        e5_12 = !sync;
    assign        e8_8 = !(d7_5 && a1_11 && e5_12);
    assign        d8_3 = !(e6_4 && e5_10);
    assign        d8_6 = !(d8_3 && e8_8);

    c7493 a1(.qa(),
             .qb(a1_9),
             .qc(a1_8),
             .qd(a1_11),
             .r01(c7_3),
             .r02(1'b1),
             .cka(),
             .ckb(dis_on));

`ifdef MONITOR
    always @(vert_drive or horz_drive or video_drive)
        $display("[%t] MONITOR: vert_drive=%b horz_drive=%b video_drive=%b",
                 $time, vert_drive, horz_drive, video_drive);
`endif

endmodule // top
