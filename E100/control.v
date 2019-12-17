/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module control(
    input wire clock,
    input wire clock_valid,
    input wire reset,
    input wire [31:0] opcode_out,
    input wire equal_out,
    input wire lt_out,

    output reg iar_write,               // write the IAR
    output reg iar_drive,               // drive IAR onto bus
    output reg plus1_drive,             // drive result of plus1 onto bus
    output reg op1_write,               // write op1
    output reg op2_write,               // write op2
    output reg add_drive,               // drive result of add onto bus
    output reg sub_drive,               // drive result of sub onto bus
    output reg mult_drive,              // drive result of mult onto bus
    output reg div_drive,               // drive result of div onto bus
    output reg bit_and_drive,           // drive result of bit_and onto bus
    output reg bit_or_drive,            // drive result of bit_or onto bus
    output reg bit_not_drive,           // drive result of bit_not onto bus
    output reg sl_drive,                // drive result of sl onto bus
    output reg sr_drive,                // drive result of sr onto bus
    output reg opcode_write,            // write opcode
    output reg arg1_write,              // write arg1
    output reg arg1_drive,              // drive arg1 onto bus
    output reg arg2_write,              // write arg2
    output reg arg2_drive,              // drive arg2 onto bus
    output reg arg3_write,              // write arg2
    output reg arg3_drive,              // drive arg2 onto bus
    output reg address_write,           // write memory's address register
    output reg memory_write,            // write memory with data from bus
    output reg memory_drive);           // read memory; drive onto bus

    parameter state_reset =  8'h0;
    parameter state_fetch1 = 8'h1;
    parameter state_fetch2 = 8'h2;
    parameter state_fetch3 = 8'h3;
    parameter state_fetch4 = 8'h4;
    parameter state_fetch5 = 8'h5;
    parameter state_fetch6 = 8'h6;
    parameter state_fetch7 = 8'h7;
    parameter state_fetch8 = 8'h8;
    parameter state_decode = 8'h9;
    parameter state_halt =   8'ha;
    parameter state_add1 =   8'hb;
    parameter state_add2 =   8'hc;
    parameter state_add3 =   8'hd;
    parameter state_add4 =   8'he;
    parameter state_add5 =   8'hf;
    parameter state_add6 =   8'h10;
    parameter state_sub1 =   8'h11;
    parameter state_sub2 =   8'h12;
    parameter state_sub3 =   8'h13;
    parameter state_sub4 =   8'h14;
    parameter state_sub5 =   8'h15;
    parameter state_sub6 =   8'h16;
    parameter state_mult1 =  8'h17;
    parameter state_mult2 =  8'h18;
    parameter state_mult3 =  8'h19;
    parameter state_mult4 =  8'h1a;
    parameter state_mult5 =  8'h1b;
    parameter state_mult6 =  8'h1c;
    parameter state_mult7 =  8'h1d;
    parameter state_div1 =   8'h1e;
    parameter state_div2 =   8'h1f;
    parameter state_div3 =   8'h20;
    parameter state_div4 =   8'h21;
    parameter state_div5 =   8'h22;
    parameter state_div6 =   8'h23;
    parameter state_div7 =   8'h24;
    parameter state_div8 =   8'h25;
    parameter state_div9 =   8'h26;
    parameter state_div10 =  8'h27;
    parameter state_div11 =  8'h28;
    parameter state_div12 =  8'h29;
    parameter state_div13 =  8'h2a;
    parameter state_div14 =  8'h2b;
    parameter state_div15 =  8'h2c;
    parameter state_div16 =  8'h2d;
    parameter state_div17 =  8'h2e;
    parameter state_div18 =  8'h2f;
    parameter state_cp1 =    8'h30;
    parameter state_cp2 =    8'h31;
    parameter state_cp3 =    8'h32;
    parameter state_cp4 =    8'h33;
    parameter state_and1 =   8'h34;
    parameter state_and2 =   8'h35;
    parameter state_and3 =   8'h36;
    parameter state_and4 =   8'h37;
    parameter state_and5 =   8'h38;
    parameter state_and6 =   8'h39;
    parameter state_or1 =    8'h3a;
    parameter state_or2 =    8'h3b;
    parameter state_or3 =    8'h3c;
    parameter state_or4 =    8'h3d;
    parameter state_or5 =    8'h3e;
    parameter state_or6 =    8'h3f;
    parameter state_not1 =   8'h40;
    parameter state_not2 =   8'h41;
    parameter state_not3 =   8'h42;
    parameter state_not4 =   8'h43;
    parameter state_sl1 =    8'h44;
    parameter state_sl2 =    8'h45;
    parameter state_sl3 =    8'h46;
    parameter state_sl4 =    8'h47;
    parameter state_sl5 =    8'h48;
    parameter state_sl6 =    8'h49;
    parameter state_sr1 =    8'h4a;
    parameter state_sr2 =    8'h4b;
    parameter state_sr3 =    8'h4c;
    parameter state_sr4 =    8'h4d;
    parameter state_sr5 =    8'h4e;
    parameter state_sr6 =    8'h4f;
    parameter state_be1 =    8'h50;
    parameter state_be2 =    8'h51;
    parameter state_be3 =    8'h52;
    parameter state_be4 =    8'h53;
    parameter state_be5 =    8'h54;
    parameter state_be6 =    8'h55;
    parameter state_bne1 =   8'h56;
    parameter state_bne2 =   8'h57;
    parameter state_bne3 =   8'h58;
    parameter state_bne4 =   8'h59;
    parameter state_bne5 =   8'h5a;
    parameter state_bne6 =   8'h5b;
    parameter state_blt1 =   8'h5c;
    parameter state_blt2 =   8'h5d;
    parameter state_blt3 =   8'h5e;
    parameter state_blt4 =   8'h5f;
    parameter state_blt5 =   8'h60;
    parameter state_blt6 =   8'h61;
    parameter state_cpfa1 =  8'h62;
    parameter state_cpfa2 =  8'h63;
    parameter state_cpfa3 =  8'h64;
    parameter state_cpfa4 =  8'h65;
    parameter state_cpfa5 =  8'h66;
    parameter state_cpfa6 =  8'h67;
    parameter state_cpfa7 =  8'h68;
    parameter state_cpta1 =   8'h69;
    parameter state_cpta2 =   8'h6a;
    parameter state_cpta3 =   8'h6b;
    parameter state_cpta4 =   8'h6c;
    parameter state_cpta5 =   8'h6d;
    parameter state_cpta6 =   8'h6e;
    parameter state_cpta7 =   8'h6f;
    parameter state_cpta8 =   8'h70;
    parameter state_call1 =  8'h71;
    parameter state_call2 =  8'h72;
    parameter state_call3 =  8'h73;
    parameter state_call4 =  8'h74;
    parameter state_ret1 =   8'h75;
    parameter state_ret2 =   8'h76;

    parameter E100_HALT =    32'h0000;
    parameter E100_ADD =     32'h0001;
    parameter E100_SUB =     32'h0002;
    parameter E100_MULT =    32'h0003;
    parameter E100_DIV =     32'h0004;
    parameter E100_CP =      32'h0005;
    parameter E100_AND =     32'h0006;
    parameter E100_OR =      32'h0007;
    parameter E100_NOT =     32'h0008;
    parameter E100_SL =      32'h0009;
    parameter E100_SR =      32'h000a;
    parameter E100_CPFA =    32'h000b;
    parameter E100_CPTA =    32'h000c;
    parameter E100_BE =      32'h000d;
    parameter E100_BNE =     32'h000e;
    parameter E100_BLT =     32'h000f;
    parameter E100_CALL =    32'h0010;
    parameter E100_RET =     32'h0011;

    reg [7:0] state;
    reg [7:0] next_state;

    always @* begin
        // default values for control signals
        iar_write = 1'b0;
        iar_drive = 1'b0;
        op1_write = 1'b0;
        op2_write = 1'b0;
        add_drive = 1'b0;
        sub_drive = 1'b0;
        bit_and_drive = 1'b0;
        bit_or_drive = 1'b0;
        bit_not_drive = 1'b0;
        sl_drive = 1'b0;
        sr_drive = 1'b0;
        mult_drive = 1'b0;
        div_drive = 1'b0;
        plus1_drive = 1'b0;
        opcode_write = 1'b0;
        arg1_write = 1'b0;
        arg1_drive = 1'b0;
        arg2_write = 1'b0;
        arg2_drive = 1'b0;
        arg3_write = 1'b0;
        arg3_drive = 1'b0;
        address_write = 1'b0;
        memory_write = 1'b0;
        memory_drive = 1'b0;
        next_state = state_reset;

        case (state)
            state_reset: begin
                next_state = state_fetch1;
            end 

            // fetch the current instruction

            state_fetch1: begin
                // copy IAR to address
                iar_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_fetch2;
            end 

            state_fetch2: begin
                // read opcode from memory
                memory_drive = 1'b1;
                opcode_write = 1'b1;
                next_state = state_fetch3;
            end 

            state_fetch3: begin
                // increment IAR; copy new value to address
                plus1_drive = 1'b1;
                iar_write = 1'b1;
                address_write = 1'b1;
                next_state = state_fetch4;
            end 

            state_fetch4: begin
                // read arg1 from memory
                memory_drive = 1'b1;
                arg1_write = 1'b1;
                next_state = state_fetch5;
            end 

            state_fetch5: begin
                // increment IAR; copy new value to address
                plus1_drive = 1'b1;
                iar_write = 1'b1;
                address_write = 1'b1;
                next_state = state_fetch6;
            end 

            state_fetch6: begin
                // read arg2 from memory
                memory_drive = 1'b1;
                arg2_write = 1'b1;
                next_state = state_fetch7;
            end 

            state_fetch7: begin
                // increment IAR; copy new value to address
                plus1_drive = 1'b1;
                iar_write = 1'b1;
                address_write = 1'b1;
                next_state = state_fetch8;
            end 

            state_fetch8: begin
                // read arg3 from memory
                memory_drive = 1'b1;
                arg3_write = 1'b1;
                next_state = state_decode;
            end 

            // decode the current instruction

            state_decode: begin
                // transfer address of (probable) next instruction to IAR
                plus1_drive = 1'b1;
                iar_write = 1'b1;

                // choose next state, based on opcode
                if (opcode_out == E100_HALT) begin
                    next_state = state_halt;
                end else if (opcode_out == E100_ADD) begin
                    next_state = state_add1;
                end else if (opcode_out == E100_SUB) begin
                    next_state = state_sub1;
                end else if (opcode_out == E100_MULT) begin
                    next_state = state_mult1;
                end else if (opcode_out == E100_DIV) begin
                    next_state = state_div1;
                end else if (opcode_out == E100_CP) begin
                    next_state = state_cp1;
                end else if (opcode_out == E100_AND) begin
                    next_state = state_and1;
                end else if (opcode_out == E100_OR) begin
                    next_state = state_or1;
                end else if (opcode_out == E100_NOT) begin
                    next_state = state_not1;
                end else if (opcode_out == E100_SL) begin
                    next_state = state_sl1;
                end else if (opcode_out == E100_SR) begin
                    next_state = state_sr1;
                end else if (opcode_out == E100_BE) begin
                    next_state = state_be1;
                end else if (opcode_out == E100_BNE) begin
                    next_state = state_bne1;
                end else if (opcode_out == E100_BLT) begin
                    next_state = state_blt1;
                
                end else if (opcode_out == E100_CPFA) begin
		    next_state = state_cpfa1;
		end else if (opcode_out == E100_CPTA) begin
		    next_state = state_cpta1;
		end else if (opcode_out == E100_CALL) begin
                    next_state = state_call1;
		end else if (opcode_out == E100_RET) begin  // STUFF JOHN ADDED
			next_state = state_ret1;
		end

            end 

            // execute halt instruction

            state_halt: begin
                next_state = state_halt;
            end 

            // execute add instruction

            state_add1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_add2;
            end 

            state_add2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_add3;
            end 

            state_add3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_add4;
            end 

            state_add4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_add5;
            end 

            state_add5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_add6;
            end 

            state_add6: begin
                // write op1 + op2 to mem[arg1]
                add_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute sub instruction

            state_sub1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sub2;
            end 

            state_sub2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_sub3;
            end 

            state_sub3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sub4;
            end 

            state_sub4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_sub5;
            end 

            state_sub5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sub6;
            end 

            state_sub6: begin
                // write op1 - op2 to mem[arg1]
                sub_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute mult instruction

            state_mult1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_mult2;
            end 

            state_mult2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_mult3;
            end

            state_mult3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_mult4;
            end 

            state_mult4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_mult5;
            end 

            state_mult5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_mult6;
            end 

            // give time for mult to compute multiplication

            state_mult6: begin
                next_state = state_mult7;
            end 

            state_mult7: begin
                // write op1 * op2 to mem[arg1]
                mult_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute div instruction

            state_div1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_div2;
            end 

            state_div2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_div3;
            end 

            state_div3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_div4;
            end 

            state_div4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_div5;
            end 

            state_div5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_div6;
            end 

            // give time for div to compute division

            state_div6: begin
                next_state = state_div7;
            end 

            state_div7: begin
                next_state = state_div8;
            end 

            state_div8: begin
                next_state = state_div9;
                end

            state_div9: begin
                next_state = state_div10;
                end

            state_div10: begin
                next_state = state_div11;
                end

            state_div11: begin
                next_state = state_div12;
                end

            state_div12: begin
                next_state = state_div13;
                end

            state_div13: begin
                next_state = state_div14;
                end

            state_div14: begin
                next_state = state_div15;
                end

            state_div15: begin
                next_state = state_div16;
                end

            state_div16: begin
                next_state = state_div17;
                end

            state_div17: begin
                next_state = state_div18;
                end

            state_div18: begin
                // write op1 / op2 to mem[arg1]
                div_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute cp instruction

            state_cp1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_cp2;
            end 

            state_cp2: begin
                // transfer mem[arg2] to arg3 (any spare register will do)
                memory_drive = 1'b1;
                arg3_write = 1'b1;
                next_state = state_cp3;
            end 

            state_cp3: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_cp4;
            end 

            state_cp4: begin
                // write mem[arg2] to mem[arg1]
                arg3_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute and instruction

            state_and1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_and2;
            end 

            state_and2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_and3;
            end 

            state_and3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_and4;
            end

            state_and4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_and5;
            end 

            state_and5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_and6;
            end 

            state_and6: begin
                // write op1 & op2 to mem[arg1]
                bit_and_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute or instruction

            state_or1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_or2;
            end 

            state_or2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_or3;
            end 

            state_or3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_or4;
            end 

            state_or4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_or5;
            end 

            state_or5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_or6;
            end

            state_or6: begin
                // write op1 | op2 to mem[arg1]
                bit_or_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute not instruction

            state_not1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_not2;
            end 

            state_not2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_not3;
            end 

            state_not3: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_not4;
            end 

            state_not4: begin
                // write ~op1 to mem[arg1]
                bit_not_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute sl instruction

            state_sl1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sl2;
            end 

            state_sl2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_sl3;
            end 

            state_sl3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sl4;
            end 

            state_sl4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_sl5;
            end 

            state_sl5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sl6;
            end 

            state_sl6: begin
                // write op1 << op2 to mem[arg1]
                sl_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute sr instruction

            state_sr1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sr2;
            end 

            state_sr2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_sr3;
            end 

            state_sr3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sr4;
            end

            state_sr4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_sr5;
            end

            state_sr5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_sr6;
            end 

            state_sr6: begin
                // write op1 >> op2 to mem[arg1]
                sr_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute be instruction

            state_be1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_be2;
            end 

            state_be2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_be3;
            end 

            state_be3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_be4;
            end 

            state_be4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_be5;
            end 

            state_be5: begin
                // if (op1 == op2) take branch
                if (equal_out == 1'b1) begin
                    next_state = state_be6;
                end else begin
                    next_state = state_fetch1;
                end
            end 

            state_be6: begin
                // transfer arg1 to IAR
                arg1_drive = 1'b1;
                iar_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute bne instruction

            state_bne1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_bne2;
            end 

            state_bne2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_bne3;
            end 

            state_bne3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_bne4;
            end 

            state_bne4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_bne5;
            end 

            state_bne5: begin
                // if (op1 != op2) take branch
                if (equal_out == 1'b0) begin
                    next_state = state_bne6;
                end else begin
                    next_state = state_fetch1;
                end
            end 

            state_bne6: begin
                // transfer arg1 to IAR
                arg1_drive = 1'b1;
                iar_write = 1'b1;
                next_state = state_fetch1;
            end 

            // execute blt instruction

            state_blt1: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_blt2;
            end 

            state_blt2: begin
                // transfer mem[arg2] to op1
                memory_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_blt3;
            end 

            state_blt3: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_blt4;
            end 

            state_blt4: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_blt5;
            end 

            state_blt5: begin
                // if (op1 < op2) take branch
                if (lt_out == 1'b1) begin
                    next_state = state_blt6;
                end else begin
                    next_state = state_fetch1;
                end
            end 

            state_blt6: begin
                // transfer arg1 to IAR
                arg1_drive = 1'b1;
                iar_write = 1'b1;
                next_state = state_fetch1;
            end 

//begin cpfa instruction
		
	    state_cpfa1 : begin	
		// transfer arg2 to op1
		arg2_drive = 1'b1;
		op1_write = 1'b1;
		next_state = state_cpfa2;
	    end

	    state_cpfa2 : begin
		// transfer arg3 to address
		arg3_drive = 1'b1;
		address_write = 1'b1;
		next_state = state_cpfa3;
	    end

	    state_cpfa3 : begin
		// transfer mem[arg3] to op2
		memory_drive = 1'b1;
		op2_write = 1'b1;
		next_state = state_cpfa4;
	    end

	    state_cpfa4 : begin
		// transfer arg2 + mem[arg3] to address
		add_drive = 1'b1;
		address_write = 1'b1;
		next_state = state_cpfa5;
	    end

	    state_cpfa5 : begin
		// transfer mem[arg2 + mem[arg3]] to arg2
		memory_drive = 1'b1;
		arg2_write = 1'b1;
		next_state = state_cpfa6;
	    end

	    state_cpfa6 : begin
		// transfer arg1 to address
		arg1_drive = 1'b1;
		address_write = 1'b1;
		next_state = state_cpfa7;
	    end

	    state_cpfa7 : begin
		// transfer mem[arg2 + mem[arg3]] to mem[arg1]
		arg2_drive = 1'b1;
		memory_write = 1'b1;
		next_state = state_fetch1;
	    end

	state_cpta1: begin
                // transfer arg2 to op1
                arg2_drive = 1'b1;
                op1_write = 1'b1;
                next_state = state_cpta2;
            end 
            
            state_cpta2: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_cpta3;
            end 

            state_cpta3: begin
                // transfer mem[arg3] to op2
                memory_drive = 1'b1;
                op2_write = 1'b1;
                next_state = state_cpta4;
            end 
            
            state_cpta4: begin
                // transfer arg2 + memory[arg3] to arg3
                add_drive = 1'b1;
                arg3_write = 1'b1;
                next_state = state_cpta5;
            end 
            state_cpta5: begin
                // transfer arg1 to address
                arg1_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_cpta6;
            end 
            state_cpta6: begin
                // transfer memory[arg1] to arg2
                memory_drive = 1'b1;
                arg2_write = 1'b1;
                next_state = state_cpta7;
            end 
            state_cpta7: begin
                // transfer arg3 to address
                arg3_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_cpta8;
            end 
            state_cpta8: begin
                // transfer arg2 to memory[arg3]
                arg2_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_fetch1;
            end 

// execute call instruction

            state_call1: begin
					iar_drive = 1'b1;
					arg3_write = 1'b1;
               next_state = state_call2;
            end 

            state_call2: begin
                // transfer arg2 to address
                arg2_drive = 1'b1;
                address_write = 1'b1;
                next_state = state_call3;
            end 

            state_call3: begin
                // write arg3 to mem[arg2]
                iar_drive = 1'b1;
                memory_write = 1'b1;
                next_state = state_call4;
            end 

            state_call4: begin
                // transfer arg1 to IAR
                arg1_drive = 1'b1;
                iar_write = 1'b1;
                next_state = state_fetch1;
            end

//JOHN ADDED RET INSTRUCTIONS:
	    
				state_ret1: begin
					arg1_drive = 1'b1;
					address_write = 1'b1;
					next_state = state_ret2;
				end
	
				state_ret2: begin
					memory_drive = 1'b1;
					iar_write = 1'b1;
					next_state = state_fetch1;
				end
		

        endcase
    end

    always @(posedge clock) begin
        if (clock_valid == 1'b0) begin
        end else if (reset == 1'b1) begin
            state <= state_reset;
        end else begin
            state <= next_state;
        end
    end
endmodule
