`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.10.2026 11:56:13
// Design Name: 
// Module Name: CU
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


module CU(//control unit
        input reset,
        input clk,
        input [6:0] funct7,
        input [2:0] funct3,
        input [6:0] opcode,
        input cordic_busy,// status coming back from the cordic unit
        input cordic_done,// one cycle pulse from the cordic unit when result is ready
        input fpu_busy,// status coming back from the fpu
        input fpu_done,// one cycle pulse from the fpu when result is ready
        output reg [5:0] alu_control,
        output reg lb, //load bit
        output reg mem_to_reg, //enabling data flow from memeory to register
        output reg bneq_control,// branch if not equal
        output reg beq_control,//branch is equal
        output reg bgeq_control,// branch id=f greater than or equal
        output reg blt_control,//branch if less than
        output reg jump,// jump to a address
        output reg sw,//store word(32 bit value)
        output reg lui_control,//load upper immediate 
        output reg cordic_start,// start pulse to the cordic unit
        output reg fpu_start,// start pulse to the fpu
        output reg stall// hold the PC while cordic or fpu is working
    );
    always@(*)
    begin
        // defaults: every output gets a value on every path (no latches, no x)
        alu_control  = 0;
        lb           = 0;
        sw           = 0;
        mem_to_reg   = 0;
        beq_control  = 0;
        bneq_control = 0;
        bgeq_control = 0;
        blt_control  = 0;
        jump         = 0;
        lui_control  = 0;
        cordic_start = 0;
        fpu_start    = 0;
        stall        = 0;
        if(!reset)
        begin
            if(opcode == 7'b0110011)//R type instruction
            begin
            case(funct3)
                3'b000:
                    begin
                        if(funct7 == 0) alu_control = 6'b000001;//addition
                        else if(funct7 == 32) alu_control = 6'b000010; //subtrction
                    end
                3'b001:
                    begin
                        if(funct7 == 0) alu_control = 6'b000011;//shift left logical
                    end
                3'b010:
                    begin
                        if(funct7 == 0) alu_control = 6'b000100;//set less than
                    end
                3'b011:
                    begin
                        if(funct7 == 0) alu_control = 6'b000101;//set less than unsigned
                    end
                3'b100:
                    begin
                        if(funct7 == 0) alu_control = 6'b000110;//XOR operation
                    end
                3'b101:
                    begin
                    if(funct7 == 0) alu_control = 6'b000111;
                    else
                        if(funct7 == 32) alu_control = 6'b001000;//shift right arithmetic
                    end
                3'b110:
                    begin
                    if(funct7 == 0) alu_control = 6'b001001;//or operation
                    end
                3'b111:
                    begin
                        if(funct7 == 0) alu_control = 6'b001010;//and operation
                    end
            endcase
            end
            /////////////////////////////////////////// I - TYPE INSTRUCTION  ///////////////////////////////////////////////////////////////////////////////////////
                  
                  else if(opcode == 7'b001_0011)// I TYPE
                  begin
                        
                       case(funct3)
                       
///////////////////////////////////////////////// ADD IMMEDIATE  ///////////////////////////////////////////////////////////////////////////////////////

                                3'b000 :
                                        begin
                                            alu_control = 6'b001011; // add immediate
                                        end

///////////////////////////////////////////////// SHIFT LEFT LOGICAL IMMEDIATE  ///////////////////////////////////////////////////////////////////////////////////////

                                3'b001 :
                                        begin
                                            alu_control = 6'b001100; // shift left logical immediate
                                        end
                                        
///////////////////////////////////////////////// SET LESS THAN IMMEDIATE  ///////////////////////////////////////////////////////////////////////////////////////
                                        
                                3'b010  :
                                        begin
                                            alu_control = 6'b001101; // SET LESS THAN IMMEDIATE
                                         end
                                         
                                 3'b011 :
                                        begin
                                            alu_control = 6'b001110; // set less than immediate unsigned
                                         end
                                 3'b100 :
                                        begin
                                            alu_control = 6'b001111; //xor immediate
                                        end
                                        
                                  3'b101 :
                                        begin
                                            if(funct7 == 32) alu_control = 6'b100011; //shift right arithmetic imm
                                            else alu_control = 6'b010000; //shift right logic imm
                                         end
                                         
                                   3'b110 :
                                        begin
                                            alu_control = 6'b010001; // OR IMMEDIATE
                                        end
                                   
                                   3'b111 :
                                        begin
                                            alu_control = 6'b010010; // AND IMMEDIATE
                                        end
                               endcase
                            end
                        
                        else if(opcode == 7'b000_0011) // I type (load instructions)
                        begin
                        
                            case(funct3)
                                3'b000 :
                                        begin
                                            mem_to_reg = 1;           
                                            lb = 1;               
                                            alu_control = 6'b010011; // load byte
                                         end
                                3'b001 :
                                    begin
                                        alu_control = 6'b010100; // load_half
                                        mem_to_reg = 1;        
                                     end
                                     
                                3'b010 :begin
                                        
                                        alu_control = 6'b010101; //load_word
                                        mem_to_reg = 1;        
                                        end
                                        
                                3'b100 :begin

                                        mem_to_reg = 1;        
                                        alu_control = 6'b010110;//load_byte unsigned
                                        end
                                                                                
                                3'b101 :begin
                                        mem_to_reg = 1;        
                                        alu_control = 6'b010111; // load_half unsigned
                                        
                                        end


                                    endcase
                                    end
                                    
                          else if(opcode == 7'b010_0011)
                            begin
                            case(funct3)
                                3'b000 :begin
                                        sw = 1;
                                        alu_control = 6'b011000; // store byte
                                        end
                                        
                                3'b001 :begin
                                        sw = 1;
                                        alu_control = 6'b011001; // store half word
                                        end
                                        
                                3'b010 :begin
                                        sw = 1;
                                        alu_control = 6'b011010; // store word
                                        end
                           endcase
                       end
                       
                       else if(opcode == 7'b110_0011)
                       begin
                            case(funct3)
                            //BRANCH EQUAL INSTRUCTION
                                3'b000 :
                                    begin
                                    alu_control = 6'b011011; 
                                    beq_control = 1;
                                    end
                                    
                               //BRANCH UNEQUAL     
                                3'b001 :
                                    begin
                                    alu_control = 6'b011100; //branch unequal
                                    bneq_control = 1;
                                    end
                                    
                                 3'b100 :
                                    begin
                                    alu_control = 6'b011101; //BRANCH LESS THAN INSTRUCTION
                                    blt_control = 1;
                                    end
                                    
                                  3'b101 :
                                   begin
                                    alu_control = 6'b011111; // BRANCH IF GREATER THAN OR EQUAL TO 
                                    bgeq_control = 1;
                                    end
                                    
                                 3'b110 :
                                    begin
                                    alu_control = 6'b011110; // branch less than unsigned
                                    blt_control = 1;
                                    end
                                    
                                 3'b111 :
                                    begin
                                    alu_control = 6'b100000; // branch greater than or equal to  unsigned 
                                    bgeq_control = 1;
                                    end
                                    
                                endcase
                       end
                       
                       //LUI INSTRUCTION
                       
                       else if(opcode == 7'b011_0111)
                            begin
                               alu_control = 6'b100001;
                               lui_control = 1;
                            end
                       
                      //JUMP AND LINK OPERATION
                      
                       else if(opcode == 7'b110_1111)
                            begin
                                alu_control = 6'b100010;
                                jump = 1;
                             end
                             
                      //CORDIC INSTRUCTION (I type format, immediate = input address)
                      
                       else if(opcode == 7'b111_1111)
                            begin
                                case(funct3)
                                    3'b000 : alu_control = 6'b100100; // sin
                                    3'b001 : alu_control = 6'b100101; // cos
                                    3'b010 : alu_control = 6'b100110; // exp
                                    3'b011 : alu_control = 6'b100111; // log
                                endcase
                                if(funct3 <= 3'b011)
                                begin
                                    stall = ~cordic_done;// hold the PC until the result is ready
                                    cordic_start = ~cordic_busy & ~cordic_done;// start only when idle
                                end
                             end
                             
                      //FPU INSTRUCTION (R type format, the fpu decodes funct3/funct7 itself)
                      
                       else if(opcode == 7'b111_1110)
                            begin
                                alu_control = 6'b101000;
                                stall = ~fpu_done;// hold the PC until the result is ready
                                fpu_start = ~fpu_busy & ~fpu_done;// start only when idle
                             end
                             
               end 
    end
endmodule