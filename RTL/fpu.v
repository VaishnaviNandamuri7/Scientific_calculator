`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:56:11
// Design Name: 
// Module Name: fpu
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




module FPU (
    input clk,
    input reset,
    input [6:0] funct7,
    input [2:0] funct3,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg busy
);

    // Internal state registers
    reg [2:0] cycle_count;
    reg [6:0] active_op; // Remembers the operation code during the multi-cycle execution

    // --- State Machine & Automatic Operation Selector ---
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 3'd0;
            busy        <= 1'b0;
            result      <= 32'd0;
            active_op   <= 7'b0;
        end 
        else begin
            // Step 1: Idle state - Automatically detect input code and start
            if (!busy) begin
                // Check if the input opcode matches a known FPU instruction
                if (funct7 == 7'b0000000 || funct7 == 7'b0000100 || funct7 == 7'b0001000) begin
                    busy        <= 1'b1;
                    cycle_count <= 3'd1;
                    active_op   <= funct7; // Lock in the operation so changing inputs won't break it mid-cycle
                end
            end 
            // Step 2: Multi-cycle execution active
            else if (busy) begin
                if (cycle_count == 3'd4) begin
                    busy        <= 1'b0;
                    cycle_count <= 3'd0;
                    
                    // Step 3: Self-Select calculation based on the locked input code
                    case (active_op)
                        7'b0000000: begin // FADD.S (funct7 = 0000000)
                            result <= a + b;
                        end
                        
                        7'b0000100: begin // FSUB.S (funct7 = 0000100)
                            result <= a - b;
                        end
                        
                        7'b0001000: begin // FMUL.S (funct7 = 0001000)
                            result <= a * b;
                        end
                        
                        default: begin
                            result <= 32'd0;
                        end
                    endcase
                end 
                else begin
                    cycle_count <= cycle_count + 1'b1;
                end
            end
        end
    end
endmodule


