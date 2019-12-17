/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * LCD controller for Crystalfontz CFAH1602B-TMC-JP.
 */
module lcd(
    input wire clock_1_6m,		// From the spec, 230 ns cycle time
    					// should be long enough, but even 320 ns
					// didn't work (it printed every other
					// character), so I lengthened the cycle
					// time to 640 ns.
    input wire clock_valid,
    input wire reset_1_6m,

    output reg LCD_ON,
    output reg LCD_BLON,
    inout reg [7:0] LCD_DATA,
    output reg LCD_EN,
    output reg LCD_RS,
    output reg LCD_RW,

    input wire lcd_command,
    output reg lcd_response,
    input wire [3:0] lcd_x,
    input wire lcd_y,
    input wire [7:0] lcd_ascii);

    reg [5:0] state;
    reg [5:0] next_state;
    reg [16:0] timer;		// each tick is .64 us
    reg timer_clear;
    reg next_lcd_response;

    reg en_clear;
    reg en_set;

    reg rs_clear;
    reg rs_set;

    reg rw_clear;
    reg rw_set;

    reg [7:0] lcd_data_out;
    reg lcd_data_out_write;
    reg [7:0] lcd_data_out_val;

    reg [7:0] lcd_data_in;
    reg lcd_data_in_write;

    always @* begin
        if (LCD_RW == 1'b0) begin
            LCD_DATA = lcd_data_out;
        end else begin
            LCD_DATA = {8{1'bz}};
        end
    end

    parameter state_reset =        6'h0;
    parameter state_init1 =        6'h1;
    parameter state_init2 =        6'h2;
    parameter state_init3 =        6'h3;
    parameter state_init4 =        6'h4;
    parameter state_init5 =        6'h5;
    parameter state_init6 =        6'h6;
    parameter state_init7 =        6'h7;
    parameter state_init8 =        6'h8;
    parameter state_init9 =        6'h9;
    parameter state_init10 =       6'ha;
    parameter state_init11 =       6'hb;
    parameter state_init12 =       6'hc;
    parameter state_init13 =       6'hd;
    parameter state_init14 =       6'he;
    parameter state_init15 =       6'hf;
    parameter state_init16 =       6'h10;
    parameter state_on1 =          6'h11;
    parameter state_on2 =          6'h12;
    parameter state_busy1 =        6'h13;
    parameter state_busy2 =        6'h14;
    parameter state_busy3 =        6'h15;
    parameter state_busy4 =        6'h16;
    parameter state_idle =         6'h17;
    parameter state_cursor1 =      6'h18;
    parameter state_cursor2 =      6'h19;
    parameter state_busy_cursor1 = 6'h1a;
    parameter state_busy_cursor2 = 6'h1b;
    parameter state_busy_cursor3 = 6'h1c;
    parameter state_busy_cursor4 = 6'h1d;
    parameter state_char1 =	   6'h1e;
    parameter state_char2 =        6'h1f;
    parameter state_char3 =        6'h20;
    parameter state_response =     6'h21;

    always @* begin
        // default values for control signals
        LCD_ON = 1'b1;
        LCD_BLON = 1'b1;
        next_state = state_reset;

        lcd_data_out_write = 1'b0;
        lcd_data_out_val = 8'h00;
	lcd_data_in_write = 1'b0;

        next_lcd_response = 1'b0;

	en_set = 1'b0;
	en_clear = 1'b0;
	rs_set = 1'b0;
	rs_clear = 1'b0;
	rw_set = 1'b0;
	rw_clear = 1'b0;
	timer_clear = 1'b0;

	case (state)

	    state_reset: begin
		next_state = state_init1;
	    end

	    // initialize the LCD

	    state_init1: begin
		en_clear = 1'b1;
		rs_clear = 1'b1;
		rw_clear = 1'b1;
	        timer_clear = 1'b1;
		next_state = state_init2;
	    end

	    state_init2: begin
		// power-up: wait at least 15 ms
		if (timer[16] == 1'b1) begin	// 42 ms
		    next_state = state_init3;
		end else begin
		    next_state = state_init2;
		end
	    end

	    // 1st function set

	    state_init3: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00111000;

		next_state = state_init4;
	    end

	    state_init4: begin
		en_clear = 1'b1;

		// wait at least 4.1 ms
		if (timer[14] == 1'b1) begin	// 10 ms
		    next_state = state_init5;
		end else begin
		    next_state = state_init4;
		end
	    end

	    // 2nd function set

	    state_init5: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00111000;

		next_state = state_init6;
	    end

	    state_init6: begin
		en_clear = 1'b1;

		// wait at least 100 us
		if (timer[10] == 1'b1) begin    // 660 us
		    next_state = state_init7;
		end else begin
		    next_state = state_init6;
		end
	    end

	    // 3rd function set

	    state_init7: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00111000;

		next_state = state_init8;
	    end

	    state_init8: begin
		en_clear = 1'b1;

		// wait at least 39 us (is a sleep is missing from the spec?)
		if (timer[9] == 1'b1) begin    // 330 us
		    next_state = state_init9;
		end else begin
		    next_state = state_init8;
		end
	    end

	    // 4th function set

	    state_init9: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00111000;

		next_state = state_init10;
	    end

	    state_init10: begin
		en_clear = 1'b1;

		// wait at least 39 us
		if (timer[9] == 1'b1) begin    // 330 us
		    next_state = state_init11;
		end else begin
		    next_state = state_init10;
		end
	    end

	    // display off

	    state_init11: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00001000;

		next_state = state_init12;
	    end

	    state_init12: begin
		en_clear = 1'b1;

		// wait at least 39 us
		if (timer[9] == 1'b1) begin    // 330 us
		    next_state = state_init13;
		end else begin
		    next_state = state_init12;
		end
	    end

	    // clear display

	    state_init13: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00000001;

		next_state = state_init14;
	    end

	    state_init14: begin
		en_clear = 1'b1;

		// wait at least 1.53 ms
		if (timer[13] == 1'b1) begin    // 5.2 ms
		    next_state = state_init15;
		end else begin
		    next_state = state_init14;
		end
	    end

	    // entry mode set

	    state_init15: begin
	        timer_clear = 1'b1;

		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00000110;

		next_state = state_init16;
	    end

	    state_init16: begin
		en_clear = 1'b1;

		// wait at least 39 us
		if (timer[9] == 1'b1) begin    // 330 us
		    next_state = state_on1;
		end else begin
		    next_state = state_init16;
		end
	    end

	    // display on

	    state_on1: begin
		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = 8'b00001100;

		next_state = state_on2;
	    end

	    state_on2: begin
		en_clear = 1'b1;
		next_state = state_busy1;
	    end

	    // wait for busy flag to be low

	    state_busy1: begin
		rs_clear = 1'b1;
		rw_set = 1'b1;
		next_state = state_busy2;
	    end

	    state_busy2: begin
		en_set = 1'b1;
		next_state = state_busy3;
	    end

	    state_busy3: begin
		lcd_data_in_write = 1'b1;
		next_state = state_busy4;
	    end

	    state_busy4: begin
		en_clear = 1'b1;

		if (lcd_data_in[7] == 1'b1) begin
		    next_state = state_busy2;
		end else begin
		    next_state = state_idle;
		end
	    end

	    // wait for command from E100

	    state_idle: begin
		en_clear = 1'b1;
		rs_clear = 1'b1;
		rw_clear = 1'b1;

		if (lcd_command == 1'b1) begin
		    next_state = state_cursor1;
		end else begin
		    next_state = state_idle;
		end
	    end

	    // write cursor position

	    state_cursor1: begin
		// LCD_RS, LCD_RW already set up
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = {1'b1, lcd_y, 2'b00, lcd_x};

		next_state = state_cursor2;
	    end

	    state_cursor2: begin
		en_clear = 1'b1;
		next_state = state_busy_cursor1;
	    end

	    // wait for busy flag to be low (for cursor command)

	    state_busy_cursor1: begin
		rs_clear = 1'b1;
		rw_set = 1'b1;
		next_state = state_busy_cursor2;
	    end

	    state_busy_cursor2: begin
		en_set = 1'b1;
		next_state = state_busy_cursor3;
	    end

	    state_busy_cursor3: begin
	        lcd_data_in_write = 1'b1;
		next_state = state_busy_cursor4;
	    end

	    state_busy_cursor4: begin
	        en_clear = 1'b1;

		if (lcd_data_in[7] == 1'b1) begin
		    next_state = state_busy_cursor2;
		end else begin
		    next_state = state_char1;
		end
	    end

	    // write character

	    state_char1: begin
		rs_set = 1'b1;
		rw_clear = 1'b1;
		next_state = state_char2;
	    end

	    state_char2: begin
		en_set = 1'b1;
		lcd_data_out_write = 1'b1;
		lcd_data_out_val = lcd_ascii;
		next_state = state_char3;
	    end

	    state_char3: begin
		en_clear = 1'b1;
		next_state = state_response;
	    end

	    // respond to E100 (must first be done using lcd_x, lcd_y,
            // lcd_ascii).  Will wait for busy flag for the character
	    // command after E100 responds.

	    state_response: begin
		next_lcd_response = 1'b1;
		if (lcd_command == 1'b1) begin
		    next_state = state_response;
		end else begin
		    next_state = state_busy1;
		end
	    end

        endcase

    end

    always @(posedge clock_1_6m) begin
        if (clock_valid == 1'b0) begin
	end else begin
	    if (reset_1_6m == 1'b1) begin
		state <= state_reset;
	    end else begin
		state <= next_state;
	    end

	    if (timer_clear == 1'b1) begin
		timer <= 17'h0;
	    end else begin
		timer <= timer + 17'h1;
	    end

	    if (en_clear == 1'b1) begin
		LCD_EN <= 1'b0;
	    end else if (en_set == 1'b1) begin
		LCD_EN <= 1'b1;
	    end

	    if (rs_clear == 1'b1) begin
		LCD_RS <= 1'b0;
	    end else if (rs_set == 1'b1) begin
		LCD_RS <= 1'b1;
	    end

	    if (rw_clear == 1'b1) begin
		LCD_RW <= 1'b0;
	    end else if (rw_set == 1'b1) begin
		LCD_RW <= 1'b1;
	    end

	    if (lcd_data_out_write == 1'b1) begin
	        lcd_data_out <= lcd_data_out_val;
	    end

	    // LCD_DATA is prone to glitching.  This caused a bizarre error in
	    // which next_state got set to an illegal value.  Register LCD_DATA
	    // to solve this error.
	    if (lcd_data_in_write == 1'b1) begin
		lcd_data_in <= LCD_DATA;
	    end

	    // register lcd_response to prevent glitches
	    lcd_response <= next_lcd_response;
	end
    end

endmodule
