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
    reg clk = 0, sw = 0;
    reg [2:0] funct3 = 3'b010;
    reg [31:0] mem_addr = 0, write_data = 0;
    wire [31:0] read_data;
    integer errors = 0;

    data_memory uut (
        .clk(clk), .mem_addr(mem_addr), .write_data(write_data),
        .sw(sw), .funct3(funct3), .read_data(read_data)
    );

    always #5 clk = ~clk;

    // drive inputs on the falling edge so they never race with the rising edge
    task store;
        input [31:0] addr;
        input [2:0]  f3;
        input [31:0] data;
        begin
            @(negedge clk);
            mem_addr = addr; funct3 = f3; write_data = data; sw = 1;
            @(negedge clk);
            sw = 0;
        end
    endtask

    task load;
        input [8*16-1:0] name;
        input [31:0]     addr;
        input [2:0]      f3;
        input [31:0]     expected;
        begin
            mem_addr = addr; funct3 = f3;
            #1;
            if (read_data !== expected) begin
                $display("FAIL %0s: got %h, expected %h", name, read_data, expected);
                errors = errors + 1;
            end else
                $display("pass %0s: %h", name, read_data);
        end
    endtask

    initial begin
        #1;
        load("init read", 32'd0, 3'b010, 32'h00000000);

        store(32'd4, 3'b010, 32'h80706050);
        load("lw",  32'd4, 3'b010, 32'h80706050);
        load("lb  @7", 32'd7, 3'b000, 32'hFFFFFF80);
        load("lbu @7", 32'd7, 3'b100, 32'h00000080);
        load("lb  @4", 32'd4, 3'b000, 32'h00000050);
        load("lh  @6", 32'd6, 3'b001, 32'hFFFF8070);
        load("lhu @6", 32'd6, 3'b101, 32'h00008070);

        store(32'd5, 3'b000, 32'h00000011);
        load("sb keeps others", 32'd4, 3'b010, 32'h80701150);

        store(32'd4, 3'b001, 32'h0000BEEF);
        load("sh low half", 32'd4, 3'b010, 32'h8070BEEF);
        load("lh  @4", 32'd4, 3'b001, 32'hFFFFBEEF);

        store(32'd6, 3'b001, 32'h00001234);
        load("sh high half", 32'd4, 3'b010, 32'h1234BEEF);

        if (errors == 0) $display("ALL DM TESTS PASSED");
        else             $display("%0d DM TEST(S) FAILED", errors);
        $finish;
    end
endmodule