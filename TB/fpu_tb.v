`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:56:11
// Design Name: 
// Module Name: fpu_tb
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


module FPU_tb;

    reg clk;
    reg reset;
    reg start;
    reg [6:0] funct7;
    reg [2:0] funct3;
    reg [31:0] a, b;

    wire [31:0] result;
    wire busy, done;

    FPU uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .funct7(funct7),
        .funct3(funct3),
        .a(a),
        .b(b),
        .result(result),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    task test;
        input [6:0] op;
        input [31:0] x, y, expected;
        begin
            @(negedge clk);
            funct7 = op;
            funct3 = 3'b000;
            a = x;
            b = y;
            start = 1;

            @(negedge clk);
            start = 0;

            wait(done);
            #1;

            if (result === expected)
                $display("PASS: op=%b result=%h", op, result);
            else
                $display("FAIL: op=%b got=%h expected=%h",
                         op, result, expected);

            @(negedge clk);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        funct7 = 0;
        funct3 = 0;
        a = 0;
        b = 0;

        repeat (2) @(negedge clk);
        reset = 0;

        // 1.0 + 1.0 = 2.0
        test(7'b0000000, 32'h3F800000, 32'h3F800000,
             32'h40000000);

        // 7.5 - 2.5 = 5.0
        test(7'b0000100, 32'h40F00000, 32'h40200000,
             32'h40A00000);

        // -2.0 + 3.0 = 1.0
        test(7'b0000000, 32'hC0000000, 32'h40400000,
             32'h3F800000);

        // 1.0 - 1.0 = 0.0
        test(7'b0000100, 32'h3F800000, 32'h3F800000,
             32'h00000000);

        // 3.0 == 4.0 -> false
        test(7'b0010000, 32'h40400000, 32'h40800000,
             32'h00000000);

        // -3.0 < -1.0 -> true
        test(7'b0010100, 32'hC0400000, 32'hBF800000,
             32'h00000001);

        // 2.0 <= 1.0 -> false
        test(7'b0011000, 32'h40000000, 32'h3F800000,
             32'h00000000);

        $display("Testbench finished.");
        $finish;
    end

endmodule

