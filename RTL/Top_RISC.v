`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05.10.2026 21:28:29
// Design Name:
// Module Name: Top_RISC
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


module Top_RISC(
input clock,
input reset
    );
    // simulation top: the program comes from $readmemh, so the board loader ports are tied off
    // (the board uses Board_Top instead)
    datapath dp(.clock(clock), .reset(reset),
        .imem_we(1'b0), .imem_addr(7'd0), .imem_data(8'd0),
        .dmem_clear(1'b0), .dmem_dump_addr(6'd0), .dmem_dump_data(),
        .current_instruction());
endmodule