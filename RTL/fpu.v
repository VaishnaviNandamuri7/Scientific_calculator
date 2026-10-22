`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2026 22:56:11
// Design Name: 
// Module Name: fpu
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


module FPU (
    input clk,
    input reset,
    input start,
    input [6:0] funct7,
    input [2:0] funct3,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg busy,
    output reg done
);

    reg [2:0] count;
    reg [6:0] saved_funct7;
    reg [2:0] saved_funct3;
    reg [31:0] operand_a;
    reg [31:0] operand_b;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 32'b0;
            busy <= 1'b0;
            done <= 1'b0;
            count <= 0;
            saved_funct7 <= 0;
            saved_funct3 <= 0;
            operand_a <= 0;
            operand_b <= 0;
        end
        else begin
            done <= 1'b0;

            if (start && !busy) begin
                if (funct3 == 3'b000 &&
                    (funct7 == 7'b0000000 ||
                     funct7 == 7'b0000100 ||
                     funct7 == 7'b0001000 ||
                     funct7 == 7'b0001100 ||
                     funct7 == 7'b0010000 ||
                     funct7 == 7'b0010100 ||
                     funct7 == 7'b0011000)) begin

                    operand_a <= a;
                    operand_b <= b;
                    saved_funct7 <= funct7;
                    saved_funct3 <= funct3;
                    count <= 0;
                    busy <= 1'b1;
                end
                else begin//invalid op, finish at once so the cpu never hangs
                    result <= 32'h7FC00000;//quiet NaN
                    done <= 1'b1;
                end
            end
            else if (busy) begin
                if (count < 2)
                    count <= count + 1'b1;
                else begin
                    case (saved_funct7)
                        7'b0000000:
                            result <= fp_add(operand_a, operand_b);

                        7'b0000100:
                            result <= fp_add(
                                operand_a,
                                {~operand_b[31], operand_b[30:0]}
                            );

                        7'b0001000:
                            result <= fp_mul(operand_a, operand_b);

                        7'b0001100:
                            result <= fp_div(operand_a, operand_b);

                        7'b0010000:
                            result <= {31'b0, fp_equal(operand_a, operand_b)};

                        7'b0010100:
                            result <= {31'b0, fp_less(operand_a, operand_b)};

                        7'b0011000:
                            result <= {
                                31'b0,
                                (fp_less(operand_a, operand_b) |
                                 fp_equal(operand_a, operand_b))
                            };

                        default:
                            result <= 32'b0;
                    endcase

                    busy <= 1'b0;
                    done <= 1'b1;
                    count <= 0;
                end
            end
        end
    end

    function [31:0] fp_add;
        input [31:0] x;
        input [31:0] y;

        reg sx, sy, sr;
        reg [7:0] ex, ey, er;
        reg [23:0] mx, my, mant;
        reg [24:0] sum;
        integer diff;
        integer i;

        begin
            sx = x[31];
            sy = y[31];
            ex = x[30:23];
            ey = y[30:23];

            mx = (ex == 0) ? {1'b0, x[22:0]} : {1'b1, x[22:0]};
            my = (ey == 0) ? {1'b0, y[22:0]} : {1'b1, y[22:0]};

            if (ex == 0 && x[22:0] == 0)
                fp_add = y;
            else if (ey == 0 && y[22:0] == 0)
                fp_add = x;
            else begin
                if (ex >= ey) begin
                    diff = ex - ey;
                    my = (diff > 24) ? 24'b0 : my >> diff;
                    er = ex;
                end
                else begin
                    diff = ey - ex;
                    mx = (diff > 24) ? 24'b0 : mx >> diff;
                    er = ey;
                end

                if (sx == sy) begin
                    sum = {1'b0, mx} + {1'b0, my};
                    sr = sx;

                    if (sum[24]) begin
                        mant = sum[24:1];
                        er = er + 1'b1;
                    end
                    else
                        mant = sum[23:0];
                end
                else begin
                    if (mx >= my) begin
                        mant = mx - my;
                        sr = sx;
                    end
                    else begin
                        mant = my - mx;
                        sr = sy;
                    end

                    if (mant == 0) begin
                        fp_add = 32'b0;
                        er = 0;
                    end
                    else begin
                        // fixed-count loop (hardware needs a fixed bound): shift left
                        // until the top bit is 1 or the exponent reaches 1
                        for (i = 0; i < 24; i = i + 1) begin
                            if (!mant[23] && er > 1) begin
                                mant = mant << 1;
                                er = er - 1'b1;
                            end
                        end
                    end
                end

                if (mant == 0)
                    fp_add = 32'b0;
                else if (er >= 255)
                    fp_add = {sr, 8'hFF, 23'b0};
                else
                    fp_add = {sr, er, mant[22:0]};
            end
        end
    endfunction

    function [31:0] fp_mul;
        input [31:0] x;
        input [31:0] y;

        reg sign_result;
        reg [7:0] ex, ey;
        integer exp_result;
        reg [23:0] mx, my;
        reg [47:0] product;
        reg [47:0] normalized_product;

        begin
            sign_result = x[31] ^ y[31];
            ex = x[30:23];
            ey = y[30:23];

            mx = (ex == 0) ? {1'b0, x[22:0]} : {1'b1, x[22:0]};
            my = (ey == 0) ? {1'b0, y[22:0]} : {1'b1, y[22:0]};

            if ((ex == 0 && x[22:0] == 0) ||
                (ey == 0 && y[22:0] == 0))
                fp_mul = 32'b0;
            else begin
                product = mx * my;
                exp_result = ex + ey - 127;

                if (product[47]) begin
                    normalized_product = product >> 1;
                    exp_result = exp_result + 1;
                end
                else
                    normalized_product = product;

                if (exp_result >= 255)
                    fp_mul = {sign_result, 8'hFF, 23'b0};
                else if (exp_result <= 0)
                    fp_mul = 32'b0;
                else
                    fp_mul = {
                        sign_result,
                        exp_result[7:0],
                        normalized_product[45:23]
                    };
            end
        end
    endfunction

    function [31:0] fp_div;
        input [31:0] x;
        input [31:0] y;

        reg sign_result;
        reg [7:0] ex, ey;
        integer exp_result;
        reg [23:0] mx, my;
        reg [50:0] numerator;
        reg [50:0] quotient;

        begin
            sign_result = x[31] ^ y[31];
            ex = x[30:23];
            ey = y[30:23];

            mx = (ex == 0) ? {1'b0, x[22:0]} : {1'b1, x[22:0]};
            my = (ey == 0) ? {1'b0, y[22:0]} : {1'b1, y[22:0]};

            if (y[30:0] == 0)
                fp_div = {sign_result, 8'hFF, 23'b0};
            else if (x[30:0] == 0)
                fp_div = 32'b0;
            else begin
                numerator = {27'b0, mx} << 26;
                quotient = numerator / my;
                exp_result = ex - ey + 127;

                if (!quotient[26]) begin//mx < my, normalize up
                    quotient = quotient << 1;
                    exp_result = exp_result - 1;
                end

                if (exp_result >= 255)
                    fp_div = {sign_result, 8'hFF, 23'b0};
                else if (exp_result <= 0)
                    fp_div = 32'b0;
                else
                    fp_div = {
                        sign_result,
                        exp_result[7:0],
                        quotient[25:3]
                    };
            end
        end
    endfunction

    function fp_equal;
        input [31:0] x;
        input [31:0] y;
        begin
            if (x[30:0] == 0 && y[30:0] == 0)
                fp_equal = 1'b1;
            else
                fp_equal = (x == y);
        end
    endfunction

    function fp_less;
        input [31:0] x;
        input [31:0] y;
        begin
            if (x[30:0] == 0 && y[30:0] == 0)
                fp_less = 1'b0;
            else if (x[31] != y[31])
                fp_less = x[31];
            else if (x[31] == 0)
                fp_less = (x[30:0] < y[30:0]);
            else
                fp_less = (x[30:0] > y[30:0]);
        end
    endfunction

endmodule