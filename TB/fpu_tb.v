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

    integer errors = 0;

    task test_bad;//illegal funct7/funct3 must finish with NaN, not hang
        input [6:0] op;
        input [2:0] f3;
        begin
            @(negedge clk);
            funct7 = op;
            funct3 = f3;
            a = 32'h3F800000;
            b = 32'h3F800000;
            start = 1;

            @(negedge clk);
            start = 0;
            #1;

            if (done === 1'b1 && result === 32'h7FC00000)
                $display("PASS: bad op=%b f3=%b -> NaN", op, f3);
            else begin
                $display("FAIL: bad op=%b f3=%b done=%b result=%h", op, f3, done, result);
                errors = errors + 1;
            end

            @(negedge clk);
        end
    endtask

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
            else begin
                $display("FAIL: op=%b got=%h expected=%h",
                         op, result, expected);
                errors = errors + 1;
            end

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

        // 2.0 * 3.0 = 6.0
        test(7'b0001000, 32'h40000000, 32'h40400000,
             32'h40C00000);

        // -1.5 * 2.0 = -3.0
        test(7'b0001000, 32'hBFC00000, 32'h40000000,
             32'hC0400000);

        // 2.0 / 1.0 = 2.0
        test(7'b0001100, 32'h40000000, 32'h3F800000,
             32'h40000000);

        // 6.0 / 3.0 = 2.0
        test(7'b0001100, 32'h40C00000, 32'h40400000,
             32'h40000000);

        // 5.0 / 5.0 = 1.0
        test(7'b0001100, 32'h40A00000, 32'h40A00000,
             32'h3F800000);

        // 1.0 / 2.0 = 0.5
        test(7'b0001100, 32'h3F800000, 32'h40000000,
             32'h3F000000);

        // 3.0 / 2.0 = 1.5
        test(7'b0001100, 32'h40400000, 32'h40000000,
             32'h3FC00000);

        // 1.0 / 4.0 = 0.25
        test(7'b0001100, 32'h3F800000, 32'h40800000,
             32'h3E800000);

        // -6.0 / 3.0 = -2.0
        test(7'b0001100, 32'hC0C00000, 32'h40400000,
             32'hC0000000);

        // illegal ops
        test_bad(7'b1111111, 3'b000);
        test_bad(7'b0000001, 3'b000);
        test_bad(7'b0000000, 3'b001);

        // valid op still works after an illegal one
        test(7'b0000000, 32'h3F800000, 32'h3F800000,
             32'h40000000);

        if (errors == 0) $display("ALL FPU TESTS PASSED");
        else             $display("%0d FPU TEST(S) FAILED", errors);
        $finish;
    end

endmodule