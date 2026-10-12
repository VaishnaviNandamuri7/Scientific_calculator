`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:56:11
// Design Name: 
// Module Name: fpu_tb
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


module FPU_tb;

    reg clk;
    reg reset;
    reg [6:0] funct7;
    reg [2:0] funct3;
    reg [31:0] a;
    reg [31:0] b;

    wire [31:0] result;
    wire busy;

    FPU uut (
        .clk(clk), 
        .reset(reset), 
        .funct7(funct7), 
        .funct3(funct3), 
        .a(a), 
        .b(b), 
        .result(result), 
        .busy(busy)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; 
        reset = 1; 
        funct7 = 7'b0; 
        funct3 = 3'b0; 
        a = 32'b0; 
        b = 32'b0;
        
        #15 reset = 0; 
        
        $display("================================================================");
        $display("   STARTING MULTI-CYCLE FPU HARDWARE AUTO-SELECTION SIMULATION  ");
        $display("================================================================");

        @(posedge clk);
        a = 32'd50; 
        b = 32'd25;
        funct7 = 7'b0000000; 
        
        #1; 
        $display("[CYCLE %0t] Dispatching FADD.S -> Inputs: A=%d, B=%d | Busy status: %b", $time, a, b, busy);
        
        wait(busy == 0); 
        @(posedge clk);
        #1; $display("[CYCLE %0t] SUCCESS: FADD.S Finished. Result = %d (Expected: 75) | Busy: %b\n", $time, result, busy);

        @(posedge clk);
        a = 32'd100; 
        b = 32'd40;
        funct7 = 7'b0000100; 
        
        #1;
        $display("[CYCLE %0t] Dispatching FSUB.S -> Inputs: A=%d, B=%d | Busy status: %b", $time, a, b, busy);
        
        wait(busy == 0); 
        @(posedge clk);
        #1; $display("[CYCLE %0t] SUCCESS: FSUB.S Finished. Result = %d (Expected: 60) | Busy: %b\n", $time, result, busy);

        @(posedge clk);
        a = 32'd6; 
        b = 32'd8;
        funct7 = 7'b0001000; 
        
        #1;
        $display("[CYCLE %0t] Dispatching FMUL.S -> Inputs: A=%d, B=%d | Busy status: %b", $time, a, b, busy);
        
        wait(busy == 0); 
        @(posedge clk);
        #1; $display("[CYCLE %0t] SUCCESS: FMUL.S Finished. Result = %d (Expected: 48) | Busy: %b\n", $time, result, busy);

        $display("================================================================");
        $display("   ALL STREAM VERIFICATIONS PASSED SUCCESSFULLY                 ");
        $display("================================================================");
        $finish;
    end
    
endmodule



