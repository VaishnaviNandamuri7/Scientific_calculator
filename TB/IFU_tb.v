`timescale 1ns/1ps

module IFU_tb;
    reg         clk = 0, reset = 1;
    reg  [31:0] imm_addre = 0, imm_J = 0;
    reg         BEQ = 0, BENQ = 0, BGE = 0, BLT = 0, jump = 0;
    wire [31:0] PC, curr_PC;

    IFU dut (
        .clk(clk), .reset(reset),
        .imm_addre(imm_addre), .imm_J(imm_J),
        .BEQ(BEQ), .BENQ(BENQ), .BGE(BGE), .BLT(BLT),
        .jump(jump),
        .PC(PC), .curr_PC(curr_PC)
    );

    always #5 clk = ~clk;

    initial begin
        // reset, then release between clock edges
        #12 reset = 0;
        if (PC !== 0) $display("FAIL reset: PC = %0d", PC);

        // sequential fetch: expect 4
        @(posedge clk); #1;
        if (PC !== 4) $display("FAIL seq 1: PC = %0d", PC);
        else          $display("pass seq 1: PC = %0d", PC);

        // sequential fetch: expect 8
        @(posedge clk); #1;
        if (PC !== 8) $display("FAIL seq 2: PC = %0d", PC);
        else          $display("pass seq 2: PC = %0d", PC);

        // branch taken, +16: expect 8 + 16 = 24
        imm_addre = 16; BEQ = 1;
        @(posedge clk); #1;
        BEQ = 0;
        if (PC !== 24) $display("FAIL branch: PC = %0d", PC);
        else           $display("pass branch: PC = %0d", PC);

        // return address must always be PC + 4
        if (curr_PC !== PC + 4) $display("FAIL curr_PC: %0d", curr_PC);
        else                    $display("pass curr_PC = PC + 4 = %0d", curr_PC);

        // jump, +100: expect 24 + 100 = 124
        imm_J = 100; jump = 1;
        @(posedge clk); #1;
        jump = 0;
        if (PC !== 124) $display("FAIL jump: PC = %0d", PC);
        else            $display("pass jump: PC = %0d", PC);

        // curr_PC still PC + 4 after the jump
        if (curr_PC !== PC + 4) $display("FAIL curr_PC after jump: %0d", curr_PC);
        else                    $display("pass curr_PC after jump = %0d", curr_PC);

        // back to normal: expect 128
        @(posedge clk); #1;
        if (PC !== 128) $display("FAIL resume: PC = %0d", PC);
        else            $display("pass resume: PC = %0d", PC);

        $finish;
    end
endmodule