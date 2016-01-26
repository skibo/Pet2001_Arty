`timescale 1ns / 1ps
//
// pet2001uart_keys.v
//
//      Convert UART input into PET key presses.
//
// Copyright (c) 2015 Thomas Skibo.
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

module pet2001uart_keys(input [3:0]  keyrow,
                        output [7:0] keyin,

                        input [7:0]  uart_data,
                        input        uart_strobe,

                        input        clk,
                        input        reset
                   );

    reg         clr_key;
    reg [3:0]   pressed_row;
    reg [3:0]   pressed_col;

    reg [3:0]   ascii_row;
    reg [3:0]   ascii_col;

    // Convert ASCII to row/col   XXX: use some sort of memory lookup?
    function [7:0] ascii_lookup(input [7:0] c);
        begin
            case (c)
                8'h03: ascii_lookup = {4'd9,4'd4}; // ''
        8'h04: ascii_lookup = {4'd8,4'd0}; // ''
        8'h08: ascii_lookup = {4'd1,4'd7}; // ''
        8'h0d: ascii_lookup = {4'd6,4'd5}; // ''
        8'h11: ascii_lookup = {4'd1,4'd6}; // ''
        8'h12: ascii_lookup = {4'd9,4'd0}; // ''
        8'h13: ascii_lookup = {4'd0,4'd6}; // ''
        8'h1d: ascii_lookup = {4'd0,4'd7}; // ''
        8'h20: ascii_lookup = {4'd9,4'd2}; // ' '
        8'h21: ascii_lookup = {4'd0,4'd0}; // '!'
        8'h22: ascii_lookup = {4'd1,4'd0}; // '"'
        8'h23: ascii_lookup = {4'd0,4'd1}; // '#'
        8'h24: ascii_lookup = {4'd1,4'd1}; // '$'
        8'h25: ascii_lookup = {4'd0,4'd2}; // '%'
        8'h26: ascii_lookup = {4'd0,4'd3}; // '&'
        8'h27: ascii_lookup = {4'd1,4'd2}; // '''
        8'h28: ascii_lookup = {4'd0,4'd4}; // '('
        8'h29: ascii_lookup = {4'd1,4'd4}; // ')'
        8'h2a: ascii_lookup = {4'd5,4'd7}; // '*'
        8'h2b: ascii_lookup = {4'd7,4'd7}; // '+'
        8'h2c: ascii_lookup = {4'd7,4'd3}; // ','
        8'h2d: ascii_lookup = {4'd8,4'd7}; // '-'
        8'h2e: ascii_lookup = {4'd9,4'd6}; // '.'
        8'h2f: ascii_lookup = {4'd3,4'd7}; // '/'
        8'h30: ascii_lookup = {4'd8,4'd6}; // '0'
        8'h31: ascii_lookup = {4'd6,4'd6}; // '1'
        8'h32: ascii_lookup = {4'd7,4'd6}; // '2'
        8'h33: ascii_lookup = {4'd6,4'd7}; // '3'
        8'h34: ascii_lookup = {4'd4,4'd6}; // '4'
        8'h35: ascii_lookup = {4'd5,4'd6}; // '5'
        8'h36: ascii_lookup = {4'd4,4'd7}; // '6'
        8'h37: ascii_lookup = {4'd2,4'd6}; // '7'
        8'h38: ascii_lookup = {4'd3,4'd6}; // '8'
        8'h39: ascii_lookup = {4'd2,4'd7}; // '9'
        8'h3a: ascii_lookup = {4'd5,4'd4}; // ':'
        8'h3b: ascii_lookup = {4'd6,4'd4}; // ';'
        8'h3c: ascii_lookup = {4'd9,4'd3}; // '<'
        8'h3d: ascii_lookup = {4'd9,4'd7}; // '='
        8'h3e: ascii_lookup = {4'd8,4'd4}; // '>'
        8'h3f: ascii_lookup = {4'd7,4'd4}; // '?'
        8'h40: ascii_lookup = {4'd8,4'd1}; // '@'
        8'h41: ascii_lookup = {4'd4,4'd0}; // 'A'
        8'h42: ascii_lookup = {4'd6,4'd2}; // 'B'
        8'h43: ascii_lookup = {4'd6,4'd1}; // 'C'
        8'h44: ascii_lookup = {4'd4,4'd1}; // 'D'
        8'h45: ascii_lookup = {4'd2,4'd1}; // 'E'
        8'h46: ascii_lookup = {4'd5,4'd1}; // 'F'
        8'h47: ascii_lookup = {4'd4,4'd2}; // 'G'
        8'h48: ascii_lookup = {4'd5,4'd2}; // 'H'
        8'h49: ascii_lookup = {4'd3,4'd3}; // 'I'
        8'h4a: ascii_lookup = {4'd4,4'd3}; // 'J'
        8'h4b: ascii_lookup = {4'd5,4'd3}; // 'K'
        8'h4c: ascii_lookup = {4'd4,4'd4}; // 'L'
        8'h4d: ascii_lookup = {4'd6,4'd3}; // 'M'
        8'h4e: ascii_lookup = {4'd7,4'd2}; // 'N'
        8'h4f: ascii_lookup = {4'd2,4'd4}; // 'O'
        8'h50: ascii_lookup = {4'd3,4'd4}; // 'P'
        8'h51: ascii_lookup = {4'd2,4'd0}; // 'Q'
        8'h52: ascii_lookup = {4'd3,4'd1}; // 'R'
        8'h53: ascii_lookup = {4'd5,4'd0}; // 'S'
        8'h54: ascii_lookup = {4'd2,4'd2}; // 'T'
        8'h55: ascii_lookup = {4'd2,4'd3}; // 'U'
        8'h56: ascii_lookup = {4'd7,4'd1}; // 'V'
        8'h57: ascii_lookup = {4'd3,4'd0}; // 'W'
        8'h58: ascii_lookup = {4'd7,4'd0}; // 'X'
        8'h59: ascii_lookup = {4'd3,4'd2}; // 'Y'
        8'h5a: ascii_lookup = {4'd6,4'd0}; // 'Z'
        8'h5b: ascii_lookup = {4'd9,4'd1}; // '['
        8'h5c: ascii_lookup = {4'd1,4'd3}; // '\'
        8'h5d: ascii_lookup = {4'd8,4'd2}; // ']'
        8'h5e: ascii_lookup = {4'd2,4'd5}; // '^'
        8'h5f: ascii_lookup = {4'd0,4'd5}; // '_'
        8'h61: ascii_lookup = {4'd4,4'd0}; // 'a'
        8'h62: ascii_lookup = {4'd6,4'd2}; // 'b'
        8'h63: ascii_lookup = {4'd6,4'd1}; // 'c'
        8'h64: ascii_lookup = {4'd4,4'd1}; // 'd'
        8'h65: ascii_lookup = {4'd2,4'd1}; // 'e'
        8'h66: ascii_lookup = {4'd5,4'd1}; // 'f'
        8'h67: ascii_lookup = {4'd4,4'd2}; // 'g'
        8'h68: ascii_lookup = {4'd5,4'd2}; // 'h'
        8'h69: ascii_lookup = {4'd3,4'd3}; // 'i'
        8'h6a: ascii_lookup = {4'd4,4'd3}; // 'j'
        8'h6b: ascii_lookup = {4'd5,4'd3}; // 'k'
        8'h6c: ascii_lookup = {4'd4,4'd4}; // 'l'
        8'h6d: ascii_lookup = {4'd6,4'd3}; // 'm'
        8'h6e: ascii_lookup = {4'd7,4'd2}; // 'n'
        8'h6f: ascii_lookup = {4'd2,4'd4}; // 'o'
        8'h70: ascii_lookup = {4'd3,4'd4}; // 'p'
        8'h71: ascii_lookup = {4'd2,4'd0}; // 'q'
        8'h72: ascii_lookup = {4'd3,4'd1}; // 'r'
        8'h73: ascii_lookup = {4'd5,4'd0}; // 's'
        8'h74: ascii_lookup = {4'd2,4'd2}; // 't'
        8'h75: ascii_lookup = {4'd2,4'd3}; // 'u'
        8'h76: ascii_lookup = {4'd7,4'd1}; // 'v'
        8'h77: ascii_lookup = {4'd3,4'd0}; // 'w'
        8'h78: ascii_lookup = {4'd7,4'd0}; // 'x'
        8'h79: ascii_lookup = {4'd3,4'd2}; // 'y'
        8'h7a: ascii_lookup = {4'd6,4'd0}; // 'z'
                default: ascii_lookup = 8'hXX;
            endcase // case (c)
        end
    endfunction // ascii_lookup
    
    wire [7:0]  ascii_rowcol = ascii_lookup(uart_data);
    always @(posedge clk) begin
        ascii_row <= ascii_rowcol[7:4];
        ascii_col <= ascii_rowcol[3:0];
    end
    
    // Only one key at a time is pressed.  When a UART strobe comes in,
    // the key's row and column (on a PET) is latched and released after
    // a 10ms timeout.
    reg         uart_strobe_1;

    always @(posedge clk)
        if (reset)
            uart_strobe_1 <= 1'b0;
        else
            uart_strobe_1 <= uart_strobe;

    always @(posedge clk)
        if (reset || clr_key)
            pressed_row <= 4'hf;
        else if (uart_strobe_1)
            pressed_row <= ascii_row;

    always @(posedge clk)
        if (reset || clr_key)
            pressed_col <= 4'hf;
        else if (uart_strobe_1)
            pressed_col <= ascii_col;

    // Implement a 10ms timer
    reg [21:0]  keytimeout;
    always @(posedge clk)
        if (reset)
            keytimeout <= 22'd0;
        else if (uart_strobe)
            keytimeout <= 22'd2500000; // 50ms assuming 50Mhz clock.
        else
            keytimeout <= keytimeout - 1'd1;

    always @(posedge clk)
        if (reset)
            clr_key <= 1'b0;
        else
            clr_key <= (keytimeout == 19'd0);

    // Generate keyin
    assign keyin = ~(keyrow == pressed_row ? (8'd1 << pressed_col) : 8'h00);
    
endmodule // pet2001uart_keys
