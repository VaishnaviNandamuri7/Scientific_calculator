`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Board_Top_tb
//
// Plays the part of load.py, so the board path can be checked without a board:
//   1. reads program.hex and sends 0xA5 + 128 bytes into the UART pin
//   2. receives the 256 bytes Board_Top sends back
//   3. writes them to board_output.hex (same format as output.hex)
//      and checks them against the CPU's data memory
// It does this twice, to check that loading again works.
//////////////////////////////////////////////////////////////////////////////////

module Board_Top_tb;
    localparam integer CLKS_PER_BIT = 26;                  // same as Board_Top
    localparam integer BIT_NS = CLKS_PER_BIT * 1000;       // the CPU clock is 1 MHz
    localparam [31:0]  DONE_MARKER = 32'h600D600D;

    reg  clk = 0, resetn = 0, rx = 1;
    wire tx;
    wire [3:0] led;

    reg  [7:0]  program_bytes [0:127];
    reg  [31:0] words [0:63];
    integer i, run, fd, errors = 0;

    Board_Top #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut(
        .CLK100MHZ(clk), .CPU_RESETN(resetn),
        .UART_TXD_IN(rx), .UART_RXD_OUT(tx), .LED(led)
    );

    always #5 clk = ~clk;                                  // 100 MHz

    // one byte into the board: start bit, 8 data bits LSB first, stop bit
    task send_byte;
        input [7:0] b;
        integer k;
        begin
            rx = 0; #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin rx = b[k]; #(BIT_NS); end
            rx = 1; #(BIT_NS);
        end
    endtask

    // one byte from the board, sampled in the middle of each bit
    task recv_byte;
        output [7:0] b;
        integer k;
        begin
            @(negedge tx);
            #(BIT_NS / 2);
            for (k = 0; k < 8; k = k + 1) begin #(BIT_NS); b[k] = tx; end
            #(BIT_NS);
        end
    endtask

    task send_program;
        begin
            send_byte(8'hA5);
            for (i = 0; i < 128; i = i + 1) send_byte(program_bytes[i]);
        end
    endtask

    task recv_result;
        integer w;
        reg [7:0] b0, b1, b2, b3;
        begin
            for (w = 0; w < 64; w = w + 1) begin
                recv_byte(b0); recv_byte(b1); recv_byte(b2); recv_byte(b3);
                words[w] = {b3, b2, b1, b0};
            end
        end
    endtask

    initial begin
        // unused bytes are 0, like load.py sends them
        for (i = 0; i < 128; i = i + 1) program_bytes[i] = 8'h00;
        $readmemh("program.hex", program_bytes);

        #1000 resetn = 1;
        #5000;

        for (run = 1; run <= 2; run = run + 1) begin
            fork
                send_program;
                recv_result;
            join

            $display("run %0d: word 0 = %h, word 1 = %h", run, words[0], words[1]);
            for (i = 0; i < 64; i = i + 1)
                if (words[i] !== dut.dp.dm.ram[i]) begin
                    $display("FAIL word %0d: board sent %h, data memory has %h", i, words[i], dut.dp.dm.ram[i]);
                    errors = errors + 1;
                end
            if (words[1] !== DONE_MARKER) begin
                $display("FAIL done marker missing");
                errors = errors + 1;
            end
            #(BIT_NS * 4);
        end

        fd = $fopen("board_output.hex", "w");
        for (i = 0; i < 64; i = i + 1)
            $fdisplay(fd, "%h", words[i]);
        $fclose(fd);

        if (errors == 0) $display("ALL BOARD TESTS PASSED");
        else             $display("%0d BOARD TEST(S) FAILED", errors);
        $finish;
    end

    // timeout guard: two runs take about 2 x 385 bytes x 10 bits x 26 us = 0.2 s
    initial begin
        #1_000_000_000;
        $display("TIMEOUT: the board never answered (no halt reached?)");
        $finish;
    end
endmodule
