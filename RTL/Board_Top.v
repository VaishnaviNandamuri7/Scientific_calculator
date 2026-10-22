`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Board_Top - the CPU on the Nexys 4 DDR / Nexys A7-100T board
//
// Does on the board what Top_RISC_tb does in simulation:
//   1. waits for a program from the PC (Tools/load.py) over the USB-UART:
//        0xA5, then 128 program bytes (same bytes and order as program.hex)
//      While loading, the CPU is held in reset and the data memory is cleared.
//   2. releases the CPU reset and lets it run
//   3. stops when the CPU reaches the halt instruction  jal x0, 0  (0x0000006F)
//   4. sends the 64 data memory words back (what output.hex holds in simulation),
//      word 0 first, each word lowest byte first = 256 bytes
// A new 0xA5 while the CPU runs (e.g. a program with no halt) starts a new load.
//
// LEDs:  LED0 = loading,  LED1 = running,  LED2 = halted,  LED3 = sending
//////////////////////////////////////////////////////////////////////////////////

module Board_Top #(
    // UART bit length in CPU clock cycles: 1 MHz / 38400 baud = 26.04 -> 26
    // (load.py uses the same 38400 baud)
    parameter CLKS_PER_BIT = 26
)(
    input CLK100MHZ,          // 100 MHz board oscillator
    input CPU_RESETN,         // red CPU RESET button, 0 when pressed
    input UART_TXD_IN,        // PC -> FPGA
    output UART_RXD_OUT,      // FPGA -> PC
    output [3:0] LED
);
    localparam [7:0]  HEADER = 8'hA5;
    localparam [31:0] HALT   = 32'h0000006F;  // jal x0, 0

    // ---------- clock: 100 MHz / 100 = 1 MHz ----------
    // The FPU divide and the CORDIC tan are each done in one clock cycle
    // (a big combinational divider), far too slow for 100 MHz.
    // So the whole board design (CPU, UART, loader) runs on a 1 MHz clock.
    // A calculation takes about 30 cycles = 30 us, so speed does not matter.
    // The xdc file tells Vivado about this clock (create_generated_clock).
    reg [5:0] div_count = 0;
    reg       clk_slow = 1'b0;
    always @(posedge CLK100MHZ) begin
        if (div_count == 6'd49) begin      // toggle every 50 cycles -> period 100 cycles
            div_count <= 0;
            clk_slow  <= ~clk_slow;
        end
        else div_count <= div_count + 1'b1;
    end

    wire clk;
    BUFG clk_buffer(.I(clk_slow), .O(clk));   // put the clock on a global clock line

    // ---------- reset: the CPU RESET button ----------
    reg [1:0] reset_sync = 2'b11;  // two flip-flops: the button is not in step with clk
    always @(posedge clk)
        reset_sync <= {reset_sync[0], ~CPU_RESETN};
    wire reset = reset_sync[1];

    // ---------- UART ----------
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       tx_busy;
    reg  [7:0] tx_data;

    // ---------- loader state machine ----------
    localparam WAIT_HEADER = 3'd0;
    localparam LOAD        = 3'd1;  // receiving the 128 program bytes
    localparam RUN         = 3'd2;  // CPU running
    localparam SEND        = 3'd3;  // hand one byte to uart_tx
    localparam SEND_WAIT   = 3'd4;  // wait until uart_tx has sent it

    reg [2:0] state = WAIT_HEADER;
    reg [6:0] load_count = 0;      // program byte 0..127
    reg [7:0] send_count = 0;      // result byte 0..255 (word = send_count / 4)
    reg       cpu_reset = 1'b1;    // CPU runs only in RUN
    reg       halted = 1'b0;       // for LED2

    wire [31:0] dump_word;
    wire [31:0] instruction;

    // 0xA5 starts a load when idle or while the CPU runs
    wire header_seen = rx_valid && (rx_data == HEADER) && (state == WAIT_HEADER || state == RUN);

    datapath dp(
        .clock(clk), .reset(cpu_reset),
        .imem_we(state == LOAD && rx_valid), .imem_addr(load_count), .imem_data(rx_data),
        .dmem_clear(header_seen), .dmem_dump_addr(send_count[7:2]), .dmem_dump_data(dump_word),
        .current_instruction(instruction)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_unit(
        .clk(clk), .reset(reset), .rx(UART_TXD_IN),
        .data(rx_data), .valid(rx_valid)
    );

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_unit(
        .clk(clk), .reset(reset), .start(state == SEND), .data(tx_data),
        .tx(UART_RXD_OUT), .busy(tx_busy)
    );

    // pick the byte of the current word, lowest byte first (same order as program.hex)
    always @(*) begin
        case (send_count[1:0])
            2'd0: tx_data = dump_word[7:0];
            2'd1: tx_data = dump_word[15:8];
            2'd2: tx_data = dump_word[23:16];
            default: tx_data = dump_word[31:24];
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT_HEADER;
            load_count <= 0;
            send_count <= 0;
            cpu_reset <= 1'b1;
            halted <= 1'b0;
        end
        else if (header_seen) begin
            // data memory is cleared this cycle (dmem_clear), the CPU is stopped
            state <= LOAD;
            load_count <= 0;
            cpu_reset <= 1'b1;
            halted <= 1'b0;
        end
        else begin
            case (state)
                LOAD: begin
                    if (rx_valid) begin              // the byte is written into the IMU this cycle
                        load_count <= load_count + 1'b1;
                        if (load_count == 7'd127) begin
                            state <= RUN;
                            cpu_reset <= 1'b0;
                        end
                    end
                end

                RUN: begin
                    // single cycle CPU: when the halt is fetched, every store before it is done
                    if (instruction == HALT) begin
                        state <= SEND;
                        send_count <= 0;
                        cpu_reset <= 1'b1;           // freeze the CPU, the data memory keeps its values
                        halted <= 1'b1;
                    end
                end

                SEND: state <= SEND_WAIT;            // uart_tx takes tx_data at this edge

                SEND_WAIT: begin
                    if (!tx_busy) begin
                        if (send_count == 8'd255) state <= WAIT_HEADER;
                        else begin
                            send_count <= send_count + 1'b1;
                            state <= SEND;
                        end
                    end
                end

                default: state <= WAIT_HEADER;       // WAIT_HEADER: only header_seen leaves it
            endcase
        end
    end

    assign LED[0] = (state == LOAD);
    assign LED[1] = (state == RUN);
    assign LED[2] = halted;
    assign LED[3] = (state == SEND) || (state == SEND_WAIT);
endmodule
