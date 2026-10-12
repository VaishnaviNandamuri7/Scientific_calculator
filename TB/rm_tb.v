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

    reg clk;
    reg reset;
    reg reg_write;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;
    reg [31:0] write_data_dm;
    reg lb;
    reg lui_control;
    reg [31:0] lui_imm_val;
    reg [31:0] return_address;
    reg jump;
    reg sw;

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [4:0] read_data_addr_dm;
    wire [31:0] data_out_2_dm;

    register_file uut (
        .clk(clk),
        .reset(reset),
        .reg_write(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data_dm(write_data_dm),
        .lb(lb),
        .lui_control(lui_control),
        .lui_imm_val(lui_imm_val),
        .return_address(return_address),
        .jump(jump),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .read_data_addr_dm(read_data_addr_dm),
        .data_out_2_dm(data_out_2_dm),
        .sw(sw)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        reg_write = 0;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        write_data_dm = 0;
        lb = 0;
        lui_control = 0;
        lui_imm_val = 0;
        return_address = 0;
        jump = 0;
        sw = 0;

        #15 reset = 0;

        @(posedge clk);
        rd = 5'd5;
        write_data_dm = 32'hAAAA_BBBB;
        reg_write = 1;
        lb = 1;
        
        @(posedge clk);
        lb = 0;
        reg_write = 0;
        
        rs1 = 5'd5;
        #1;
        $display("[LB TEST] rs1_data = %h", rs1_data);

        @(posedge clk);
        rs1 = 5'd5;
        sw = 1;
        
        @(posedge clk);
        sw = 0;
        #1;
        $display("[SW TEST] data_out_2_dm = %h", data_out_2_dm);

        @(posedge clk);
        rd = 5'd10;
        lui_imm_val = 32'hFFFF_0000;
        reg_write = 1;
        lui_control = 1;
        
        @(posedge clk);
        lui_control = 0;
        reg_write = 0;
        
        rs2 = 5'd10;
        #1;
        $display("[LUI TEST] rs2_data = %h", rs2_data);

        @(posedge clk);
        rd = 5'd15;
        return_address = 32'h0000_1234;
        reg_write = 1;
        jump = 1;
        
        @(posedge clk);
        jump = 0;
        reg_write = 0;
        
        rs1 = 5'd15;
        #1;
        $display("[JUMP TEST] rs1_data = %h", rs1_data);

        $finish;
    end

endmodule


