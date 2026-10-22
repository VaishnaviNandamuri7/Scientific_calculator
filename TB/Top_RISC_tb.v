`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Top_RISC_tb
//
// Program-agnostic top-level testbench:
//   1. releases reset and lets the CPU run program.hex
//   2. stops when the CPU reaches the halt instruction  jal x0, 0  (0x0000006F)
//      (instruction match, NOT "PC stopped changing": the PC also freezes while
//       the FPU/CORDIC stall, so PC-unchanged would give false halts)
//   3. dumps final state to text files:
//        output.hex : data memory, 64 words, one 8-digit hex WORD per line
//        regs.hex   : register file, x0..x31, one 8-digit hex word per line
//   4. optional self-check block (EDIT PER PROGRAM) at the bottom
//
// XSim writes the files into its run directory:
//   <proj>/CALC_PRO.sim/sim_1/behav/xsim/
// program.hex is read from the same place (build.tcl adds it to sim_1).
//////////////////////////////////////////////////////////////////////////////////

module Top_RISC_tb;
    localparam integer MAX_CYCLES = 100000;       // timeout guard
    localparam [31:0]  HALT       = 32'h0000006F; // jal x0, 0
    localparam         RUN_SELF_CHECK = 0;           // 1 = run the exercise-program checks at the bottom

    reg clock = 0, reset = 1;
    integer cycles = 0;
    integer errors = 0;
    integer i, fd;
    reg     halted = 0;

    Top_RISC dut(.clock(clock), .reset(reset));

    always #5 clock = ~clock;                     // 100 MHz

    // ---------- self-check helpers ----------
    task check_reg;
        input [4:0]  r;
        input [31:0] expected;
        begin
            if (dut.dp.rf.reg_mem[r] !== expected) begin
                $display("FAIL x%0d = %h, expected %h", r, dut.dp.rf.reg_mem[r], expected);
                errors = errors + 1;
            end else
                $display("pass x%0d = %h", r, expected);
        end
    endtask

    // allow +/- tol on a result (CORDIC output is not bit-exact)
    task check_mem_near;
        input integer w;           // word index (byte address / 4)
        input [31:0]  expected;
        input integer tol;
        integer diff;
        begin
            diff = $signed(dut.dp.dm.ram[w]) - $signed(expected);
            if (diff < 0) diff = -diff;
            if (diff > tol) begin
                $display("FAIL mem[%0d] = %h, expected %h (+/-%0d)", w, dut.dp.dm.ram[w], expected, tol);
                errors = errors + 1;
            end else
                $display("pass mem[%0d] = %h (expected %h, +/-%0d)", w, dut.dp.dm.ram[w], expected, tol);
        end
    endtask

    // ---------- run ----------
    initial begin
        #22 reset = 0;

        // run until the CPU fetches the halt instruction, or time out
        while (!halted && cycles < MAX_CYCLES) begin
            @(posedge clock);
            #1;                                   // let the posedge writes settle
            cycles = cycles + 1;
            if (dut.dp.instruction === HALT) halted = 1;
        end
        repeat (2) @(posedge clock);              // margin for a store in flight
        #1;

        if (!halted)
            $display("TIMEOUT after %0d cycles: no halt (jal x0,0) reached. Is program.hex loaded? Missing halt at the end?", cycles);
        else
            $display("HALT at PC=%h after %0d cycles", dut.dp.PC, cycles);

        // ---------- dump: output.hex (data memory) ----------
        fd = $fopen("output.hex", "w");
        for (i = 0; i < 64; i = i + 1)
            $fdisplay(fd, "%h", dut.dp.dm.ram[i]);
        $fclose(fd);

        // ---------- dump: regs.hex (debug only, not on the board) ----------
        fd = $fopen("regs.hex", "w");
        for (i = 0; i < 32; i = i + 1)
            $fdisplay(fd, "%h", dut.dp.rf.reg_mem[i]);
        $fclose(fd);

        // ---------- console summary: only non-zero state ----------
        $display("---- registers (non-zero) ----");
        for (i = 1; i < 32; i = i + 1)
            if (dut.dp.rf.reg_mem[i] !== 32'd0)
                $display("x%0d = %h", i, dut.dp.rf.reg_mem[i]);
        $display("---- data memory (non-zero words) ----");
        for (i = 0; i < 64; i = i + 1)
            if (dut.dp.dm.ram[i] !== 32'd0)
                $display("mem[%0d] @0x%02h = %h", i, i*4, dut.dp.dm.ram[i]);

        // =====================================================================
        // EDIT PER PROGRAM: expected results for the exercise program
        // Only runs when RUN_SELF_CHECK = 1 (calc.py programs need it at 0)
        // =====================================================================
        if (RUN_SELF_CHECK && halted) begin
            $display("---- self-check ----");
            check_reg(2, 32'd15);                  // 5+4+3+2+1
            check_reg(5, 32'h40400000);            // 1.5f * 2.0f = 3.0f
            if (dut.dp.dm.ram[0] !== 32'd15) begin
                $display("FAIL mem[0] = %h, expected 0000000f", dut.dp.dm.ram[0]);
                errors = errors + 1;
            end else $display("pass mem[0] = 0000000f");
            if (dut.dp.dm.ram[1] !== 32'h40400000) begin
                $display("FAIL mem[1] = %h, expected 40400000", dut.dp.dm.ram[1]);
                errors = errors + 1;
            end else $display("pass mem[1] = 40400000");
            check_mem_near(2, 32'h0000D76A, 8);    // sin(1.0) in Q16.16 = 0.84147 * 65536
            if (errors == 0) $display("ALL TOP TESTS PASSED");
            else             $display("%0d TOP TEST(S) FAILED", errors);
        end
        $finish;
    end
endmodule