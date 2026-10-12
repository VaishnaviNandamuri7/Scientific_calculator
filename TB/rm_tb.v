`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 11.10.2026 22:47:09
// Design Name:
// Module Name: rm_tb
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

module register_file_tb;

    reg clk = 0;
    reg reset = 1;
    reg reg_write = 0;
    reg [4:0] rs1 = 0, rs2 = 0, rd = 0;
    reg [31:0] write_data = 0;
    wire [31:0] rs1_data, rs2_data;
    integer errors = 0;

    register_file uut (
        .clk(clk), .reset(reset), .reg_write(reg_write),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .write_data(write_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    always #5 clk = ~clk;

    // drive inputs on the falling edge so they never race with the rising edge
    task write_reg;
        input [4:0]  r;
        input [31:0] data;
        input        en;
        begin
            @(negedge clk);
            rd = r; write_data = data; reg_write = en;
            @(negedge clk);
            reg_write = 0;
        end
    endtask

    // read both ports and compare
    task read_check;
        input [8*16-1:0] name;
        input [4:0]  r1;
        input [4:0]  r2;
        input [31:0] exp1;
        input [31:0] exp2;
        begin
            rs1 = r1; rs2 = r2;
            #1;
            if (rs1_data !== exp1 || rs2_data !== exp2) begin
                $display("FAIL %0s: rs1_data=%h (exp %h)  rs2_data=%h (exp %h)",
                         name, rs1_data, exp1, rs2_data, exp2);
                errors = errors + 1;
            end else
                $display("pass %0s", name);
        end
    endtask

    initial begin
        #12 reset = 0;

        read_check("after reset", 5'd5, 5'd10, 32'd0, 32'd0);

        write_reg(5'd5, 32'hAAAABBBB, 1);
        read_check("write x5", 5'd5, 5'd5, 32'hAAAABBBB, 32'hAAAABBBB);

        write_reg(5'd10, 32'hFFFF0000, 1);
        read_check("two ports", 5'd5, 5'd10, 32'hAAAABBBB, 32'hFFFF0000);

        write_reg(5'd0, 32'hDEADBEEF, 1);
        read_check("x0 stays zero", 5'd0, 5'd0, 32'd0, 32'd0);

        write_reg(5'd7, 32'h00001234, 0);
        read_check("no write enable", 5'd7, 5'd5, 32'd0, 32'hAAAABBBB);

        write_reg(5'd5, 32'h00000042, 1);
        read_check("overwrite x5", 5'd5, 5'd10, 32'h00000042, 32'hFFFF0000);

        reset = 1;
        @(negedge clk);
        @(negedge clk);
        reset = 0;
        read_check("reset clears", 5'd5, 5'd10, 32'd0, 32'd0);

        if (errors == 0) $display("ALL RF TESTS PASSED");
        else             $display("%0d RF TEST(S) FAILED", errors);
        $finish;
    end

endmodule