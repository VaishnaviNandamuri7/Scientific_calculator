`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:47:09
// Design Name: 
// Module Name: alu_tb
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


module alu_tb;

    // Inputs to your ALU
    reg [31:0] src1;
    reg [31:0] src2;
    reg [31:0] imm;
    reg [5:0] alu_control;
    reg [3:0] shift;

    // Outputs from your ALU
    wire [31:0] result;

    // Instantiate your exact ALU port mapping structure
    alu uut (
        .src1(src1), 
        .src2(src2), 
        .alu_control(alu_control), 
        .imm(imm), 
        .shift(shift), 
        .result(result)
    );

    initial begin
        // Initialize inputs
        src1 = 32'd0;
        src2 = 32'd0;
        imm = 32'd0;
        shift = 4'd0;
        alu_control = 6'd0;

        #10;
        $display("--- Starting Your ALU Testbench ---");

        // Test Case 1: Addition (6'b000001)
        src1 = 32'd40; src2 = 32'd20; alu_control = 6'b000001;
        #10; $display("[ADD] src1=%d, src2=%d -> result=%d", src1, src2, result);

        // Test Case 2: Subtraction (6'b000010)
        src1 = 32'd40; src2 = 32'd20; alu_control = 6'b000010;
        #10; $display("[SUB] src1=%d, src2=%d -> result=%d", src1, src2, result);

        // Test Case 3: Add Immediate (6'b001011)
        src1 = 32'd100; imm = 32'd50; alu_control = 6'b001011;
        #10; $display("[ADDI] src1=%d, imm=%d -> result=%d", src1, imm, result);

        // Test Case 4: Branch Equal Check (6'b011011)
        src1 = 32'd77; src2 = 32'd77; alu_control = 6'b011011;
        #10; $display("[BEQ] src1=%d, src2=%d -> result=%d", src1, src2, result);

        $display("-----------------------------------");
        $finish;
    end

endmodule

