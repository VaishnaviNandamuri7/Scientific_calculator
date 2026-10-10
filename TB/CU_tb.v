`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.10.2026 14:17:24
// Design Name: 
// Module Name: CU_tb
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



module CU_tb;
    reg         reset = 0, clk = 0;
    reg  [6:0]  funct7 = 0, opcode = 0;
    reg  [2:0]  funct3 = 0;
    reg         cordic_busy = 0, cordic_done = 0, fpu_busy = 0, fpu_done = 0;
    wire [5:0]  alu_control;
    wire        lb, mem_to_reg, bneq_control, beq_control, bgeq_control, blt_control;
    wire        jump, sw, lui_control, cordic_start, fpu_start, stall;

    integer errors = 0;
    integer tests  = 0;

    CU dut (
        .reset(reset), .clk(clk),
        .funct7(funct7), .funct3(funct3), .opcode(opcode),
        .cordic_busy(cordic_busy), .cordic_done(cordic_done),
        .fpu_busy(fpu_busy), .fpu_done(fpu_done),
        .alu_control(alu_control),
        .lb(lb), .mem_to_reg(mem_to_reg),
        .bneq_control(bneq_control), .beq_control(beq_control),
        .bgeq_control(bgeq_control), .blt_control(blt_control),
        .jump(jump), .sw(sw), .lui_control(lui_control),
        .cordic_start(cordic_start), .fpu_start(fpu_start), .stall(stall)
    );

    // clk is unused by the CU, driven only for completeness
    always #5 clk = ~clk;

    // flag bit positions: {lb, mem_to_reg, beq, bneq, bgeq, blt, jump, sw, lui, cordic_start, fpu_start, stall}
    localparam [11:0] F_NONE   = 12'b0000_0000_0000;
    localparam [11:0] F_LB     = 12'b1000_0000_0000;
    localparam [11:0] F_M2R    = 12'b0100_0000_0000;
    localparam [11:0] F_BEQ    = 12'b0010_0000_0000;
    localparam [11:0] F_BNEQ   = 12'b0001_0000_0000;
    localparam [11:0] F_BGEQ   = 12'b0000_1000_0000;
    localparam [11:0] F_BLT    = 12'b0000_0100_0000;
    localparam [11:0] F_JUMP   = 12'b0000_0010_0000;
    localparam [11:0] F_SW     = 12'b0000_0001_0000;
    localparam [11:0] F_LUI    = 12'b0000_0000_1000;
    localparam [11:0] F_CSTART = 12'b0000_0000_0100;
    localparam [11:0] F_FSTART = 12'b0000_0000_0010;
    localparam [11:0] F_STALL  = 12'b0000_0000_0001;

    // opcodes
    localparam [6:0] OP_R      = 7'b0110011;
    localparam [6:0] OP_I      = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_FPU    = 7'b1111110;
    localparam [6:0] OP_CORDIC = 7'b1111111;

    // drive the instruction fields, wait, compare every output
    task check;
        input [8*24-1:0] name;
        input [6:0]      f7;
        input [2:0]      f3;
        input [6:0]      op;
        input [5:0]      exp_alu;
        input [11:0]     exp_flags;
        reg   [11:0]     got;
        begin
            funct7 = f7; funct3 = f3; opcode = op;
            #1;
            got = {lb, mem_to_reg, beq_control, bneq_control, bgeq_control,
                   blt_control, jump, sw, lui_control, cordic_start, fpu_start, stall};
            tests = tests + 1;
            if (alu_control !== exp_alu || got !== exp_flags) begin
                $display("FAIL %0s: alu=%b (exp %b)  flags=%b (exp %b)",
                         name, alu_control, exp_alu, got, exp_flags);
                errors = errors + 1;
            end else
                $display("pass %0s", name);
            #1;
        end
    endtask

    // same check, but from a full 32-bit instruction word (e.g. lines from program.hex)
    task check_instr;
        input [8*24-1:0] name;
        input [31:0]     instr;
        input [5:0]      exp_alu;
        input [11:0]     exp_flags;
        begin
            check(name, instr[31:25], instr[14:12], instr[6:0], exp_alu, exp_flags);
        end
    endtask

    initial begin
        #5;

        // ================= R-type =================
        $display("--- R-type ---");
        check("add",   7'd0,  3'b000, OP_R, 6'b000001, F_NONE);
        check("sub",   7'd32, 3'b000, OP_R, 6'b000010, F_NONE);
        check("sll",   7'd0,  3'b001, OP_R, 6'b000011, F_NONE);
        check("slt",   7'd0,  3'b010, OP_R, 6'b000100, F_NONE);
        check("sltu",  7'd0,  3'b011, OP_R, 6'b000101, F_NONE);
        check("xor",   7'd0,  3'b100, OP_R, 6'b000110, F_NONE);
        check("srl",   7'd0,  3'b101, OP_R, 6'b000111, F_NONE);
        check("sra",   7'd32, 3'b101, OP_R, 6'b001000, F_NONE);
        check("or",    7'd0,  3'b110, OP_R, 6'b001001, F_NONE);
        check("and",   7'd0,  3'b111, OP_R, 6'b001010, F_NONE);
        // illegal funct7 values must decode to nothing
        check("add bad funct7", 7'd1,  3'b000, OP_R, 6'b000000, F_NONE);
        check("sll bad funct7", 7'd32, 3'b001, OP_R, 6'b000000, F_NONE);

        // ================= I-type arithmetic =================
        $display("--- I-type ---");
        check("addi",  7'd0,   3'b000, OP_I, 6'b001011, F_NONE);
        check("addi imm bits ignored", 7'h7F, 3'b000, OP_I, 6'b001011, F_NONE);
        check("slli",  7'd0,   3'b001, OP_I, 6'b001100, F_NONE);
        check("slti",  7'd0,   3'b010, OP_I, 6'b001101, F_NONE);
        check("sltiu", 7'd0,   3'b011, OP_I, 6'b001110, F_NONE);
        check("xori",  7'd0,   3'b100, OP_I, 6'b001111, F_NONE);
        check("srli",  7'd0,   3'b101, OP_I, 6'b010000, F_NONE);
        check("srai",  7'd32,  3'b101, OP_I, 6'b100011, F_NONE);
        check("ori",   7'd0,   3'b110, OP_I, 6'b010001, F_NONE);
        check("andi",  7'd0,   3'b111, OP_I, 6'b010010, F_NONE);

        // ================= loads =================
        $display("--- loads ---");
        check("lb",  7'd0, 3'b000, OP_LOAD, 6'b010011, F_LB | F_M2R);
        check("lh",  7'd0, 3'b001, OP_LOAD, 6'b010100, F_M2R);
        check("lw",  7'd0, 3'b010, OP_LOAD, 6'b010101, F_M2R);
        check("lbu", 7'd0, 3'b100, OP_LOAD, 6'b010110, F_M2R);
        check("lhu", 7'd0, 3'b101, OP_LOAD, 6'b010111, F_M2R);
        check("load illegal f3=011", 7'd0, 3'b011, OP_LOAD, 6'b000000, F_NONE);

        // ================= stores =================
        $display("--- stores ---");
        check("sb", 7'd0, 3'b000, OP_STORE, 6'b011000, F_SW);
        check("sh", 7'd0, 3'b001, OP_STORE, 6'b011001, F_SW);
        check("sw", 7'd0, 3'b010, OP_STORE, 6'b011010, F_SW);
        check("store illegal f3=111", 7'd0, 3'b111, OP_STORE, 6'b000000, F_NONE);

        // ================= branches =================
        $display("--- branches ---");
        check("beq",  7'd0, 3'b000, OP_BRANCH, 6'b011011, F_BEQ);
        check("bne",  7'd0, 3'b001, OP_BRANCH, 6'b011100, F_BNEQ);
        check("blt",  7'd0, 3'b100, OP_BRANCH, 6'b011101, F_BLT);
        check("bge",  7'd0, 3'b101, OP_BRANCH, 6'b011111, F_BGEQ);
        check("bltu", 7'd0, 3'b110, OP_BRANCH, 6'b011110, F_BLT);
        check("bgeu", 7'd0, 3'b111, OP_BRANCH, 6'b100000, F_BGEQ);
        check("branch illegal f3=010", 7'd0, 3'b010, OP_BRANCH, 6'b000000, F_NONE);
        check("branch illegal f3=011", 7'd0, 3'b011, OP_BRANCH, 6'b000000, F_NONE);

        // ================= lui / jal =================
        $display("--- lui / jal ---");
        check("lui",           7'd0,  3'b000, OP_LUI, 6'b100001, F_LUI);
        check("lui other bits", 7'h55, 3'b101, OP_LUI, 6'b100001, F_LUI);
        check("jal",           7'd0,  3'b000, OP_JAL, 6'b100010, F_JUMP);
        check("jal other bits", 7'h55, 3'b111, OP_JAL, 6'b100010, F_JUMP);

        // ================= CORDIC (opcode 1111111) =================
        $display("--- CORDIC, idle (busy=0 done=0) ---");
        cordic_busy = 0; cordic_done = 0;
        check("sin idle", 7'd0, 3'b000, OP_CORDIC, 6'b100100, F_CSTART | F_STALL);
        check("cos idle", 7'd0, 3'b001, OP_CORDIC, 6'b100101, F_CSTART | F_STALL);
        check("exp idle", 7'd0, 3'b010, OP_CORDIC, 6'b100110, F_CSTART | F_STALL);
        check("log idle", 7'd0, 3'b011, OP_CORDIC, 6'b100111, F_CSTART | F_STALL);
        check("cordic imm bits ignored", 7'h7F, 3'b000, OP_CORDIC, 6'b100100, F_CSTART | F_STALL);

        $display("--- CORDIC, working (busy=1 done=0) ---");
        cordic_busy = 1; cordic_done = 0;
        check("sin busy", 7'd0, 3'b000, OP_CORDIC, 6'b100100, F_STALL);
        check("log busy", 7'd0, 3'b011, OP_CORDIC, 6'b100111, F_STALL);

        $display("--- CORDIC, result ready (done=1) ---");
        cordic_busy = 0; cordic_done = 1;
        check("sin done", 7'd0, 3'b000, OP_CORDIC, 6'b100100, F_NONE);
        cordic_busy = 1; cordic_done = 1;
        check("cos busy+done", 7'd0, 3'b001, OP_CORDIC, 6'b100101, F_NONE);

        $display("--- CORDIC, illegal funct3 never stalls ---");
        cordic_busy = 0; cordic_done = 0;
        check("cordic f3=100", 7'd0, 3'b100, OP_CORDIC, 6'b000000, F_NONE);
        check("cordic f3=111", 7'd0, 3'b111, OP_CORDIC, 6'b000000, F_NONE);

        // ================= FPU (opcode 1111110) =================
        $display("--- FPU ---");
        cordic_busy = 0; cordic_done = 0; fpu_busy = 0; fpu_done = 0;
        check("fpu idle",   7'd0,  3'b000, OP_FPU, 6'b101000, F_FSTART | F_STALL);
        check("fpu idle f7=32 f3=5", 7'd32, 3'b101, OP_FPU, 6'b101000, F_FSTART | F_STALL);
        fpu_busy = 1; fpu_done = 0;
        check("fpu busy",   7'd0,  3'b000, OP_FPU, 6'b101000, F_STALL);
        fpu_busy = 0; fpu_done = 1;
        check("fpu done",   7'd0,  3'b000, OP_FPU, 6'b101000, F_NONE);
        fpu_busy = 1; fpu_done = 1;
        check("fpu busy+done", 7'd0, 3'b000, OP_FPU, 6'b101000, F_NONE);

        // the two units must not affect each other
        $display("--- unit isolation ---");
        fpu_busy = 0; fpu_done = 0; cordic_busy = 0; cordic_done = 1;
        check("fpu ignores cordic_done", 7'd0, 3'b000, OP_FPU, 6'b101000, F_FSTART | F_STALL);
        cordic_done = 0; fpu_busy = 0; fpu_done = 1;
        check("cordic ignores fpu_done", 7'd0, 3'b000, OP_CORDIC, 6'b100100, F_CSTART | F_STALL);
        fpu_done = 0;

        // normal instructions never stall, whatever the status inputs say
        $display("--- status inputs don't affect normal instructions ---");
        cordic_busy = 1; fpu_busy = 1; cordic_done = 0; fpu_done = 0;
        check("add with units busy", 7'd0, 3'b000, OP_R, 6'b000001, F_NONE);
        check("lw with units busy",  7'd0, 3'b010, OP_LOAD, 6'b010101, F_M2R);
        cordic_busy = 0; fpu_busy = 0;

        // ================= reset =================
        $display("--- reset forces everything to 0 ---");
        reset = 1;
        check("add in reset",    7'd0, 3'b000, OP_R,      6'b000000, F_NONE);
        check("lb in reset",     7'd0, 3'b000, OP_LOAD,   6'b000000, F_NONE);
        check("sw in reset",     7'd0, 3'b010, OP_STORE,  6'b000000, F_NONE);
        check("beq in reset",    7'd0, 3'b000, OP_BRANCH, 6'b000000, F_NONE);
        check("jal in reset",    7'd0, 3'b000, OP_JAL,    6'b000000, F_NONE);
        check("cordic in reset", 7'd0, 3'b000, OP_CORDIC, 6'b000000, F_NONE);
        check("fpu in reset",    7'd0, 3'b000, OP_FPU,    6'b000000, F_NONE);
        reset = 0;
        check("add after reset", 7'd0, 3'b000, OP_R, 6'b000001, F_NONE);

        // ================= unknown opcodes =================
        $display("--- unknown opcodes ---");
        check("all zero instr",  7'd0,  3'b000, 7'b0000000, 6'b000000, F_NONE);
        check("opcode 1010101",  7'd0,  3'b000, 7'b1010101, 6'b000000, F_NONE);
        check("opcode 1111101",  7'd0,  3'b000, 7'b1111101, 6'b000000, F_NONE);
        check("opcode 1111100",  7'd0,  3'b011, 7'b1111100, 6'b000000, F_NONE);

        // ================= real instructions from program.hex =================
        $display("--- program.hex instructions ---");
        check_instr("addi x1,x0,5",  32'h00500093, 6'b001011, F_NONE);
        check_instr("addi x2,x0,10", 32'h00A00113, 6'b001011, F_NONE);
        check_instr("add x3,x1,x2",  32'h002081B3, 6'b000001, F_NONE);
        check_instr("sub x4,x2,x1",  32'h40110233, 6'b000010, F_NONE);
        check_instr("and x5,x1,x2",  32'h0020F2B3, 6'b001010, F_NONE);
        check_instr("or x6,x1,x2",   32'h0020E333, 6'b001001, F_NONE);
        check_instr("sw x3,0(x0)",   32'h00302023, 6'b011010, F_SW);
        check_instr("lw x7,0(x0)",   32'h00002383, 6'b010101, F_M2R);
        check_instr("beq x3,x7,+8",  32'h00718463, 6'b011011, F_BEQ);
        check_instr("addi x9,x0,99",  32'h06300493, 6'b001011, F_NONE);
        check_instr("jal x0,0",      32'h0000006F, 6'b100010, F_JUMP);

        // ================= summary =================
        $display("-----------------------------------------");
        if (errors == 0) $display("ALL %0d CU TESTS PASSED", tests);
        else             $display("%0d of %0d CU TESTS FAILED", errors, tests);
        $finish;
    end
endmodule
