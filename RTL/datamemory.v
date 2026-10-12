`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:20:07
// Design Name: 
// Module Name: datamemory
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


module data_memory(
    input clk,
    input [31:0] mem_addr,       // Address from ALU
    input [31:0] write_data,     // Data to store (from register memory)
    input sw,                    // Store Word control
    input lb,                    // Load Byte control
    output reg [31:0] read_data  // Output data back to register memory
);

    // RAM array: 64 words of 32-bit memory
    reg [31:0] ram [63:0];
    
    // Explicit tracking wires/registers
    wire [5:0] word_addr;
    wire [1:0] byte_offset;
    reg [7:0] selected_byte;

    // Direct bit-slicing for addresses
    assign word_addr = mem_addr[7:2];    
    assign byte_offset = mem_addr[1:0];  

    // --- Synchronous Write Block ---
    always @(posedge clk) begin
        if (sw) begin
            ram[word_addr] <= write_data; // Pure register store
        end
    end

    // --- Combinational Read & Manual Sign Extension Block ---
    always @(*) begin
        // 1. Manual byte decoding using explicit if-else
        if (byte_offset == 2'b00) begin
            selected_byte = ram[word_addr][7:0];
        end
        else if (byte_offset == 2'b01) begin
            selected_byte = ram[word_addr][15:8];
        end
        else if (byte_offset == 2'b10) begin
            selected_byte = ram[word_addr][23:16];
        end
        else begin
            selected_byte = ram[word_addr][31:24];
        end

        // 2. Manual Sign Extension based on the 7th bit of the byte
        if (lb) begin
            if (selected_byte[7] == 1'b1) begin
                // If negative, pad with 24 ones manually
                read_data = {24'hFFFFFF, selected_byte};
            end
            else begin
                // If positive, pad with 24 zeros manually
                read_data = {24'h000000, selected_byte};
            end
        end
        else begin
            // Normal word read
            read_data = ram[word_addr];
        end
    end

endmodule


