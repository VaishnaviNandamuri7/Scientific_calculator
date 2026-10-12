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
    input reg_write,
    input [4:0] rs1, rs2, rd,
    input [31:0] write_data_dm,
    input lb,
    input lui_control,
    input [31:0] lui_imm_val,
    input [31:0] return_address,
    input jump,
    output [31:0] rs1_data,
    output [31:0] rs2_data,
    output [4:0] read_data_addr_dm,
    output reg [31:0] data_out_2_dm,
    input sw
);

    reg [31:0] reg_mem [31:0];
    wire [31:0] write_reg_dm;

    assign read_data_addr_dm = rd;
    assign write_reg_dm = rd;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_mem[i] <= i;
            end
            data_out_2_dm <= 32'd0;
        end
        else begin
            if (reg_write && lb) begin
                reg_mem[rd] <= write_data_dm;
            end
            else if (sw) begin
                data_out_2_dm <= reg_mem[rs1];
            end
            else if (reg_write && lui_control) begin
                reg_mem[rd] <= lui_imm_val;
            end
            else if (reg_write && jump) begin
                reg_mem[rd] <= return_address;
            end
        end
    end

    assign rs1_data = reg_mem[rs1];
    assign rs2_data = reg_mem[rs2];

endmodule
