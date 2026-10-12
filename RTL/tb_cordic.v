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
    reg        clk;              // 100 MHz reference clock
    reg        rst_n;            // Active-low master reset
    reg        en;               // Control Unit block enable[cite: 1]
    reg        cordic_start;     // Single-cycle execution start trigger[cite: 1]
    reg [2:0]  funct3;           // RISC-V 3-bit funct3 operation selector[cite: 1]
    reg        use_imm;          // 0 = register operand, 1 = immediate operand
    reg signed [31:0] reg_data;  // Input data bus from Register File[cite: 1]
    reg signed [31:0] immediate; // Unused in register sweep mode[cite: 1]

    // Observed Outputs from CORDIC Block
   
    wire        cordic_busy;     // Asserted during calculation; stalls CPU fetch[cite: 1]
    wire        cordic_done;     // Asserted for 1 cycle upon completion[cite: 1]
    wire signed [31:0] cordic_out; // 32-bit Q16.16 output bus (displayed as analog)[cite: 1]

    cordic_block uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .cordic_start(cordic_start),
        .funct3(funct3),
        .use_imm(use_imm),
        .reg_data(reg_data),
        .immediate(immediate),
        .cordic_busy(cordic_busy),
        .cordic_done(cordic_done),
        .cordic_out(cordic_out)
    );

    // 100 MHz clock generation (10 ns clock cycle)
    always #5 clk = ~clk;

    localparam [2:0] OP_SIN  = 3'b000;
    localparam [2:0] OP_COS  = 3'b001;
    localparam [2:0] OP_TAN  = 3'b010;
    localparam [2:0] OP_EXP  = 3'b011;
    localparam [2:0] OP_LN   = 3'b100;
    localparam [2:0] OP_SQRT = 3'b101;

    localparam signed [31:0] PI_VAL       = 32'sd205887; // pi  = ~3.141593 rad
    localparam signed [31:0] TAN_BOUND    =  32'sd88474; // 1.35 rad (avoids inf asymptote)
    localparam signed [31:0] SQRT_START   =   32'sd3276; // 0.05
    localparam signed [31:0] SQRT_STOP    = 32'sd262144; // 4.00
    localparam signed [31:0] EXP_START    = -32'sd98304; // -1.50
    localparam signed [31:0] EXP_STOP     =  32'sd81920; // +1.25 (e^1.25 = ~3.49)
    localparam signed [31:0] LN_START     =  32'sd13107; // 0.20
    localparam signed [31:0] LN_STOP      = 32'sd229376; // 3.50

    integer branch;
    reg signed [31:0] sweep_val;
    // Reusable Task: Executes a single CORDIC operation and waits for done
    task run_point(input [2:0] op, input signed [31:0] val);
        begin
            @(posedge clk);
            en           <= 1'b1;        // CU asserts block enable[cite: 1]
            funct3       <= op;          // Load function opcode[cite: 1]
            use_imm      <= 1'b0;        // Route from reg_data[cite: 1]
            reg_data     <= val;         // Provide Q16.16 operand[cite: 1]
            cordic_start <= 1'b1;        // Trigger calculation[cite: 1]

            @(posedge clk);
            cordic_start <= 1'b0;        // Deassert start pulse

            @(posedge cordic_done);      // Wait until 16 iterations finish[cite: 1]
            @(posedge clk);
            en           <= 1'b0;        // Release enable[cite: 1]
        end
    endtask

    // Main Simulation Process: Sweeping All Functions Sequentially

    initial begin
        // Reset and initialization
        clk          = 0;
        rst_n        = 0;
        en           = 0;
        cordic_start = 0;
        funct3       = 3'b000;
        use_imm      = 0;
        reg_data     = 32'sd0;
        immediate    = 32'sd0;

        #40;
        rst_n = 1;
        #20;

        // SECTION 1: SINE WAVEFORM SWEEP (-pi to +pi)
        // Generates a smooth standard sinusoidal analog cycle
        sweep_val = -PI_VAL;
        while (sweep_val <= PI_VAL) begin
            run_point(OP_SIN, sweep_val);
            sweep_val = sweep_val + 32'sd4289; // ~96 discrete points per wave
        end
        #100; // Flat separation zone

        // SECTION 2: COSINE WAVEFORM SWEEP (-pi to +pi)
        // Generates a smooth cosine curve with a 90-degree phase lead
       
        sweep_val = -PI_VAL;
        while (sweep_val <= PI_VAL) begin
            run_point(OP_COS, sweep_val);
            sweep_val = sweep_val + 32'sd4289;
        end
        #100;

        // =====================================================================
        // SECTION 3: TANGENT WAVEFORM SWEEP (3 Periodic Branches)
        // Sweeps through [-1.35 rad, +1.35 rad] to show S-curve periodicity
        // =====================================================================
        for (branch = 0; branch < 3; branch = branch + 1) begin
            sweep_val = -TAN_BOUND;
            while (sweep_val <= TAN_BOUND) begin
                run_point(OP_TAN, sweep_val);
                sweep_val = sweep_val + 32'sd3686;
            end
        end
        #100;

        // =====================================================================
        // SECTION 4: SQUARE ROOT CURVE SWEEP (0.05 to 4.00)
        // Generates a classic square-root curve rising and flattening
        // =====================================================================
        sweep_val = SQRT_START;
        while (sweep_val <= SQRT_STOP) begin
            run_point(OP_SQRT, sweep_val);
            sweep_val = sweep_val + 32'sd3932; // Steps of ~0.06
        end
        #100;

        // =====================================================================
        // SECTION 5: NATURAL EXPONENTIAL (e^x) CURVE SWEEP (-1.50 to +1.25)
        // Generates a steep exponential growth curve
        // =====================================================================
        sweep_val = EXP_START;
        while (sweep_val <= EXP_STOP) begin
            run_point(OP_EXP, sweep_val);
            sweep_val = sweep_val + 32'sd2816; // Fine resolution
        end
        #100;

        // =====================================================================
        // SECTION 6: NATURAL LOGARITHM (ln x) CURVE SWEEP (0.20 to 3.50)
        // Generates a logarithmic curve crossing zero at x = 1.0 (65536)
        // =====================================================================
        sweep_val = LN_START;
        while (sweep_val <= LN_STOP) begin
            run_point(OP_LN, sweep_val);
            sweep_val = sweep_val + 32'sd3379;
        end

        #200;
        $finish; // End of full sweep
    end

endmodule