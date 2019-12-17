/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * The USB controller is implemented as a device driver running on a
 * general-purpose CPU (separate from the main E100 CPU).
 */
module usb(
    input wire clock,
    input wire clock_valid,
    input wire reset,

    output wire [1:0] OTG_ADDR,         // OTG_ADDR[0] is A0; OTG_ADDR[1] is A1
    inout wire [15:0] OTG_DATA,
    output wire OTG_CS_N,
    output wire OTG_RD_N,
    output wire OTG_WR_N,
    output wire OTG_RST_N,

    input wire mouse_command,
    output wire mouse_response,
    output wire [31:0] mouse_deltax,
    output wire [31:0] mouse_deltay,
    output wire mouse_button1,
    output wire mouse_button2,
    output wire mouse_button3,
    
    input wire touch_command,
    output wire touch_response,
    output wire [9:0] touch_x,
    output wire [8:0] touch_y,
    output wire touch_pressed);

    wire [31:0] bus;

    wire [31:0] iar_out;
    wire iar_write, iar_drive;

    wire [31:0] op1_out;
    wire op1_write;

    wire [31:0] op2_out;
    wire op2_write;

    wire [31:0] add_out;
    wire add_drive;

    wire [31:0] sub_out;
    wire sub_drive;

    wire [31:0] mult_out;
    wire mult_drive;

    wire [31:0] div_out;
    wire div_drive;

    wire [31:0] bit_and_out;
    wire bit_and_drive;

    wire [31:0] bit_or_out;
    wire bit_or_drive;

    wire [31:0] bit_not_out;
    wire bit_not_drive;

    wire [31:0] sl_out;
    wire sl_drive;

    wire [31:0] sr_out;
    wire sr_drive;

    wire [31:0] plus1_out;
    wire plus1_drive;

    wire equal_out;
    wire lt_out;

    wire [31:0] opcode_out;
    wire opcode_write;

    wire [31:0] arg1_out;
    wire arg1_write, arg1_drive;

    wire [31:0] arg2_out;
    wire arg2_write, arg2_drive;

    wire [31:0] arg3_out;
    wire arg3_write, arg3_drive;

    wire address_write;
    wire memory_write;
    wire [31:0] memory_out;
    wire memory_drive;
    wire [31:0] address_out;

    register u3 (clock, clock_valid, reset, iar_write, bus, iar_out);
    register u4 (clock, clock_valid, reset, op1_write, bus, op1_out);
    register u5 (clock, clock_valid, reset, op2_write, bus, op2_out);
    register u6 (clock, clock_valid, reset, opcode_write, bus, opcode_out);
    register u7 (clock, clock_valid, reset, arg1_write, bus, arg1_out);
    register u8 (clock, clock_valid, reset, arg2_write, bus, arg2_out);
    register u9 (clock, clock_valid, reset, arg3_write, bus, arg3_out);

    plus1 u10 (iar_out, plus1_out);

    add u11 (op1_out, op2_out, add_out);
    sub u12 (op1_out, op2_out, sub_out);
    mult u13 (clock, op1_out, op2_out, mult_out);
    div u14 (clock, op1_out, op2_out, div_out);
    bit_and u15 (op1_out, op2_out, bit_and_out);
    bit_or u16 (op1_out, op2_out, bit_or_out);
    bit_not u17 (op1_out, bit_not_out);
    sl u18 (op1_out, op2_out, sl_out);
    sr u19 (op1_out, op2_out, sr_out);
    equal u20 (op1_out, op2_out, equal_out);
    lt u21 (op1_out, op2_out, lt_out);

    register u22 (clock, clock_valid, reset, address_write, bus, address_out);
    usbram u23 (bus[10:0], ~address_write, clock_valid, clock, bus,
                memory_write & ~address_out[31], memory_out);

    // Possible drivers of the main bus
    tristate u24 (iar_out, bus, iar_drive);
    tristate u25 (add_out, bus, add_drive);
    tristate u26 (sub_out, bus, sub_drive);
    tristate u27 (mult_out, bus, mult_drive);
    tristate u28 (div_out, bus, div_drive);
    tristate u29 (bit_and_out, bus, bit_and_drive);
    tristate u30 (bit_or_out, bus, bit_or_drive);
    tristate u31 (bit_not_out, bus, bit_not_drive);
    tristate u32 (sl_out, bus, sl_drive);
    tristate u33 (sr_out, bus, sr_drive);
    tristate u34 (plus1_out, bus, plus1_drive);
    tristate u35 (arg1_out, bus, arg1_drive);
    tristate u36 (arg2_out, bus, arg2_drive);
    tristate u37 (arg3_out, bus, arg3_drive);
    tristate u38 (memory_out, bus, memory_drive & ~address_out[31]);

    // interface to main CPU (mouse)
    in_port #(.WIDTH(1)) u39 (32'h80000070, clock, address_out, memory_drive, bus,
            mouse_command);
    out_port #(.WIDTH(1)) u40 (32'h80000071, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_response);
    out_port u41 (32'h80000072, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_deltax);
    out_port u42 (32'h80000073, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_deltay);
    out_port #(.WIDTH(1)) u43 (32'h80000074, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_button1);
    out_port #(.WIDTH(1)) u44 (32'h80000075, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_button2);
    out_port #(.WIDTH(1)) u45 (32'h80000076, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_button3);

    // interface to main CPU (touchscreen)
    in_port #(.WIDTH(1)) u46 (32'h800000e0, clock, address_out, memory_drive, bus,
            touch_command);
    out_port #(.WIDTH(1)) u47 (32'h800000e1, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, touch_response);
    out_port #(.WIDTH(10)) u48 (32'h800000e2, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, touch_x);
    out_port #(.WIDTH(9)) u49 (32'h800000e3, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, touch_y);
    out_port #(.WIDTH(1)) u50 (32'h800000e4, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, touch_pressed);

    // interface to USB device
    out_port #(.WIDTH(2)) u51 (32'h80001000, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_ADDR);
    inout_port #(.WIDTH(16)) u52 (32'h80001001, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_DATA);
    out_port #(.WIDTH(1)) u53 (32'h80001002, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_CS_N);
    out_port #(.WIDTH(1)) u54 (32'h80001003, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_RD_N);
    out_port #(.WIDTH(1)) u55 (32'h80001004, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_WR_N);
    out_port #(.WIDTH(1)) u56 (32'h80001005, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, OTG_RST_N);
    
    control u57 (clock, clock_valid, reset, opcode_out, equal_out, lt_out,
        iar_write, iar_drive, plus1_drive, op1_write, op2_write, add_drive,
        sub_drive, mult_drive, div_drive, bit_and_drive, bit_or_drive,
        bit_not_drive, sl_drive, sr_drive, opcode_write, arg1_write,
        arg1_drive, arg2_write, arg2_drive, arg3_write, arg3_drive,
        address_write, memory_write, memory_drive);

endmodule
