`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2026 11:12:45
// Design Name: 
// Module Name: tb_cordic
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


module tb_cordic;
    reg clk = 0, rst_n = 0, en = 0, start = 0;
    reg  [2:0] funct3 = 0;
    reg  signed [31:0] reg_data = 0;
    wire busy, done;
    wire signed [31:0] result;
    integer errors = 0;
    integer cycles;

    localparam SIN = 0, COS = 1, TAN = 2, EXP = 3, LN = 4, SQRT = 5;
    localparam signed [31:0] MAXQ = 32'sh7FFFFFFF;
    localparam signed [31:0] MINQ = 32'sh80000000;

    cordic_block dut(
        .clk(clk), .rst_n(rst_n), .en(en), .cordic_start(start),
        .funct3(funct3), .use_imm(1'b0),
        .reg_data(reg_data), .immediate(32'sd0),
        .cordic_busy(busy), .cordic_done(done), .cordic_out(result)
    );

    always #5 clk = ~clk;

    // run one op, leaves the raw result in "result"
    task run;
        input [2:0] op;
        input signed [31:0] x;
        begin
            @(negedge clk);
            en = 1; funct3 = op; reg_data = x; start = 1; cycles = 0;
            @(negedge clk);
            start = 0;
            while (!done && cycles < 200) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!done) begin
                $display("FAIL: op=%0d x=%0d never finished", op, x);
                errors = errors + 1;
            end
            @(negedge clk);
            en = 0;
        end
    endtask

    // compare against real math, tolerance 3e-4 + 3e-4*|expected|
    task check;
        input [2:0] op;
        input real x;
        input real expected;
        real got, tol;
        begin
            run(op, $rtoi($floor(x * 65536.0 + 0.5)));
            got = $itor(result) / 65536.0;
            tol = 3.0e-4 + 3.0e-4 * ((expected < 0.0) ? -expected : expected);
            if ((got - expected < tol) && (expected - got < tol))
                $display("pass op=%0d x=%f -> %f", op, x, got);
            else begin
                $display("FAIL op=%0d x=%f got=%f expected=%f", op, x, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    // exact raw compare, for saturation and error markers
    task check_raw;
        input [2:0] op;
        input real x;
        input signed [31:0] expected;
        begin
            run(op, $rtoi($floor(x * 65536.0 + 0.5)));
            if (result === expected)
                $display("pass op=%0d x=%f -> %h", op, x, result);
            else begin
                $display("FAIL op=%0d x=%f got=%h expected=%h", op, x, result, expected);
                errors = errors + 1;
            end
        end
    endtask

    // the quantized input is what the hardware actually sees
    function real q;
        input real x;
        begin
            q = $floor(x * 65536.0 + 0.5) / 65536.0;
        end
    endfunction

    task trig;
        input real x;
        begin
            check(SIN, x, $sin(q(x)));
            check(COS, x, $cos(q(x)));
        end
    endtask

    initial begin
        #22 rst_n = 1;

        $display("--- sin/cos, inside and outside +-pi ---");
        trig(0.0);
        trig(0.5);
        trig(1.0);
        trig(1.5708);
        trig(2.0);
        trig(3.0);
        trig(3.1416);
        trig(-2.5);
        trig(4.0);
        trig(-4.7);
        trig(10.0);
        trig(-100.0);
        trig(1000.5);
        trig(20000.25);
        trig(-32000.0);

        $display("--- tan ---");
        check(TAN, 0.0,    $tan(q(0.0)));
        check(TAN, 0.5,    $tan(q(0.5)));
        check(TAN, 1.0,    $tan(q(1.0)));
        check(TAN, -1.0,   $tan(q(-1.0)));
        check(TAN, 2.0,    $tan(q(2.0)));
        check(TAN, 3.0,    $tan(q(3.0)));
        check(TAN, 10.0,   $tan(q(10.0)));
        check(TAN, 100.0,  $tan(q(100.0)));
        check(TAN, 1000.0, $tan(q(1000.0)));

        $display("--- exp ---");
        check(EXP, 0.0,   $exp(q(0.0)));
        check(EXP, 0.5,   $exp(q(0.5)));
        check(EXP, 1.0,   $exp(q(1.0)));
        check(EXP, -1.0,  $exp(q(-1.0)));
        check(EXP, 2.0,   $exp(q(2.0)));
        check(EXP, -5.0,  $exp(q(-5.0)));
        check(EXP, 5.0,   $exp(q(5.0)));
        check(EXP, 9.0,   $exp(q(9.0)));
        check(EXP, 10.3,  $exp(q(10.3)));
        check_raw(EXP, 11.0,  MAXQ);   // overflow saturates
        check_raw(EXP, 20.0,  MAXQ);
        check_raw(EXP, -12.0, 32'sd0); // underflow
        check_raw(EXP, -20.0, 32'sd0);

        $display("--- ln ---");
        check(LN, 1.0,     $ln(q(1.0)));
        check(LN, 2.0,     $ln(q(2.0)));
        check(LN, 0.5,     $ln(q(0.5)));
        check(LN, 10.0,    $ln(q(10.0)));
        check(LN, 0.001,   $ln(q(0.001)));
        check(LN, 100.0,   $ln(q(100.0)));
        check(LN, 1000.5,  $ln(q(1000.5)));
        check(LN, 30000.0, $ln(q(30000.0)));
        check_raw(LN, 0.0,  MINQ);     // ln(0) marker
        check_raw(LN, -3.0, MINQ);     // ln(negative) marker

        $display("--- sqrt ---");
        check(SQRT, 1.0,     $sqrt(q(1.0)));
        check(SQRT, 2.0,     $sqrt(q(2.0)));
        check(SQRT, 4.0,     $sqrt(q(4.0)));
        check(SQRT, 9.0,     $sqrt(q(9.0)));
        check(SQRT, 0.25,    $sqrt(q(0.25)));
        check(SQRT, 0.01,    $sqrt(q(0.01)));
        check(SQRT, 100.0,   $sqrt(q(100.0)));
        check(SQRT, 1000.0,  $sqrt(q(1000.0)));
        check(SQRT, 12345.678, $sqrt(q(12345.678)));
        check(SQRT, 32767.0, $sqrt(q(32767.0)));
        check_raw(SQRT, 0.0,  32'sd0);
        check_raw(SQRT, -4.0, 32'sd0);

        $display("--- illegal funct3 never starts ---");
        @(negedge clk);
        en = 1; funct3 = 3'b110; reg_data = 32'sd65536; start = 1;
        repeat (30) begin
            @(negedge clk);
            if (busy || done) begin
                $display("FAIL: funct3=110 started the unit");
                errors = errors + 1;
            end
        end
        start = 0; en = 0;
        $display("pass funct3=110 ignored");

        if (errors == 0) $display("ALL CORDIC TESTS PASSED");
        else             $display("%0d CORDIC TEST(S) FAILED", errors);
        $finish;
    end
endmodule