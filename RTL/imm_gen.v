`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2026 09:51:25
// Design Name: 
// Module Name: imm_gen
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

module imm_gen(
    input  [31:0] instruction,    // full instruction word from the IMU

    output reg [31:0] imm,        // I or S immediate, goes to the ALU
    output  reg   [31:0] imm_addre,  // B immediate, goes to the IFU
    output  reg   [31:0] imm_J,      // J immediate, goes to the IFU
    output   reg  [31:0] lui_imm_val // U immediate (already << 12), goes to the register file
);  
    always@(*)
    begin
    imm = 32'd0;//Initialise
    imm_addre = {{20{instruction[31]}},instruction[7],instruction[30:25],instruction[11:8],1'b0};//B type
    imm_J = {{12{instruction[31]}},instruction[19:12],instruction[20],instruction[30:21],1'b0};// J type
    lui_imm_val = {instruction[31:12],12'b0};// Lui
    if(instruction[6:0] == 7'b001_0011) begin //I type
        imm = {{20{instruction[31]}},instruction[31:20]};
    end
    else if(instruction[6:0] == 7'b000_0011) begin// lw
        imm = {{20{instruction[31]}},instruction[31:20]};
    end
    else if(instruction[6:0] == 7'b111_1111) begin// cordic
        imm = {{20{instruction[31]}},instruction[31:20]};
    end
    else if(instruction[6:0] == 7'b010_0011) begin//S type
        imm = {{20{instruction[31]}},instruction[31:25],instruction[11:7]};
    end
    end
endmodule
