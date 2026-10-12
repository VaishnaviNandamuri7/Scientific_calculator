`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 19:28:45
// Design Name: 
// Module Name: alu
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


module alu(src1,src2,alu_control,imm,shift,result);
input [31:0] src1,src2,imm;
input [5:0]alu_control;
input [3:0]shift;
output reg [31:0] result;
    always @(*) begin
        case(alu_control)
            6'b000001: // addition
                result = src1 + src2;
                
            6'b000010: // subtraction
                result = src1 - src2;
                
            6'b000011: // shift left logical
                result = src1 << src2[4:0]; // Typically uses lower 5 bits of src2 for 32-bit width
                
            6'b000100: // set less than (signed)
                result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0;
                
            6'b000101: // set less than unsigned
                result = (src1 < src2) ? 32'd1 : 32'd0;
                
            6'b000110: // xor operation
                result = src1 ^ src2;
                
            6'b000111: // shift right logical
                result = src1 >> src2[4:0];
                
            6'b001000: // shift right arithmetic
                result = $signed(src1) >>> src2[4:0]; // Needs $signed to sign-extend
                
            6'b001001: // or operation
                result = src1 | src2;
                
            6'b001010: // and operation
                result = src1 & src2;
                
            6'b001011 :
                result = src1 + imm; // add immediate
            
            6'b001100 :
                result = imm << shift; // shift left logical immediate
            
            6'b001101 :
                result = (imm< src1) ? 1 : 0;// SET LESS THAN IMMEDIATE
            
            6'b001110:
                result = src1 & src2;
            
            6'b001111 :
                result = src1 ^ imm; // xor immediate
            
            6'b010000 :
                result = src1 >> imm; // shift right logical immediate
            
            6'b001001 :
                result = (src1 < src2) ? 1 : 0;
            
            6'b001011 :
                //set less than unsigned this should be checked
                result = src1 + imm;
            
            6'b001101 :
                begin
                result = src1 | imm;
                end
            
            6'b001110 :
                result = src1 & imm;
            
            6'b001111 :
                result = src1 >> imm;
            
            6'b010000 :
                result = src1 << imm;
            
            6'b010001 : // OR IMMEDIATE
                result = src1 | imm;
            
            6'b010010 :
                result = src1 & imm;
            
                
            6'b011011 : // BEQ: Branch if Equal
                result = (src1 == src2) ? 32'd1 : 32'd0; 
                
            6'b011100 : // BNE: Branch if Not Equal
                result = (src1 != src2) ? 32'd1 : 32'd0; // Corrected comment explanation: returns 1 if different
                
            6'b011111 : // BGE: Branch if Greater than or Equal (Signed)
                result = ($signed(src1) >= $signed(src2)) ? 32'd1 : 32'd0; // Fixed reversed operands & added signed comparison
                
            6'b100000 : // BLT: Branch if Less Than (Signed)
                result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0;  // Added signed comparison
    
            default:
                result = 32'd0;
    endcase
end
endmodule

