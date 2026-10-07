`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2026 14:15:04
// Design Name: 
// Module Name: IMU_tb
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


`timescale 1ns/1ps

module IMU_tb;
    reg         clk   = 0;
    reg         reset = 0;
    reg  [31:0] PC    = 0;
    wire [31:0] instruction;

    // Device under test
    IMU #(.PROGRAM_FILE("program.hex")) uut (
        .clk(clk),
        .PC(PC),
        .reset(reset),
        .instruction(instruction)
    );

    // Clock isn't used by the IMU, but it's good habit to drive it
    always #5 clk = ~clk;

    // Expected 32-bit instruction words (what the hex file should assemble to)
    reg [31:0] expected [0:11];
    integer i;
    integer errors = 0;

    initial begin
        expected[0]  = 32'h00500093; // addi x1, x0, 5
        expected[1]  = 32'h00A00113; // addi x2, x0, 10
        expected[2]  = 32'h002081B3; // add  x3, x1, x2
        expected[3]  = 32'h40110233; // sub  x4, x2, x1
        expected[4]  = 32'h0020F2B3; // and  x5, x1, x2
        expected[5]  = 32'h0020E333; // or   x6, x1, x2
        expected[6]  = 32'h00302023; // sw   x3, 0(x0)
        expected[7]  = 32'h00002383; // lw   x7, 0(x0)
        expected[8]  = 32'h00718463; // beq  x3, x7, +8
        expected[9]  = 32'h00100413; // addi x8, x0, 1
        expected[10] = 32'h06300493; // addi x9, x0, 99
        expected[11] = 32'h0000006F; // jal  x0, 0

        #1; // let the initial block in IMU finish loading the file

        for (i = 0; i < 12; i = i + 1) begin
            PC = i * 4;
            #10;
            if (instruction === expected[i])
                $display("PASS  PC=0x%02h  instr=0x%08h", PC, instruction);
            else begin
                $display("FAIL  PC=0x%02h  got=0x%08h  expected=0x%08h",
                         PC, instruction, expected[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("All %0d fetches correct.", 12);
        else             $display("%0d fetch(es) failed.", errors);

        $finish;
    end
endmodule
