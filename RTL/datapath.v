`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 14.10.2026 13:57:54
// Design Name:
// Module Name: datapath
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


module datapath(//single cycle data path
    input clock,
    input reset
    );
    //fetch
    wire [31:0] PC, curr_PC, instruction;
    //decode
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [4:0] rd  = instruction[11:7];
    wire [31:0] imm, imm_addre, imm_J, lui_imm_val;
    //control
    wire [5:0] alu_control;
    wire lb, mem_to_reg, bneq_control, beq_control, bgeq_control, blt_control;
    wire jump, sw, lui_control, cordic_start, fpu_start, stall;
    //data
    wire [31:0] rs1_data, rs2_data, alu_result, mem_data;
    wire [31:0] cordic_out, fpu_result;
    wire cordic_busy, cordic_done, fpu_busy, fpu_done;
    reg  [31:0] write_data;

    //opcode flags
    wire is_cordic = (opcode == 7'b111_1111);
    wire is_fpu    = (opcode == 7'b111_1110);
    wire writes_rd = (opcode == 7'b011_0011) | (opcode == 7'b001_0011) | (opcode == 7'b000_0011) |
                     (opcode == 7'b011_0111) | (opcode == 7'b110_1111) | is_cordic | is_fpu;
    wire reg_write = writes_rd & ~stall;//no write while cordic/fpu is working

    //branch taken = branch type & alu compare result
    wire BEQ  = beq_control  & alu_result[0];
    wire BENQ = bneq_control & alu_result[0];
    wire BGE  = bgeq_control & alu_result[0];
    wire BLT  = blt_control  & alu_result[0];

    //write back select
    always @(*) begin
        if (jump)             write_data = curr_PC;
        else if (lui_control) write_data = lui_imm_val;
        else if (mem_to_reg)  write_data = mem_data;
        else if (is_cordic)   write_data = cordic_out;
        else if (is_fpu)      write_data = fpu_result;
        else                  write_data = alu_result;
    end

    IFU ifu(//instruction fetch unit
        .clk(clock), .reset(reset),
        .imm_addre(imm_addre), .imm_J(imm_J),
        .BEQ(BEQ), .BENQ(BENQ), .BGE(BGE), .BLT(BLT),
        .jump(jump), .stall(stall),
        .PC(PC), .curr_PC(curr_PC)
    );

    IMU #(.PROGRAM_FILE("program.hex")) imu(//instruction memory unit
        .clk(clock), .PC(PC), .reset(reset),
        .instruction(instruction)
    );

    imm_gen immgen(
        .instruction(instruction),
        .imm(imm), .imm_addre(imm_addre), .imm_J(imm_J), .lui_imm_val(lui_imm_val)
    );

    CU cu(//control unit
        .reset(reset), .clk(clock),
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

    register_file rf(
        .clk(clock), .reset(reset), .reg_write(reg_write),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .write_data(write_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    alu alu0(
        .src1(rs1_data), .src2(rs2_data),
        .alu_control(alu_control), .imm(imm),
        .shift(instruction[23:20]),//unused by the alu
        .result(alu_result)
    );

    data_memory dm(
        .clk(clock), .mem_addr(alu_result), .write_data(rs2_data),
        .sw(sw), .funct3(funct3), .read_data(mem_data)
    );

    cordic_block cordic(
        .clk(clock), .rst_n(~reset),
        .en(is_cordic), .cordic_start(cordic_start),
        .funct3(funct3), .use_imm(1'b0),//1 = take imm instead of rs1
        .reg_data(rs1_data), .immediate(imm),
        .cordic_busy(cordic_busy), .cordic_done(cordic_done), .cordic_out(cordic_out)
    );

    FPU fpu(
        .clk(clock), .reset(reset), .start(fpu_start),
        .funct7(funct7), .funct3(funct3),
        .a(rs1_data), .b(rs2_data),
        .result(fpu_result), .busy(fpu_busy), .done(fpu_done)
    );
endmodule