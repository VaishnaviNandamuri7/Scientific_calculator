`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// uart_tx - sends one byte, 8N1 (1 start bit, 8 data bits LSB first, 1 stop bit)
// CLKS_PER_BIT = clock frequency / baud rate
// Give start = 1 for one cycle while busy = 0; busy stays high until the stop bit is sent.
//////////////////////////////////////////////////////////////////////////////////

module uart_tx #(
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input reset,
    input start,
    input [7:0] data,
    output reg tx = 1'b1,     // serial line, idles high
    output reg busy = 1'b0
);
    reg [9:0]  frame = 10'h3FF;   // {stop, data[7:0], start}
    reg [3:0]  bit_index = 0;
    reg [15:0] count = 0;         // clock cycles inside the current bit

    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1;
            busy <= 1'b0;
            bit_index <= 0;
            count <= 0;
        end
        else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                frame <= {1'b1, data, 1'b0};
                bit_index <= 0;
                count <= 0;
                busy <= 1'b1;
            end
        end
        else begin
            tx <= frame[bit_index];
            if (count == CLKS_PER_BIT - 1) begin
                count <= 0;
                if (bit_index == 4'd9) busy <= 1'b0;   // stop bit done
                else                   bit_index <= bit_index + 1'b1;
            end
            else count <= count + 1'b1;
        end
    end
endmodule
