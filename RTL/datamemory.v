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
    input sw,                    // Store control (high for sb, sh and sw)
    input [2:0] funct3,          // Access size and sign: [1:0] = size, [2] = unsigned load
    output reg [31:0] read_data, // Output data back to register memory
    input clear,                 // Board loader: set all 64 words to 0 (Top_RISC ties it to 0)
    input [5:0] dump_addr,       // Board loader: second read port, word index 0..63
    output [31:0] dump_data      // Board loader: word sent back over UART
);

    // RAM array: 64 words of 32-bit memory
    reg [31:0] ram [63:0];

    // Explicit tracking wires/registers
    wire [5:0] word_addr;
    wire [1:0] byte_offset;
    reg [7:0] selected_byte;
    reg [15:0] selected_half;
    integer i;

    // Direct bit-slicing for addresses
    assign word_addr = mem_addr[7:2];
    assign byte_offset = mem_addr[1:0];

    // Clear the memory at start so reads never return x
    initial begin
        for (i = 0; i < 64; i = i + 1) ram[i] = 32'd0;
    end

    // Second read port, only used by the board loader to send the results back
    assign dump_data = ram[dump_addr];

    // --- Synchronous Write Block ---
    always @(posedge clk) begin
        if (clear) begin
            // Board loader: start every run from zeros, like a fresh simulation
            for (i = 0; i < 64; i = i + 1) ram[i] <= 32'd0;
        end
        else if (sw) begin
            if (funct3[1:0] == 2'b00) begin
                // Store byte: only the selected byte changes, other 3 stay as they are
                if (byte_offset == 2'b00)      ram[word_addr][7:0]   <= write_data[7:0];
                else if (byte_offset == 2'b01) ram[word_addr][15:8]  <= write_data[7:0];
                else if (byte_offset == 2'b10) ram[word_addr][23:16] <= write_data[7:0];
                else                           ram[word_addr][31:24] <= write_data[7:0];
            end
            else if (funct3[1:0] == 2'b01) begin
                // Store half word: only the selected half changes
                if (mem_addr[1] == 1'b0) ram[word_addr][15:0]  <= write_data[15:0];
                else                     ram[word_addr][31:16] <= write_data[15:0];
            end
            else begin
                ram[word_addr] <= write_data; // Store word
            end
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

        // 2. Half word decoding, address bit 1 picks the lower or upper half
        if (mem_addr[1] == 1'b0) begin
            selected_half = ram[word_addr][15:0];
        end
        else begin
            selected_half = ram[word_addr][31:16];
        end

        // 3. Size from funct3[1:0], funct3[2] = 1 means unsigned (pad with zeros)
        if (funct3[1:0] == 2'b00) begin
            if (funct3[2] == 1'b0 && selected_byte[7] == 1'b1) begin
                // lb and negative: pad with 24 ones
                read_data = {24'hFFFFFF, selected_byte};
            end
            else begin
                // lb positive or lbu: pad with 24 zeros
                read_data = {24'h000000, selected_byte};
            end
        end
        else if (funct3[1:0] == 2'b01) begin
            if (funct3[2] == 1'b0 && selected_half[15] == 1'b1) begin
                // lh and negative: pad with 16 ones
                read_data = {16'hFFFF, selected_half};
            end
            else begin
                // lh positive or lhu: pad with 16 zeros
                read_data = {16'h0000, selected_half};
            end
        end
        else begin
            // Normal word read
            read_data = ram[word_addr];
        end
    end

endmodule