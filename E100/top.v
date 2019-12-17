/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module top(
    input wire OSC_50,
    input wire [3:0] KEY,               // ~KEY[0] toggles reset
    input wire [17:0] SW,               // SW[15:0] is port 0
    output wire [17:0] LED_RED,         // port 1
    output wire [8:0] LED_GREEN,        // LED_GREEN[8] shows reset
                                        // LED_GREEN[7:0] is port 2
    output wire [6:0] HEX0,             // port 3 (HEX3-HEX0)
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,             // port 4 (HEX7-HEX4)
    output wire [6:0] HEX5,
    output wire [6:0] HEX6,
    output wire [6:0] HEX7,

    output wire LCD_ON,
    output wire LCD_BLON,
    inout wire [7:0] LCD_DATA,
    output wire LCD_EN,
    output wire LCD_RS,
    output wire LCD_RW,

    input wire PS2_DAT,
    input wire PS2_CLK,

    output wire AUD_ADCLRCK,
    input wire AUD_ADCDAT,
    output wire AUD_DACLRCK,
    output wire AUD_DACDAT,
    output wire AUD_XCK,
    output wire AUD_BCLK,
    inout wire I2C_SDAT,
    output wire I2C_SCLK,
    input [7:0] TD_DATA,
    input wire TD_CLK27,
    output wire TD_RESET_N,

    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire VGA_CLK,
    output wire VGA_BLANK_N,
    output wire VGA_HS,
    output wire VGA_VS,
    output wire VGA_SYNC_N,

    inout wire [15:0] SRAM_DQ,
    output wire SRAM_CE_N,
    output wire SRAM_OE_N,
    output wire SRAM_LB_N,
    output wire SRAM_UB_N,
    output wire SRAM_WE_N,
    output wire [19:0] SRAM_ADDR,

    output wire [12:0] DRAM_ADDR,
    output wire [1:0] DRAM_BA,
    output wire DRAM_CS_N,
    output wire DRAM_RAS_N,
    output wire DRAM_CAS_N,
    output wire DRAM_WE_N,
    output wire DRAM_CKE,
    output wire DRAM_CLK,
    inout wire [31:0] DRAM_DQ,
    output wire [3:0] DRAM_DQM,

    output wire [1:0] OTG_ADDR,         // OTG_ADDR[0] is A0; OTG_ADDR[1] is A1
    inout wire [15:0] OTG_DATA,
    output wire OTG_CS_N,
    output wire OTG_RD_N,
    output wire OTG_WR_N,
    output wire OTG_RST_N,

    inout wire SD_CMD,
    inout wire [3:0] SD_DAT,
    inout wire SD_CLK,

    input wire UART_RXD,
    output wire UART_TXD,

    inout wire [31:0] GPIO);

    wire reset_edge;                    // reset signal (after edge detection)
    wire reset;                         // reset signal, synchronized to E100 clock
    wire reset_100m;                    // reset signal, synchronized to clock_100m
    wire reset_50m;                     // reset signal, synchronized to OSC_50
    wire reset_25m;                     // reset signal, synchronized to clock_25m
    wire reset_1_6m;                    // reset signal, synchronized to clock_1_6m
    wire reset_195k;                    // reset signal, synchronized to clock_195k

    wire [31:0] bus;

    wire clock, clock_valid;            // main E100 clock
    wire clock_100m;                    // 100 MHz clock
    wire clock_25m;                     // 25 MHz clock
    wire clock_1_6m;                    // 1.6 MHz clock
    wire clock_195k;                    // 195 KHz clock
    wire clock_8_1k;                    // 8.1 KHz clock

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

    wire [15:0] hexdigit_out;
    wire [15:0] hexdigit_out1;
    wire [31:0] timer_out;

    wire lcd_command;
    wire lcd_response;
    wire [3:0] lcd_x;
    wire lcd_y;
    wire [7:0] lcd_ascii;

    wire ps2_command;
    wire ps2_response;
    wire ps2_pressed;
    wire [7:0] ps2_ascii;

    wire sdram_command;
    wire sdram_write;
    wire [24:0] sdram_address;
    wire [31:0] sdram_data_write;
    wire sdram_response;
    wire [31:0] sdram_data_read;

    wire i2c_audio_done;
    wire i2c_video_done;

    wire speaker_command;
    wire speaker_response;
    wire [31:0] speaker_sample;

    wire microphone_command;
    wire microphone_response;
    wire [31:0] microphone_sample;

    wire vga_command;
    wire vga_response;
    wire vga_write;
    wire [9:0] vga_x1;
    wire [9:0] vga_y1;
    wire [9:0] vga_x2;
    wire [9:0] vga_y2;
    wire [23:0] vga_color_write;
    wire [23:0] vga_color_read;

    wire camera_to_vga_valid;
    wire camera_to_vga_ack;
    wire [9:0] camera_to_vga_x;
    wire [9:0] camera_to_vga_y;
    wire [14:0] camera_to_vga_color;

    wire mouse_command;
    wire mouse_response;
    wire [31:0] mouse_deltax;
    wire [31:0] mouse_deltay;
    wire mouse_button1;
    wire mouse_button2;
    wire mouse_button3;

    wire touch_command;
    wire touch_response;
    wire [9:0] touch_x;
    wire [8:0] touch_y;
    wire touch_pressed;

    wire sd_command;
    wire sd_response;
    wire sd_write;
    wire [29:0] sd_address;
    wire [31:0] sd_data_write;
    wire [31:0] sd_data_read;

    wire serial_receive_command;
    wire serial_receive_response;
    wire [7:0] serial_receive_data;

    wire serial_send_command;
    wire serial_send_response;
    wire [7:0] serial_send_data;
    
    wire fft_send_command;
    wire fft_send_response;
    wire fft_send_inverse;
    wire [15:0] fft_send_data_real;
    wire [15:0] fft_send_data_imag;
    wire fft_send_end;
    
    wire fft_receive_command;
    wire fft_receive_response;
    wire [15:0] fft_receive_data_real;
    wire [15:0] fft_receive_data_imag;
    wire fft_receive_end;	// not used

    wire camera_command, camera_response;
    wire [9:0] camera_x;
    wire [9:0] camera_y;
    wire [1:0] camera_scale;
    wire camera_mirror;

    wire pwm_command, pwm_response1, pwm_response2;
    wire [31:0] pwm_period;
    wire [31:0] pwm_high1;
	 wire [31:0] pwm_high2;

    wire spi_command, spi_response;
    wire [7:0] spi_send_data;
    wire [7:0] spi_receive_data;

    wire [18:0] ir_count;
	 
    clocks u1 (OSC_50, clock, clock_100m, clock_25m, clock_1_6m, clock_195k,
               clock_8_1k, clock_valid);

    reset_toggle u2 (OSC_50, ~KEY[0], reset_edge, LED_GREEN[8]); // maintains the reset signal

    // Synchronize reset_edge to various clocks to get rid of metastability.
    synchronizer #(.WIDTH(1)) u3 (clock, reset_edge, reset);
    synchronizer #(.WIDTH(1)) u4 (clock_100m, reset_edge, reset_100m);
    synchronizer #(.WIDTH(1)) u5 (OSC_50, reset_edge, reset_50m);
    synchronizer #(.WIDTH(1)) u6 (clock_25m, reset_edge, reset_25m);
    synchronizer #(.WIDTH(1)) u7 (clock_1_6m, reset_edge, reset_1_6m);

    register u8 (clock, clock_valid, reset, iar_write, bus, iar_out);
    register u9 (clock, clock_valid, reset, op1_write, bus, op1_out);
    register u10 (clock, clock_valid, reset, op2_write, bus, op2_out);
    register u11 (clock, clock_valid, reset, opcode_write, bus, opcode_out);
    register u12 (clock, clock_valid, reset, arg1_write, bus, arg1_out);
    register u13 (clock, clock_valid, reset, arg2_write, bus, arg2_out);
    register u14 (clock, clock_valid, reset, arg3_write, bus, arg3_out);

    plus1 u15 (iar_out, plus1_out);

    add u16 (op1_out, op2_out, add_out);
    sub u17 (op1_out, op2_out, sub_out);
    mult u18 (clock, op1_out, op2_out, mult_out);
    div u19 (clock, op1_out, op2_out, div_out);
    bit_and u20 (op1_out, op2_out, bit_and_out);
    bit_or u21 (op1_out, op2_out, bit_or_out);
    bit_not u22 (op1_out, bit_not_out);
    sl u23 (op1_out, op2_out, sl_out);
    sr u24 (op1_out, op2_out, sr_out);
    equal u25 (op1_out, op2_out, equal_out);
    lt u26 (op1_out, op2_out, lt_out);

    register u27 (clock, clock_valid, reset, address_write, bus, address_out);
    ram u28 (bus[13:0], ~address_write, clock_valid, clock, bus,
             memory_write & ~address_out[31], memory_out);

    // Possible drivers of the main bus
    tristate u29 (iar_out, bus, iar_drive);
    tristate u30 (add_out, bus, add_drive);
    tristate u31 (sub_out, bus, sub_drive);
    tristate u32 (mult_out, bus, mult_drive);
    tristate u33 (div_out, bus, div_drive);
    tristate u34 (bit_and_out, bus, bit_and_drive);
    tristate u35 (bit_or_out, bus, bit_or_drive);
    tristate u36 (bit_not_out, bus, bit_not_drive);
    tristate u37 (sl_out, bus, sl_drive);
    tristate u38 (sr_out, bus, sr_drive);
    tristate u39 (plus1_out, bus, plus1_drive);
    tristate u40 (arg1_out, bus, arg1_drive);
    tristate u41 (arg2_out, bus, arg2_drive);
    tristate u42 (arg3_out, bus, arg3_drive);
    tristate u43 (memory_out, bus, memory_drive & ~address_out[31]);

    // switch
    in_port #(.WIDTH(18)) u44 (32'h80000000, clock, address_out, memory_drive, bus,
            SW[17:0]);

    // led_red
    out_port #(.WIDTH(18)) u45 (32'h80000001, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, LED_RED[17:0]);

    // led_green port
    out_port #(.WIDTH(8)) u46 (32'h80000002, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, LED_GREEN[7:0]);

    // HEX3-HEX0
    hexdigit u47 (hexdigit_out[3:0], HEX0);
    hexdigit u48 (hexdigit_out[7:4], HEX1);
    hexdigit u49 (hexdigit_out[11:8], HEX2);
    hexdigit u50 (hexdigit_out[15:12], HEX3);
    out_port #(.WIDTH(16)) u51 (32'h80000003, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, hexdigit_out[15:0]);

    // HEX7-HEX4
    hexdigit u52 (hexdigit_out1[3:0], HEX4);
    hexdigit u53 (hexdigit_out1[7:4], HEX5);
    hexdigit u54 (hexdigit_out1[11:8], HEX6);
    hexdigit u55 (hexdigit_out1[15:12], HEX7);
    out_port #(.WIDTH(16)) u56 (32'h80000004, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, hexdigit_out1[15:0]);

    // timer
    timer u57 (clock, clock_8_1k, clock_valid, reset, timer_out);
    in_port u58 (32'h80000005, clock, address_out, memory_drive,
            bus, timer_out);

    // LCD controller
    lcd u59 (clock_1_6m, clock_valid, reset_1_6m, LCD_ON, LCD_BLON,
         LCD_DATA, LCD_EN, LCD_RS, LCD_RW, lcd_command, lcd_response, lcd_x,
         lcd_y, lcd_ascii);
    out_port #(.WIDTH(1)) u60 (32'h80000010, clock, clock_1_6m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, lcd_command);
    in_port #(.WIDTH(1)) u61 (32'h80000011, clock, address_out, memory_drive, bus,
            lcd_response);
    out_port #(.WIDTH(4)) u62 (32'h80000012, clock, clock_1_6m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, lcd_x[3:0]);
    out_port #(.WIDTH(1)) u63 (32'h80000013, clock, clock_1_6m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, lcd_y);
    out_port #(.WIDTH(8)) u64 (32'h80000014, clock, clock_1_6m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, lcd_ascii[7:0]);
    
    // ps/2 controller
    ps2_keyboard u65 (clock_25m, clock_valid, reset_25m, PS2_CLK, PS2_DAT,
                      ps2_command, ps2_response, ps2_pressed, ps2_ascii);
    out_port #(.WIDTH(1)) u66 (32'h80000020, clock, clock_25m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, ps2_command);
    in_port #(.WIDTH(1)) u67 (32'h80000021, clock, address_out, memory_drive, bus,
            ps2_response);
    in_port #(.WIDTH(1)) u68 (32'h80000022, clock, address_out, memory_drive, bus,
            ps2_pressed);
    in_port #(.WIDTH(8)) u69 (32'h80000023, clock, address_out, memory_drive, bus,
            ps2_ascii);

    // sdram controller
    sdram u70 (OSC_50, clock_195k, clock_valid, reset_50m, sdram_command,
           sdram_response, sdram_write, sdram_address, sdram_data_write,
           sdram_data_read, DRAM_ADDR, DRAM_BA, DRAM_CS_N,
           DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N, DRAM_CKE, DRAM_CLK, DRAM_DQ,
           DRAM_DQM);
    out_port #(.WIDTH(1)) u71 (32'h80000030, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sdram_command);
    in_port #(.WIDTH(1)) u72 (32'h80000031, clock, address_out, memory_drive, bus,
            sdram_response);
    out_port #(.WIDTH(1)) u73 (32'h80000032, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sdram_write);
    out_port #(.WIDTH(25)) u74 (32'h80000033, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sdram_address);
    out_port u75 (32'h80000034, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sdram_data_write);
    in_port u76 (32'h80000035, clock, address_out, memory_drive, bus,
            sdram_data_read);

    // I2C configuration
    i2c_config u77 (OSC_50, clock_8_1k, clock_valid, reset_50m, I2C_SDAT,
                I2C_SCLK, i2c_audio_done, i2c_video_done);

    // speaker controller
    speaker u78 (clock_25m, clock_8_1k, clock_valid, reset_25m, i2c_audio_done,
             speaker_command, speaker_response, speaker_sample, AUD_XCK, AUD_BCLK,
             AUD_DACLRCK, AUD_DACDAT);

    out_port #(.WIDTH(1)) u79 (32'h80000040, clock, clock_25m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, speaker_command);
    in_port #(.WIDTH(1)) u80 (32'h80000041, clock, address_out, memory_drive, bus,
            speaker_response
        );
    out_port u81 (32'h80000042, clock, clock_25m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, speaker_sample);

    // microphone controller
    microphone u82 (clock_25m, clock_8_1k, clock_valid, reset_25m,
                i2c_audio_done, microphone_command, microphone_response,
                microphone_sample, AUD_BCLK, AUD_ADCLRCK, AUD_ADCDAT);

    out_port #(.WIDTH(1)) u83 (32'h80000050, clock, clock_25m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, microphone_command);
    in_port #(.WIDTH(1)) u84 (32'h80000051, clock, address_out, memory_drive, bus,
            microphone_response);
    in_port u85 (32'h80000052, clock, address_out, memory_drive, bus,
            microphone_sample);

    // VGA controller
    vga u86 (clock_100m, clock_valid, reset_100m,
         vga_command, vga_response, vga_write, vga_x1, vga_y1, vga_x2, vga_y2,
         {vga_color_write[23:19], vga_color_write[15:11], vga_color_write[7:3]},
         {vga_color_read[23:19], vga_color_read[15:11], vga_color_read[7:3]},
	 camera_to_vga_valid,
         camera_to_vga_ack, camera_to_vga_x, camera_to_vga_y,
         camera_to_vga_color, VGA_R, VGA_G, VGA_B, VGA_CLK, VGA_BLANK_N,
         VGA_HS, VGA_VS, VGA_SYNC_N, SRAM_DQ, SRAM_CE_N, SRAM_OE_N,
         SRAM_LB_N, SRAM_UB_N, SRAM_WE_N, SRAM_ADDR);

    out_port #(.WIDTH(1)) u87 (32'h80000060, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_command);
    in_port #(.WIDTH(1)) u88 (32'h80000061, clock, address_out, memory_drive, bus,
            vga_response);
    out_port #(.WIDTH(1)) u89 (32'h80000062, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_write);
    out_port #(.WIDTH(10)) u90 (32'h80000063, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_x1);
    out_port #(.WIDTH(10)) u91 (32'h80000064, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_y1);
    out_port #(.WIDTH(10)) u92 (32'h80000065, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_x2);
    out_port #(.WIDTH(10)) u93 (32'h80000066, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_y2);
    out_port #(.WIDTH(24)) u94 (32'h80000067, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, vga_color_write);
    in_port #(.WIDTH(24)) u95 (32'h80000068, clock, address_out, memory_drive, bus,
            {vga_color_read[23:19], 3'b0, vga_color_read[15:11], 3'b0, vga_color_read[7:3], 3'b0});

    // USB controller (used for both mouse and touchscreen)
    usb u96 (OSC_50, clock_valid, reset_50m, OTG_ADDR, OTG_DATA, OTG_CS_N,
              OTG_RD_N, OTG_WR_N, OTG_RST_N, mouse_command, mouse_response,
              mouse_deltax, mouse_deltay, mouse_button1, mouse_button2,
              mouse_button3, touch_command, touch_response,
              touch_x, touch_y, touch_pressed);

    out_port #(.WIDTH(1)) u97 (32'h80000070, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, mouse_command);
    in_port #(.WIDTH(1)) u98 (32'h80000071, clock, address_out, memory_drive, bus,
            mouse_response);
    in_port u99 (32'h80000072, clock, address_out, memory_drive, bus,
            mouse_deltax);
    in_port u100 (32'h80000073, clock, address_out, memory_drive, bus,
            mouse_deltay);
    in_port #(.WIDTH(1)) u101 (32'h80000074, clock, address_out, memory_drive, bus,
            mouse_button1);
    in_port #(.WIDTH(1)) u102 (32'h80000075, clock, address_out, memory_drive, bus,
            mouse_button2);
    in_port #(.WIDTH(1)) u103 (32'h80000076, clock, address_out, memory_drive, bus,
            mouse_button3);

    out_port #(.WIDTH(1)) u104 (32'h800000e0, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, touch_command);
    in_port #(.WIDTH(1)) u105 (32'h800000e1, clock, address_out, memory_drive, bus,
            touch_response);
    in_port #(.WIDTH(10)) u106 (32'h800000e2, clock, address_out, memory_drive, bus,
            touch_x);
    in_port #(.WIDTH(9)) u107 (32'h800000e3, clock, address_out, memory_drive, bus,
            touch_y);
    in_port #(.WIDTH(1)) u108 (32'h800000e4, clock, address_out, memory_drive, bus,
            touch_pressed);

    // SD controller
    sd u109 (OSC_50, clock_valid, reset_50m, SD_CMD, SD_DAT[3], SD_DAT[0],
	     SD_CLK, sd_command, sd_response, sd_write, sd_address,
	     sd_data_write, sd_data_read);

    out_port #(.WIDTH(1)) u110 (32'h80000080, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sd_command);
    in_port #(.WIDTH(1)) u111 (32'h80000081, clock, address_out, memory_drive, bus,
            sd_response);
    out_port #(.WIDTH(1)) u112 (32'h80000082, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sd_write);
    out_port #(.WIDTH(30)) u113 (32'h80000083, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sd_address);
    out_port u114 (32'h80000084, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, sd_data_write);
    in_port u115 (32'h80000085, clock, address_out, memory_drive, bus,
            sd_data_read);

    // serial port receive controller
    serial_receive u116 (OSC_50, clock_valid, reset_50m, UART_RXD,
                    serial_receive_command, serial_receive_response,
                    serial_receive_data);

    out_port #(.WIDTH(1)) u117 (32'h80000090, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, serial_receive_command);
    in_port #(.WIDTH(1)) u118 (32'h80000091, clock, address_out, memory_drive, bus,
            serial_receive_response);
    in_port #(.WIDTH(8)) u119 (32'h80000092, clock, address_out, memory_drive, bus,
            serial_receive_data);

    // serial port send controller
    serial_send u120 (OSC_50, clock_valid, reset_50m, UART_TXD,
                 serial_send_command, serial_send_response, serial_send_data);

    out_port #(.WIDTH(1)) u121 (32'h800000a0, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, serial_send_command);
    in_port #(.WIDTH(1)) u122 (32'h800000a1, clock, address_out, memory_drive, bus,
            serial_send_response);
    out_port #(.WIDTH(8)) u123 (32'h800000a2, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, serial_send_data);

    // camera controller (if you disable this controller, you must
    // assign camera_to_vga_valid = 1'b0 (otherwise there will be glitches
    // on the VGA).
    camera u124 (clock_100m, clock_valid, reset_100m, i2c_video_done,
                TD_RESET_N, TD_CLK27, TD_DATA, camera_to_vga_valid,
                camera_to_vga_ack, camera_to_vga_x, camera_to_vga_y,
                camera_to_vga_color, camera_command, camera_response,
                camera_x, camera_y, camera_scale, camera_mirror);
    out_port #(.WIDTH(1)) u125 (32'h800000b0, clock, clock_100m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, camera_command);
    in_port #(.WIDTH(1)) u126 (32'h800000b1, clock, address_out, memory_drive, bus,
            camera_response);

    out_port #(.WIDTH(10)) u127 (32'h800000b2, clock, clock_100m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, camera_x);
    out_port #(.WIDTH(10)) u128 (32'h800000b3, clock, clock_100m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, camera_y);
    out_port #(.WIDTH(2)) u129 (32'h800000b4, clock, clock_100m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, camera_scale);
    out_port #(.WIDTH(1)) u130 (32'h800000b5, clock, clock_100m, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, camera_mirror);

    // fft controller
    fft u131 (OSC_50, clock_valid, reset_50m, fft_send_command, fft_send_response,
	    fft_send_inverse, fft_send_data_real, fft_send_data_imag,
	    fft_send_end, fft_receive_command, fft_receive_response,
	    fft_receive_data_real, fft_receive_data_imag, fft_receive_end);
    out_port #(.WIDTH(1)) u132 (32'h800000c0, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_send_command);
    in_port #(.WIDTH(1)) u133 (32'h800000c1, clock, address_out, memory_drive, bus,
            fft_send_response);
    out_port #(.WIDTH(16)) u134 (32'h800000c2, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_send_data_real);
    out_port #(.WIDTH(16)) u135 (32'h800000c3, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_send_data_imag);
    out_port #(.WIDTH(1)) u136 (32'h800000c4, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_send_inverse);
    out_port #(.WIDTH(1)) u137 (32'h800000c5, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_send_end);
    out_port #(.WIDTH(1)) u138 (32'h800000d0, clock, OSC_50, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, fft_receive_command);
    in_port #(.WIDTH(1)) u139 (32'h800000d1, clock, address_out, memory_drive, bus,
            fft_receive_response);
    in_port u140 (32'h800000d2, clock, address_out, memory_drive, bus,
            {
	    // sign extend the result to 32 bits
            {16{fft_receive_data_real[15]}},
            fft_receive_data_real
	    }
	);
    in_port u141 (32'h800000d3, clock, address_out, memory_drive, bus,
            {
	    // sign extend the result to 32 bits
            {16{fft_receive_data_imag[15]}},
	    fft_receive_data_imag
	    }
	);

    // PWM controller for motor 1
    pwm u142 (clock_100m, clock_valid, reset_100m, pwm_command, pwm_response1,
              pwm_period, pwm_high1, GPIO[10], GPIO[11], GPIO[12]);
    out_port #(.WIDTH(1)) u143 (32'h800000f0, clock, clock_100m, clock_valid,
            reset, address_out, memory_drive, memory_write, bus, pwm_command);
    in_port #(.WIDTH(1)) u144 (32'h800000f1, clock, address_out, memory_drive, bus,
            pwm_response1 & pwm_response2);
    out_port #(.WIDTH(32)) u145 (32'h800000f2, clock, clock_100m, clock_valid,
            reset, address_out, memory_drive, memory_write, bus, pwm_period);
    out_port #(.WIDTH(32)) u146 (32'h800000f3, clock, clock_100m, clock_valid,
            reset, address_out, memory_drive, memory_write, bus, pwm_high1);
	
	 // PWM controller for motor 2
	pwm u154 (clock_100m, clock_valid, reset_100m, pwm_command, pwm_response2,
              pwm_period, pwm_high2, GPIO[13], GPIO[14], GPIO[15]);
    out_port #(.WIDTH(32)) u155 (32'h800000f4, clock, clock_100m, clock_valid,
            reset, address_out, memory_drive, memory_write, bus, pwm_high2);
				
    // SPI controller
    spi u147 (clock, clock_valid, reset, GPIO[4], GPIO[5], GPIO[6], GPIO[7],
              spi_command, spi_response, spi_send_data, spi_receive_data);

    out_port #(.WIDTH(1)) u148 (32'h80000100, clock, clock, clock_valid, reset,
	    address_out, memory_drive, memory_write, bus, spi_command);
    in_port #(.WIDTH(1)) u149 (32'h80000101, clock, address_out, memory_drive, bus,
            spi_response);
    out_port #(.WIDTH(8)) u150 (32'h80000102, clock, clock, clock_valid, reset,
            address_out, memory_drive, memory_write, bus, spi_send_data);
    in_port #(.WIDTH(8)) u151 (32'h80000103, clock, address_out, memory_drive, bus,
            spi_receive_data);

	 // IR controller - VCC through GPIO8 and sends "OUT" to GPIO8 for now
    ir u152 (clock, clock_valid, reset, ir_count, GPIO[8]);

	 // May have to change addresses of ports later
    in_port #(.WIDTH(19)) u153 (32'h80000110, clock, address_out, memory_drive, bus, ir_count);
				
    control u157 (clock, clock_valid, reset, opcode_out, equal_out, lt_out,
        iar_write, iar_drive, plus1_drive, op1_write, op2_write, add_drive,
        sub_drive, mult_drive, div_drive, bit_and_drive, bit_or_drive,
        bit_not_drive, sl_drive, sr_drive, opcode_write, arg1_write,
        arg1_drive, arg2_write, arg2_drive, arg3_write, arg3_drive,
        address_write, memory_write, memory_drive);

endmodule
