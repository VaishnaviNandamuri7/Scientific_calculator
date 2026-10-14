`timescale 1ns / 1ps

module Top_RISC_tb;
    reg clock = 0, reset = 1;
    integer errors = 0;

    Top_RISC dut(.clock(clock), .reset(reset));

    always #5 clock = ~clock;

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

    initial begin
        #22 reset = 0;
        repeat (40) @(posedge clock);
        #1;

        // program.hex
        check_reg(1, 32'd5);
        check_reg(2, 32'd10);
        check_reg(3, 32'd15);
        check_reg(4, 32'd5);
        check_reg(5, 32'd0);
        check_reg(6, 32'd15);
        check_reg(7, 32'd15);   // sw then lw round trip
        check_reg(8, 32'd0);    // skipped by the beq
        check_reg(9, 32'd99);

        if (dut.dp.dm.ram[0] !== 32'd15) begin
            $display("FAIL mem[0] = %h, expected 0000000f", dut.dp.dm.ram[0]);
            errors = errors + 1;
        end else
            $display("pass mem[0] = 0000000f");

        if (dut.dp.PC !== 32'h2C) begin
            $display("FAIL PC = %h, expected 2c (jal loop)", dut.dp.PC);
            errors = errors + 1;
        end else
            $display("pass PC parked at 2c");

        if (errors == 0) $display("ALL TOP TESTS PASSED");
        else             $display("%0d TOP TEST(S) FAILED", errors);
        $finish;
    end
endmodule