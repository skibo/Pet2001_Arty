`timescale 1ns / 1ps
//
// simtop.v
//
//      Simulate top module for Pet2001_Arty.
//
module testPet2001_Arty;

    reg [2:0]  SW;
    reg        BTN;
    wire [1:0] CVID;
    reg        UART_TXD_IN;
    wire       UART_RXD_OUT;
    wire       LED;
    reg        CLK100;

    initial begin
        SW = 3'b000;
        BTN = 1'b0;
        UART_TXD_IN = 1'b1;
        CLK100 = 1'b0;
    end

    always #5.0 CLK100 = ~CLK100; // outboard clock 100Mhz

    // DUT
    Pet2001_Arty dut(.SW(SW),
                     .BTN(BTN),
                     .CVID(CVID),
                     .LED(LED),
                     .UART_TXD_IN(UART_TXD_IN),
                     .UART_RXD_OUT(UART_RXD_OUT),
                     .CLK(CLK100)
                  );
    
endmodule // testPet2001_Arty
