`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// uart_rx - receives one byte, 8N1 (1 start bit, 8 data bits LSB first, 1 stop bit)
// CLKS_PER_BIT = clock frequency / baud rate
// valid is a one cycle pulse when data holds a new byte.
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input reset,
    input rx,                 // serial line, idles high
    output reg [7:0] data,
    output reg valid
);
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam BITS  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state = IDLE;
    reg [15:0] count = 0;     // clock cycles inside the current bit
    reg [2:0]  bit_index = 0;
    reg rx_meta = 1'b1, rx_sync = 1'b1;   // two flip-flops: rx comes from outside the FPGA

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
        valid   <= 1'b0;

        if (reset) begin
            state <= IDLE;
            count <= 0;
            bit_index <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    count <= 0;
                    if (rx_sync == 1'b0) state <= START;   // falling edge = start bit
                end

                START: begin
                    // check again in the middle of the start bit (ignore short glitches)
                    if (count == CLKS_PER_BIT / 2 - 1) begin
                        count <= 0;
                        bit_index <= 0;
                        if (rx_sync == 1'b0) state <= BITS;
                        else                 state <= IDLE;
                    end
                    else count <= count + 1'b1;
                end

                BITS: begin
                    // one full bit later = middle of the next data bit
                    if (count == CLKS_PER_BIT - 1) begin
                        count <= 0;
                        data[bit_index] <= rx_sync;
                        if (bit_index == 3'd7) state <= STOP;
                        else                   bit_index <= bit_index + 1'b1;
                    end
                    else count <= count + 1'b1;
                end

                STOP: begin
                    if (count == CLKS_PER_BIT - 1) begin
                        count <= 0;
                        state <= IDLE;
                        if (rx_sync == 1'b1) valid <= 1'b1;   // bad stop bit -> byte dropped
                    end
                    else count <= count + 1'b1;
                end
            endcase
        end
    end
endmodule
