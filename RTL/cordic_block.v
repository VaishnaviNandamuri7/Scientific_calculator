`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2026 11:11:17
// Design Name: 
// Module Name: cordic_block
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

module cordic_block (
    input  wire        clk,          // System clock from CPU datapath
    input  wire        rst_n,        // Active-low master reset
    input  wire        en,           // Block enable derived from CU (ALUcontrol & opcode)
    input  wire        cordic_start, // Start trigger pulse from Control Unit (CU)
    input  wire [2:0]  funct3,       // RISC-V instruction funct3 selecting CORDIC function
    input  wire        use_imm,      // Flag from CU: 1 = select immediate, 0 = select register
    input  wire signed [31:0] reg_data,  // 32-bit Q16.16 operand read from Register File
    input  wire signed [31:0] immediate, // 32-bit Q16.16 immediate operand from instruction
    output reg         cordic_busy,  // High while calculating; CU uses this to stall PC
    output reg         cordic_done,  // 1-cycle completion pulse; signals CU to drop stall
    output reg  signed [31:0] cordic_out // 32-bit Q16.16 result routed back to Register File
);

    // funct3 opcode decoding definitions
    localparam FN3_SIN  = 3'b000; // funct3 code for SIN
    localparam FN3_COS  = 3'b001; // funct3 code for COS
    localparam FN3_TAN  = 3'b010; // funct3 code for TAN
    localparam FN3_EXP  = 3'b011; // funct3 code for EXP (e^x)
    localparam FN3_LN   = 3'b100; // funct3 code for LN (ln x)
    localparam FN3_SQRT = 3'b101; // funct3 code for SQRT (sqrt x)

    // Pre-calculated fixed-point constants in Q16.16 format
    localparam signed [31:0] INV_K1    = 32'sh00009B75; // 1/K1 = ~0.607253 (Circular scaling reciprocal)
    localparam signed [31:0] INV_KN1   = 32'sh0001351E; // 1/K_{-1} = ~1.207497 (Hyperbolic scaling reciprocal)
    localparam signed [31:0] CONST_ONE = 32'sh00010000; // 1.0 in Q16.16 (65536)
    localparam signed [31:0] CONST_QTR = 32'sh00004000; // 0.25 in Q16.16 (16384)
    localparam signed [31:0] PI_HALF   = 32'sh00019220; // pi/2 = ~1.570796 rad in Q16.16
    localparam signed [31:0] PI_CONST  = 32'sh0003243F; // pi   = ~3.141593 rad in Q16.16

    // Datapath FSM state encodings
    localparam IDLE = 2'd0; // Idle state: waiting for enable and start command
    localparam CALC = 2'd1; // Calculation state: actively performing rotation steps
    localparam POST = 2'd2; // Post-processing state: final scaling, division, and output write
    reg [1:0] state;        // Current FSM state register

    // Internal pipeline registers
    reg [4:0]  iter;         // Iteration counter (0 to 15)
    reg [2:0]  fn3_latched;  // Latched funct3 instruction code
    reg        negate_trig;  // Flag for trigonometric quadrant 2/3 sign inversion
    reg signed [31:0] x;     // Datapath register X (accumulates cos, cosh, or square root norm)
    reg signed [31:0] y;     // Datapath register Y (accumulates sin, sinh, or vector residual)
    reg signed [31:0] z;     // Datapath register Z (accumulates angle or logarithm)

    // Combinational signals
    reg signed [31:0] angle_lut; // Angle read from lookup table for current step
    reg [4:0]         shift_amt; // Right-shift magnitude for current step

    // Operand Multiplexer: selects between Register File data or Immediate value
    wire signed [31:0] operand = (use_imm) ? immediate : reg_data;

    // Elementary Angle Lookup Table and Shift Controller
    always @(*) begin
        if (fn3_latched == FN3_SIN || fn3_latched == FN3_COS || fn3_latched == FN3_TAN) begin
            shift_amt = iter; // Circular CORDIC: shift amount equals iteration index (0 to 15)
            case (iter)
                5'd0:  angle_lut = 32'sh0000C910; // atan(2^0)  = 0.785398 rad (~45.00 deg)
                5'd1:  angle_lut = 32'sh000076B2; // atan(2^-1) = 0.463648 rad (~26.57 deg)
                5'd2:  angle_lut = 32'sh00003EB7; // atan(2^-2) = 0.244979 rad (~14.04 deg)
                5'd3:  angle_lut = 32'sh00001FD6; // atan(2^-3) = 0.124355 rad (~7.13 deg)
                5'd4:  angle_lut = 32'sh00000FFB; // atan(2^-4) = 0.062419 rad (~3.58 deg)
                5'd5:  angle_lut = 32'sh000007FF; // atan(2^-5) = 0.031240 rad (~1.79 deg)
                5'd6:  angle_lut = 32'sh00000400; // atan(2^-6) = 0.015624 rad (~0.89 deg)
                5'd7:  angle_lut = 32'sh00000200; // atan(2^-7) = 0.007812 rad (~0.45 deg)
                5'd8:  angle_lut = 32'sh00000100; // atan(2^-8) = 0.003906 rad
                5'd9:  angle_lut = 32'sh00000080; // atan(2^-9) = 0.001953 rad
                5'd10: angle_lut = 32'sh00000040; // atan(2^-10) = 0.000977 rad
                5'd11: angle_lut = 32'sh00000020; // atan(2^-11) = 0.000488 rad
                5'd12: angle_lut = 32'sh00000010; // atan(2^-12) = 0.000244 rad
                5'd13: angle_lut = 32'sh00000008; // atan(2^-13) = 0.000122 rad
                5'd14: angle_lut = 32'sh00000004; // atan(2^-14) = 0.000061 rad
                default: angle_lut = 32'sh00000002;
            endcase
        end else begin
            // Hyperbolic CORDIC: shift sequence with repeated iterations at i=4 and i=13
            case (iter)
                5'd0:  begin shift_amt = 5'd1;  angle_lut = 32'sh00008CA0; end // atanh(2^-1) = 0.549306
                5'd1:  begin shift_amt = 5'd2;  angle_lut = 32'sh00004163; end // atanh(2^-2) = 0.255413
                5'd2:  begin shift_amt = 5'd3;  angle_lut = 32'sh0000202B; end // atanh(2^-3) = 0.125657
                5'd3:  begin shift_amt = 5'd4;  angle_lut = 32'sh00001005; end // atanh(2^-4) = 0.062582
                5'd4:  begin shift_amt = 5'd4;  angle_lut = 32'sh00001005; end // Repeat iteration 4
                5'd5:  begin shift_amt = 5'd5;  angle_lut = 32'sh00000801; end // atanh(2^-5) = 0.031260
                5'd6:  begin shift_amt = 5'd6;  angle_lut = 32'sh00000400; end // atanh(2^-6) = 0.015626
                5'd7:  begin shift_amt = 5'd7;  angle_lut = 32'sh00000200; end // atanh(2^-7) = 0.007813
                5'd8:  begin shift_amt = 5'd8;  angle_lut = 32'sh00000100; end // atanh(2^-8) = 0.003906
                5'd9:  begin shift_amt = 5'd9;  angle_lut = 32'sh00000080; end // atanh(2^-9) = 0.001953
                5'd10: begin shift_amt = 5'd10; angle_lut = 32'sh00000040; end // atanh(2^-10) = 0.000977
                5'd11: begin shift_amt = 5'd11; angle_lut = 32'sh00000020; end // atanh(2^-11) = 0.000488
                5'd12: begin shift_amt = 5'd12; angle_lut = 32'sh00000010; end // atanh(2^-12) = 0.000244
                5'd13: begin shift_amt = 5'd13; angle_lut = 32'sh00000008; end // atanh(2^-13) = 0.000122
                5'd14: begin shift_amt = 5'd13; angle_lut = 32'sh00000008; end // Repeat iteration 13
                default: begin shift_amt = 5'd14; angle_lut = 32'sh00000004; end
            endcase
        end
    end

    // Arithmetic right shifters for micro-rotations
    wire signed [31:0] x_shr = x >>> shift_amt; // x * 2^(-shift_amt)
    wire signed [31:0] y_shr = y >>> shift_amt; // y * 2^(-shift_amt)

    // Rotation direction decision:
    // Trig & Exp are in Rotation Mode (drive z -> 0); LN & SQRT are in Vectoring Mode (drive y -> 0)
    wire rot_dir = (fn3_latched == FN3_SIN || fn3_latched == FN3_COS || fn3_latched == FN3_TAN || fn3_latched == FN3_EXP) ? (z >= 0) : (y < 0);

    // Scaling hardware multiplier for square root: x * (1/K_{-1})
    wire signed [63:0] sqrt_mult = x * INV_KN1; // Multiplies Q16.16 by Q16.16 into Q32.32

    // Tangent calculation: Q16.16 division of sin by cos -> (sin <<< 16) / cos
    wire signed [31:0] final_y = negate_trig ? -y : y; // Corrected Sine
    wire signed [31:0] final_x = negate_trig ? -x : x; // Corrected Cosine
    wire signed [63:0] tan_numerator = {{16{final_y[31]}}, final_y, 16'd0}; // Align to Q16.16 quotient
    wire signed [31:0] tan_result    = (final_x != 0) ? (tan_numerator / final_x) : 32'sh7FFFFFFF; // Divide sin/cos

    // Main synchronous control and datapath process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset clears all control and datapath registers
            state       <= IDLE;
            cordic_busy <= 1'b0;
            cordic_done <= 1'b0;
            cordic_out  <= 32'sd0;
            iter        <= 5'd0;
            fn3_latched <= 3'd0;
            negate_trig <= 1'b0;
            x           <= 32'sd0;
            y           <= 32'sd0;
            z           <= 32'sd0;
        end else begin
            case (state)
                IDLE: begin
                    cordic_done <= 1'b0; // Ensure done flag is deasserted in IDLE
                    // Start execution only if block enable and start pulse are both asserted
                    if (en && cordic_start) begin
                        cordic_busy <= 1'b1;        // Assert busy back to CU (causes PC stall)
                        fn3_latched <= funct3;      // Latch funct3 instruction code
                        iter        <= 5'd0;        // Reset iteration count to 0
                        state       <= CALC;        // Begin iterative calculations

                        case (funct3)
                            FN3_SIN, FN3_COS, FN3_TAN: begin
                                // Range reduction: map angle to [-pi/2, +pi/2]
                                if (operand > PI_HALF) begin
                                    z           <= operand - PI_CONST; // Angle in Q2 -> fold by subtracting pi
                                    negate_trig <= 1'b1;               // Negate outputs in quadrant 2
                                end else if (operand < -PI_HALF) begin
                                    z           <= operand + PI_CONST; // Angle in Q3 -> fold by adding pi
                                    negate_trig <= 1'b1;               // Negate outputs in quadrant 3
                                end else begin
                                    z           <= operand;            // Angle already in [-pi/2, +pi/2]
                                    negate_trig <= 1'b0;               // No sign correction needed
                                end
                                x <= INV_K1;    // Seed x with 1/K1 to pre-compensate circular gain
                                y <= 32'sd0;    // Seed y with 0.0
                            end

                            FN3_EXP: begin
                                negate_trig <= 1'b0;
                                x           <= INV_KN1;  // Seed x with 1/K_{-1} hyperbolic gain reciprocal
                                y           <= 32'sd0;  // Seed y with 0.0
                                z           <= operand;  // Seed z with target power 'a'
                            end

                            FN3_LN: begin
                                negate_trig <= 1'b0;
                                x           <= operand + CONST_ONE; // Seed x_0 = x + 1.0
                                y           <= operand - CONST_ONE; // Seed y_0 = x - 1.0
                                z           <= 32'sd0;             // Accumulator starts at 0.0
                            end

                            FN3_SQRT: begin
                                negate_trig <= 1'b0;
                                x           <= operand + CONST_QTR; // Seed x_0 = x + 0.25
                                y           <= operand - CONST_QTR; // Seed y_0 = x - 0.25
                                z           <= 32'sd0;             // Seed z_0 = 0.0
                            end

                            default: begin
                                state       <= IDLE; // Unknown funct3 returns to IDLE
                                cordic_busy <= 1'b0;
                            end
                        endcase
                    end
                end

                CALC: begin
                    // Perform rotation iteration based on coordinate geometry
                    if (fn3_latched == FN3_SIN || fn3_latched == FN3_COS || fn3_latched == FN3_TAN) begin
                        // Circular coordinates (m = +1)
                        if (rot_dir) begin
                            x <= x - y_shr;
                            y <= y + x_shr;
                            z <= z - angle_lut;
                        end else begin
                            x <= x + y_shr;
                            y <= y - x_shr;
                            z <= z + angle_lut;
                        end
                    end else begin
                        // Hyperbolic coordinates (m = -1)
                        if (rot_dir) begin
                            x <= x + y_shr;
                            y <= y + x_shr;
                            z <= z - angle_lut;
                        end else begin
                            x <= x - y_shr;
                            y <= y - x_shr;
                            z <= z + angle_lut;
                        end
                    end

                    // Check if 16 rotation steps are complete
                    if (iter == 5'd15) begin
                        state <= POST; // Transition to writeback state
                    end else begin
                        iter  <= iter + 5'd1; // Next iteration
                    end
                end

                POST: begin
                    cordic_busy <= 1'b0; // Deassert busy; CU drops CPU stall line
                    cordic_done <= 1'b1; // Pulse done flag to signal writeback readiness
                    state       <= IDLE; // Return to IDLE to await next command

                    // Select output based on latched funct3
                    case (fn3_latched)
                        FN3_SIN:  cordic_out <= final_y;             // Output sin(theta)
                        FN3_COS:  cordic_out <= final_x;             // Output cos(theta)
                        FN3_TAN:  cordic_out <= tan_result;          // Output tan(theta) = sin / cos
                        FN3_EXP:  cordic_out <= x + y;               // Output e^x = cosh(x) + sinh(x)
                        FN3_LN:   cordic_out <= z <<< 1;             // Output ln(x) = 2 * z
                        FN3_SQRT: cordic_out <= sqrt_mult[47:16];    // Output sqrt(x) = x * (1/K_{-1})
                        default:  cordic_out <= 32'sd0;
                    endcase
                end
            endcase
        end
    end
endmodule