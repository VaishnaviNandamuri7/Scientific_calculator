`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2026 13:57:38
// Design Name: 
// Module Name: IMU
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


module IMU#(//instruction memory unit
    parameter PROGRAM_FILE = "program.hex"
)(
    input clk,
    input [31:0] PC,
    input reset,
    input load_we,          // board loader: write one program byte (Top_RISC ties it to 0)
    input [6:0] load_addr,  // byte address 0..127
    input [7:0] load_data,
    output [31:0] instruction
    );
    reg [7:0] memory [0:127];

    initial begin
        $readmemh(PROGRAM_FILE, memory);
    end

    // on the board the program arrives over UART instead of $readmemh
    always @(posedge clk) begin
        if (load_we) memory[load_addr] <= load_data;
    end
    assign instruction = {memory[PC+3],memory[PC+2],memory[PC+1],memory[PC]};
endmodule
