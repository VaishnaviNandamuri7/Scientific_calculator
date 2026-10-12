`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 11.10.2026 22:09:16
// Design Name:
// Module Name: register_memory
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


`timescale 1ns / 1ps

module register_file(
    input clk, reset,
    input reg_write,             // High when the instruction writes rd (CU holds it low during a stall)
    input [4:0] rs1, rs2, rd,
    input [31:0] write_data,     // Already selected in Top_RISC (ALU, memory, lui, return address, cordic, fpu)
    output [31:0] rs1_data,
    output [31:0] rs2_data
);

    reg [31:0] reg_mem [31:0];

    integer i;

    // Clear the registers at start so reads never return x
    initial begin
        for (i = 0; i < 32; i = i + 1) reg_mem[i] = 32'd0;
    end

    // --- Synchronous Write Block ---
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_mem[i] <= 32'd0;
            end
        end
        else begin
            // x0 is hardwired to zero, so a write to rd = 0 is ignored
            if (reg_write && rd != 5'd0) begin
                reg_mem[rd] <= write_data;
            end
        end
    end

    // --- Combinational Read Ports ---
    // rs2_data also feeds the data memory as the store data
    assign rs1_data = reg_mem[rs1];
    assign rs2_data = reg_mem[rs2];

endmodule