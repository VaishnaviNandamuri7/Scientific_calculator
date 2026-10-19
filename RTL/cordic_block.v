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
    localparam signed [63:0] PI_Q32      = 64'sh3243F6A89; // pi    in Q32 (range reduction)
    localparam signed [63:0] LN2_Q32     = 64'shB17217F8;  // ln(2) in Q32 (range reduction)
    localparam signed [31:0] INV_PI_Q30  = 32'sh145F306E;  // 1/pi    in Q30
    localparam signed [31:0] INV_LN2_Q30 = 32'sh5C551D95;  // 1/ln(2) in Q30

    // Datapath FSM state encodings
    localparam IDLE = 3'd0; // waiting for enable and start
    localparam PRE1 = 3'd1; // pick k (trig/exp) or exponent (ln/sqrt)
    localparam PRE2 = 3'd2; // reduced operand and seeds
    localparam CALC = 3'd3; // 16 rotation steps
    localparam POST = 3'd4; // scaling and output write
    reg [2:0] state;

    // Internal pipeline registers
    reg [4:0]  iter;         // Iteration counter (0 to 15)
    reg [2:0]  fn3_latched;  // Latched funct3 instruction code
    reg        negate_trig;  // Set when k is odd (trig sign flip)
    reg signed [31:0] opr;   // Latched operand
    reg signed [17:0] k_reg; // k for trig/exp, exponent for ln/sqrt
    reg               force_en;  // Output overridden (overflow, ln/sqrt of x<=0)
    reg signed [31:0] force_val; // Value used when force_en is set
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

    // Range reduction
    wire is_trig = (fn3_latched <= FN3_TAN);
    wire signed [31:0] inv_const = (fn3_latched == FN3_EXP) ? INV_LN2_Q30 : INV_PI_Q30;
    wire signed [63:0] k_prod = opr * inv_const;                     // Q16 * Q30 = Q46
    wire signed [63:0] k_est  = (k_prod + (64'sd1 <<< 45)) >>> 46;   // round(opr / pi) or round(opr / ln2)
    wire signed [63:0] konst  = is_trig ? PI_Q32 : LN2_Q32;
    wire signed [63:0] k_mul  = k_reg * konst;                       // k*pi, or k*ln2 (e*ln2 for ln), Q32
    wire signed [63:0] opr_q32 = {{16{opr[31]}}, opr, 16'b0};
    wire signed [63:0] r_q32  = opr_q32 - k_mul;
    wire signed [31:0] r_q16  = (r_q32 + 64'sd32768) >>> 16;         // reduced argument, Q16.16

    // Leading one of opr gives the power of two for ln and sqrt
    reg [4:0] pe;
    integer i;
    always @(*) begin
        pe = 5'd0;
        for (i = 0; i < 31; i = i + 1)
            if (opr[i]) pe = i;
    end
    wire signed [5:0] q_exp = $signed({1'b0, pe}) - 6'sd16;          // opr = m * 2^q_exp, m in [1,2)
    wire signed [5:0] s_exp = q_exp[0] ? (q_exp + 6'sd1) : q_exp;    // even exponent for sqrt, m in [0.5,2)
    wire [4:0] shl = 5'd0 - k_reg[4:0];                              // -k for k < 0
    wire signed [31:0] mant = (k_reg >= 0) ? (opr >>> k_reg[4:0]) : (opr <<< shl);

    // Tangent calculation: Q16.16 division of sin by cos -> (sin <<< 16) / cos
    wire signed [31:0] final_y = negate_trig ? -y : y; // Corrected Sine
    wire signed [31:0] final_x = negate_trig ? -x : x; // Corrected Cosine
    wire signed [63:0] tan_numerator = {{16{final_y[31]}}, final_y, 16'd0}; // Align to Q16.16 quotient
    wire signed [63:0] tan_q = tan_numerator / final_x;
    wire signed [31:0] tan_result = (final_x == 0)             ? 32'sh7FFFFFFF :
                                    (tan_q >  64'sh7FFFFFFF)   ? 32'sh7FFFFFFF :
                                    (tan_q < -64'sh80000000)   ? 32'sh80000000 : tan_q[31:0];

    // Output scaling
    wire signed [31:0] exp_val  = x + y;                             // e^r
    wire signed [63:0] exp_ext  = exp_val;
    wire signed [63:0] exp_wide = (k_reg >= 0) ? (exp_ext <<< k_reg[4:0]) : (exp_ext >>> shl);
    wire signed [31:0] exp_out  = (exp_wide > 64'sh7FFFFFFF) ? 32'sh7FFFFFFF : exp_wide[31:0];
    wire signed [31:0] ln_off   = (k_mul + 64'sd32768) >>> 16;       // e * ln2
    wire signed [17:0] e2       = k_reg >>> 1;                       // sqrt exponent = s/2
    wire signed [31:0] sqrt_val = sqrt_mult[47:16];
    wire signed [31:0] sqrt_out = (e2 >= 0) ? (sqrt_val <<< e2[4:0]) : (sqrt_val >>> (5'd0 - e2[4:0]));

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
            opr         <= 32'sd0;
            k_reg       <= 18'sd0;
            force_en    <= 1'b0;
            force_val   <= 32'sd0;
            x           <= 32'sd0;
            y           <= 32'sd0;
            z           <= 32'sd0;
        end else begin
            case (state)
                IDLE: begin
                    cordic_done <= 1'b0; // Ensure done flag is deasserted in IDLE
                    // Start only if enabled, start pulse asserted and funct3 is valid
                    if (en && cordic_start && funct3 <= FN3_SQRT) begin
                        cordic_busy <= 1'b1;   // Assert busy back to CU (causes PC stall)
                        fn3_latched <= funct3; // Latch funct3 instruction code
                        opr         <= operand;
                        iter        <= 5'd0;
                        force_en    <= 1'b0;
                        state       <= PRE1;
                    end
                end

                PRE1: begin
                    case (fn3_latched)
                        FN3_LN:   k_reg <= q_exp;
                        FN3_SQRT: k_reg <= s_exp;
                        default:  k_reg <= k_est[17:0]; // trig and exp
                    endcase
                    state <= PRE2;
                end

                PRE2: begin
                    state <= CALC;
                    case (fn3_latched)
                        FN3_SIN, FN3_COS, FN3_TAN: begin
                            z           <= r_q16;    // angle in [-pi/2, +pi/2]
                            negate_trig <= k_reg[0]; // odd k flips sin and cos
                            x           <= INV_K1;   // Seed x with 1/K1 to pre-compensate circular gain
                            y           <= 32'sd0;
                        end

                        FN3_EXP: begin
                            negate_trig <= 1'b0;
                            z           <= r_q16;    // |r| <= ln2/2
                            x           <= INV_KN1;  // Seed x with 1/K_{-1} hyperbolic gain reciprocal
                            y           <= 32'sd0;
                            if (k_reg > 18'sd15) begin           // result >= 32768, saturate
                                force_en <= 1'b1; force_val <= 32'sh7FFFFFFF;
                            end else if (k_reg < -18'sd16) begin // result < 2^-16, underflow
                                force_en <= 1'b1; force_val <= 32'sd0;
                            end
                        end

                        FN3_LN: begin
                            negate_trig <= 1'b0;
                            x           <= mant + CONST_ONE; // Seed x_0 = m + 1.0
                            y           <= mant - CONST_ONE; // Seed y_0 = m - 1.0
                            z           <= 32'sd0;
                            if (opr <= 0) begin                  // ln(x<=0) -> most negative value
                                force_en <= 1'b1; force_val <= 32'sh80000000;
                            end
                        end

                        FN3_SQRT: begin
                            negate_trig <= 1'b0;
                            x           <= mant + CONST_QTR; // Seed x_0 = m + 0.25
                            y           <= mant - CONST_QTR; // Seed y_0 = m - 0.25
                            z           <= 32'sd0;
                            if (opr <= 0) begin                  // sqrt(x<=0) -> 0
                                force_en <= 1'b1; force_val <= 32'sd0;
                            end
                        end
                    endcase
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

                    if (force_en)
                        cordic_out <= force_val;
                    else
                        case (fn3_latched)
                            FN3_SIN:  cordic_out <= final_y;             // Output sin(theta)
                            FN3_COS:  cordic_out <= final_x;             // Output cos(theta)
                            FN3_TAN:  cordic_out <= tan_result;          // Output tan(theta) = sin / cos
                            FN3_EXP:  cordic_out <= exp_out;             // Output e^r * 2^k
                            FN3_LN:   cordic_out <= (z <<< 1) + ln_off;  // Output ln(m) + e*ln2
                            FN3_SQRT: cordic_out <= sqrt_out;            // Output sqrt(m) * 2^(s/2)
                            default:  cordic_out <= 32'sd0;
                        endcase
                end
            endcase
        end
    end
endmodule