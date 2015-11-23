`timescale 1ns / 1ps

//
// sim_petkeys.v
//
//	Simulate pet2001uart_keys block.
//

module testPetKeys;

    reg [3:0]  keyrow;
    wire [7:0] keyin;
    reg [7:0]  uart_data;
    reg        uart_strobe;
    reg        clk;
    reg        reset;

    initial begin
        keyrow = 4'hf;
        uart_data = 8'd0;
        uart_strobe = 1'b0;
        clk = 1'b0;
        reset = 1'b1;
    end
    
    always #10.0 clk = ~clk;	// 50Mhz

    // Wait a few clocks, release reset, a few more clocks, strobe '^D'.
    initial begin
        repeat (20) @(posedge clk);
        reset <= 1'b0;
        repeat (100) @(posedge clk);
        uart_data <= 8'h0d;
        uart_strobe <= 1'b1;
        @(posedge clk);
        uart_strobe <= 1'b0;
    end

    // Scan keyrows much like a PET would.
    always @(posedge clk) begin
        if (keyrow == 4'd9)
            keyrow <= 4'd0;
        else
            keyrow <= keyrow + 1'b1;
        repeat (20) @(posedge clk);
    end

    // DUT
    pet2001uart_keys pet2001uart_keys_0(
		                        .keyrow(keyrow),
		                        .keyin(keyin),
		                        .uart_data(uart_data),
		                        .uart_strobe(uart_strobe),
		                        .clk(clk),
		                        .reset(reset)
                              );
    
endmodule // testPetKeys
