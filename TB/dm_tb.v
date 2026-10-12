`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:47:09
// Design Name: 
// Module Name: dm_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dm_tb;
    reg clk, sw, lb;
    reg [31:0] mem_addr, write_data;
    wire [31:0] read_data;

    data_memory uut (
        .clk(clk), .mem_addr(mem_addr), .write_data(write_data),
        .sw(sw), .lb(lb), .read_data(read_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; sw = 0; lb = 0; mem_addr = 0; write_data = 0;
        #10;

        // Store Word into memory address 4 (aligned word index 1)
        @(posedge clk);
        mem_addr = 32'd4; write_data = 32'h80706050; sw = 1;
        @(posedge clk);
        sw = 0;

        // Test normal word read
        mem_addr = 32'd4;
        #1; $display("[MEM WORD READ] Data: %h (Expected: 80706050)", read_data);

        // Test load byte signed extension reading the highest byte (negative sign)
        lb = 1; mem_addr = 32'd7; // Address 7 targets byte offset 3 (Value: 80)
        #1; $display("[MEM BYTE READ] Sign Extended: %h (Expected: ffffff80)", read_data);

        $finish;
    end
endmodule

