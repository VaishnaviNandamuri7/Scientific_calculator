`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.10.2026 21:33:47
// Design Name: 
// Module Name: IFU
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


module IFU(//instruction fetch unit
    input clk, reset,
    input [31:0] imm_addre, imm_J,
    input BEQ, BENQ, BGE, BLT, jump, stall,
    output reg [31:0] PC,
    output [31:0] curr_PC     // return address = PC + 4
);
    assign curr_PC = PC + 32'd4;

    always @(posedge clk or posedge reset) begin
        if (reset)                       PC <= 32'd0;
        else if (stall)                  PC <= PC;
        else if (jump)                   PC <= PC + imm_J;
        else if (BEQ | BENQ | BGE | BLT) PC <= PC + imm_addre;
        else                             PC <= PC + 32'd4;
    end
endmodule