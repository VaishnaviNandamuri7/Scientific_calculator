`timescale 1ns/1ps

module IFU_tb;
    reg         clk = 0, reset = 1;
    reg  [31:0] imm_addre = 0, imm_J = 0;
    reg         BEQ = 0, BENQ = 0, BGE = 0, BLT = 0, jump = 0, stall = 0;
    wire [31:0] PC, curr_PC;
    integer     errors = 0;

    IFU dut (
        .clk(clk), .reset(reset),
        .imm_addre(imm_addre), .imm_J(imm_J),
        .BEQ(BEQ), .BENQ(BENQ), .BGE(BGE), .BLT(BLT),
        .jump(jump), .stall(stall),
        .PC(PC), .curr_PC(curr_PC)
    );

    always #5 clk = ~clk;

    // wait for the next clock edge, then check PC and curr_PC
    task step_check;
        input [31:0]      expected;
        input [8*28-1:0]  name;
        begin
            @(posedge clk); #1;
            if (PC !== expected) begin
                $display("FAIL %0s: PC = %0d, expected %0d", name, PC, expected);
                errors = errors + 1;
            end else
                $display("pass %0s: PC = %0d", name, PC);
            if (curr_PC !== PC + 4) begin
                $display("FAIL %0s: curr_PC = %0d, expected %0d", name, curr_PC, PC + 4);
                errors = errors + 1;
            end
        end
    endtask

    // check PC right now (no clock edge), used for the async reset tests
    task now_check;
        input [31:0]      expected;
        input [8*28-1:0]  name;
        begin
            if (PC !== expected) begin
                $display("FAIL %0s: PC = %0d, expected %0d", name, PC, expected);
                errors = errors + 1;
            end else
                $display("pass %0s: PC = %0d", name, PC);
        end
    endtask

    initial begin
        // ---------------- reset ----------------
        #12 reset = 0;                       // release between clock edges
        now_check(0, "reset value");

        // ---------------- sequential ----------------
        step_check(4,  "seq 1");
        step_check(8,  "seq 2");

        // ---------------- each branch flag, +16 ----------------
        imm_addre = 16;
        BEQ = 1;  step_check(24, "BEQ taken");   BEQ = 0;
        BENQ = 1; step_check(40, "BENQ taken");  BENQ = 0;
        BGE = 1;  step_check(56, "BGE taken");   BGE = 0;
        BLT = 1;  step_check(72, "BLT taken");   BLT = 0;

        // two branch flags at once still add the offset only once
        BEQ = 1; BLT = 1;
        step_check(88, "two flags, one offset"); BEQ = 0; BLT = 0;

        // backward branch (-8)
        imm_addre = -8; BEQ = 1;
        step_check(80, "backward branch");       BEQ = 0;

        // ---------------- jump ----------------
        imm_J = 100; jump = 1;
        step_check(180, "jump +100");            jump = 0;
        imm_J = -20; jump = 1;
        step_check(160, "jump -20 (backward)");  jump = 0;

        // jump has priority over a branch flag
        imm_addre = 16; imm_J = 100; jump = 1; BEQ = 1;
        step_check(260, "jump beats branch");    jump = 0; BEQ = 0;

        // back to normal
        step_check(264, "resume sequential");

        // ---------------- stall ----------------
        stall = 1;
        step_check(264, "stall hold 1");
        step_check(264, "stall hold 2");
        step_check(264, "stall hold 3");

        // stall beats jump and branch
        jump = 1; imm_J = 100;
        step_check(264, "stall beats jump");
        jump = 0; BEQ = 1; imm_addre = 16;
        step_check(264, "stall beats branch");
        BEQ = 0;

        // release stall: PC resumes from the held value
        stall = 0;
        step_check(268, "resume after stall");

        // one-cycle stall
        stall = 1;
        step_check(268, "1-cycle stall hold");
        stall = 0;
        step_check(272, "resume after 1-cycle");

        // ---------------- reset priority ----------------
        // reset is asynchronous: PC clears immediately, even with stall and jump set
        stall = 1; jump = 1; imm_J = 100;
        #2 reset = 1; #1;
        now_check(0, "async reset (no clk edge)");
        step_check(0, "reset beats stall/jump");
        reset = 0; stall = 0; jump = 0;
        step_check(4, "run after reset");
        step_check(8, "seq after reset");

        // reset in the middle of normal running
        #2 reset = 1; #1;
        now_check(0, "mid-run async reset");
        step_check(0, "reset held over edge");
        reset = 0;
        step_check(4, "restart from 0");

        // ---------------- summary ----------------
        if (errors == 0) $display("ALL IFU TESTS PASSED");
        else             $display("%0d IFU TEST(S) FAILED", errors);
        $finish;
    end
endmodule