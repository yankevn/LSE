/*
 * Copyright (c) 2006, Steven Lieberman.  All rights reserved.  This software
 * is supplied as is without expressed or implied warranties of any kind.
 */
module ps2_keyboard(
    input wire clock_25m,		// can be any speed that's sufficiently
    					// faster than the 10-16.7 kHz signal
					// produced by the PS/2 serial
					// interface.
    input wire clock_valid,
    input wire reset_25m,
    input wire PS2_CLK,			// from port
    input wire PS2_DAT,			// from port
    input wire ps2_command,
    output reg ps2_response_sync,
    output reg ps2_pressed_sync,	// 1 = pressed, 0 = released
    output reg [7:0] ps2_ascii_sync);

    reg prev_key_state;			// really mem_data_out[0]
    reg prev_shift_state;		// really mem_data_out[1]
    reg set_prev_key_state;		// really mem_data_in[0]
    reg set_prev_shift_state;		// really mem_data_in[1]

    // register: shift_actual
    reg shift_actual_write;
    reg shift_actual_in;
    reg shift_actual_out;

    // register: lowercase
    reg lowercase_write;
    wire [7:0] lowercase_in;
    reg [7:0] lowercase_out;

    // register: uppercase
    reg uppercase_write;
    wire [7:0] uppercase_in;
    reg [7:0] uppercase_out;

    reg mem_addr_en;
    reg mem_wr_en;
    reg [7:0] mem_addr;
    reg [1:0] mem_data_in;
    wire [1:0] mem_data_out;

    wire [7:0] scan_code;
    wire ps2_serial_valid;
    reg  ps2_serial_ack;

    reg is_extended;
    reg is_break_code;
    reg is_shift_char;

    reg ps2_response;
    reg ps2_pressed;
    reg [7:0] ps2_ascii;

    /*
     * Register these to prevent glitches
     */
    always @(posedge clock_25m) begin
	ps2_response_sync <= ps2_response;
	ps2_pressed_sync <= ps2_pressed;
	ps2_ascii_sync <= ps2_ascii;
    end

    always @* begin
	is_extended   = (scan_code == 8'hE0);
	is_break_code = (scan_code == 8'hF0);
	is_shift_char = (scan_code == 8'h12 || scan_code == 8'h59);

	prev_key_state   = mem_data_out[0];
	prev_shift_state = mem_data_out[1];
	
	mem_data_in[0] = set_prev_key_state;
	mem_data_in[1] = set_prev_shift_state;
	mem_addr = lowercase_in;

	ps2_pressed = prev_key_state;

	if (prev_shift_state == 1'b1) begin
	    ps2_ascii = uppercase_out;
	end else begin
	    ps2_ascii = lowercase_out;
	end

    end

    keyboard_ram u1 (mem_addr, ~mem_addr_en, clock_valid, clock_25m, mem_data_in,
		 mem_wr_en, mem_data_out);

    scancode2ascii u2 (scan_code, lowercase_in, uppercase_in);

    ps2_serial u3 (clock_25m, clock_valid, reset_25m, PS2_CLK, PS2_DAT,
                ps2_serial_ack, scan_code, ps2_serial_valid);

    /*
     * register to store current shift status -- yes, this effectively
     * duplicates the number of states, but I think it makes the code much
     * easier to follow.
     */
    always @(posedge clock_25m) begin
	if (clock_valid == 1'b0) begin
	end else begin
	    if (shift_actual_write == 1'b1) begin
		shift_actual_out <= shift_actual_in;
	    end
	    if (lowercase_write == 1'b1) begin
		lowercase_out <= lowercase_in;
	    end
	    if (uppercase_write == 1'b1) begin
		uppercase_out <= uppercase_in;
	    end
	end
    end

    /*
     * The state machine converts the scancodes for use by the E100 CPU.
     * It does the following:
     *     (1) ignores extended scancodes
     *     (2) ignores typematic repeat, or any double-event using keyboard_ram
     *     (3) stores current shift status in the shift_actual register
     *     (4) makes sure that when a key is released, the ASCII output to the
     *         E100 is the same case (uppercase/lowercase) as it was when the
     *	       key was originally pressed. this is done using keyboard_ram.
     * It does not read the values directly from the PS/2 port; the module
     * ps2_serial.v conducts the serial protocol and returns full bytes.
     */
    reg [3:0] state;
    reg [3:0] next_state;

    parameter state_reset               = 4'h0;
    parameter state_idle                = 4'h1;
    parameter state_check               = 4'h2;
    parameter state_prevalid            = 4'h3;
    parameter state_valid               = 4'h4;
    parameter state_response            = 4'h5;
    parameter state_break               = 4'h6;
    parameter state_break_waitnext      = 4'h7;
    parameter state_break_check         = 4'h8;
    parameter state_break_prevalid      = 4'h9;
    parameter state_extended            = 4'ha;
    parameter state_extended_waitnext   = 4'hb;
    parameter state_extended_ignorebyte = 4'hc;
    parameter state_shift_pressed       = 4'hd;
    parameter state_shift_released      = 4'he;

    always @(posedge clock_25m) begin
	if (clock_valid == 1'b0) begin
	end else if (reset_25m == 1'b1) begin
	    state <= state_reset;
	end else begin
	    state <= next_state;
	end
    end


    always @* begin
	mem_addr_en           = 1'b0;
	lowercase_write       = 1'b0;
	uppercase_write       = 1'b0;
	ps2_serial_ack        = 1'b0;
	mem_wr_en             = 1'b0;
	set_prev_key_state    = 1'b0;
	set_prev_shift_state  = 1'b0;
	ps2_response          = 1'b0;
	shift_actual_write    = 1'b0;
	shift_actual_in       = 1'b0;
	next_state            = state_reset;

	case (state)
	
	    state_reset: begin
		next_state = state_idle;
	    end

	    state_idle: begin
		mem_addr_en      = 1'b1;
		lowercase_write  = 1'b1;
		uppercase_write  = 1'b1;
		if (ps2_serial_valid == 1'b1) begin
		    if (is_extended == 1'b1) begin
			next_state = state_extended;    // extended char
		    end else if (is_break_code == 1'b1) begin
			next_state = state_break;       // break code
		    end else if (is_shift_char == 1'b1) begin
			next_state = state_shift_pressed; // shift char
		    end else begin
			next_state = state_check;
		    end
		end else begin
		    next_state = state_idle; // loop
		end
	    end

	    state_check: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		
		/*
		 * Checks what our last recorded action was for this key
		 * ('make' or 'break') -- if it was also a 'make,' we should
		 * return to idle, otherwise we'll continue sending the make
		 * out to the E100
		 */
		if (prev_key_state == 1'b1) begin
		    next_state = state_idle;
		end else begin
		    next_state = state_prevalid;                
		end
	    end

	    state_prevalid: begin
		/*
		 * store in memory that the 'make' code happened,
		 * so we can ignore repeat make codes due to typematic,
		 * and record the current 'shift' status, because
		 * we're about to send the character to the E100 with this
		 * shift status
		 */
		mem_wr_en            = 1'b1;          // 1 = 'write'
		set_prev_key_state   = 1'b1;          // 1 = 'make'
		set_prev_shift_state = shift_actual_out;
		next_state = state_valid;
	    end

	    state_valid: begin
		/*
		 * We have a valid event to send to the E100.
                 * Wait for E100 to start transaction.
		 */
		if (ps2_command == 1'b1) begin
		    next_state = state_response;
		end else begin
		    next_state = state_valid;
		end
	    end

	    state_response: begin
		ps2_response = 1'b1;
		if (ps2_command == 1'b0) begin
		    next_state = state_idle;
		end else begin
		    next_state = state_response;
		end
            end

	    state_break: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl

		/*
		 * the current byte indicates the beginning of a
		 * 'break code' (0xF0) ...thus, we must wait for
		 * the next byte, which is also part of the
		 * 'break code' and treat it accordingly
		 */
		next_state = state_break_waitnext;                                
	    end

	    state_break_waitnext: begin
		/*
		 * should store the next byte we receive:
		 */
		mem_addr_en       = 1'b1;
		lowercase_write   = 1'b1;
		uppercase_write   = 1'b1;

		if (ps2_serial_valid == 1'b0) begin
		    next_state = state_break_waitnext; // loop
		end else begin
		    if (is_shift_char == 1'b1) begin
			next_state = state_shift_released; // shift char
		    end else begin
			next_state = state_break_check;
		    end
		end
	    end

	    state_break_check: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		
		/*
		 * checks what our last recorded action was for
		 * this key ('make' or 'break') -- if it was also
		 * a 'make,' we should return to idle, otherwise
		 * we'll continue sending the make out to the E100
		 */
		if (prev_key_state == 1'b0) begin
		    next_state = state_idle;
		end else begin
		    next_state = state_break_prevalid;
		end
	    end

	    state_break_prevalid: begin
		/*
		 * store in memory that the 'break' code happened, so we can
		 * ignore repeat break codes (though they shouldn't occur) and
		 * preserve the current 'shift' status, because we're about to
		 * send the character to the E100 with this shift status
		 * (which is the status when 'make' happened)
		 */
		mem_wr_en            = 1'b1;          // 1 = 'write'
		set_prev_key_state   = 1'b0;          // 0 = 'break'
		set_prev_shift_state = prev_shift_state; // preserve
		next_state = state_valid;
	    end

	    state_extended: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		
		/*
		 * the current byte indicates the beginning of an
		 * 'extended character' (0xE0) ...since we don't handle
		 * these, we must wait for the next byte, which is also
		 * part of the extended character, and ignore it
		 */
		next_state = state_extended_waitnext;
	    end

	    state_extended_waitnext: begin
		if (ps2_serial_valid == 1'b1) begin
		    if (is_extended == 1'b1 || is_break_code == 1'b1) begin
			next_state = state_extended; // one more byte to ignore
		    end else begin
			next_state = state_extended_ignorebyte;
		    end                        
		end else begin
		    next_state = state_extended_waitnext; // loop
		end                
	    end

	    state_extended_ignorebyte: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		
		/*
		 * this is the last byte in the 'extended character'
		 * 'make code' or 'break code', it should be something
		 * other than 0xE0 or 0xF0. just ignore it, and move
		 * back to idle
		 */
		next_state = state_idle;
	    end

	    state_shift_pressed: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		shift_actual_write = 1'b1;
		shift_actual_in = 1'b1; // 1 = shift pressed
		    
		next_state = state_idle;
	    end

	    state_shift_released: begin
		ps2_serial_ack = 1'b1; // send an ack to ps2ctrl
		shift_actual_write = 1'b1;
		shift_actual_in = 1'b0; // 0 = shift NOT pressed
		    
		next_state = state_idle;                                
	    end

	endcase
    end

endmodule

module scancode2ascii(
    input wire [7:0] scan_code,
    output reg [7:0] lowercase,
    output reg [7:0] uppercase);

    parameter ASCII_SPACE = 8'd32;
    parameter ASCII_EXCLAMATION = 8'd33;
    parameter ASCII_DOUBLE_QUOTE = 8'd34;
    parameter ASCII_POUND = 8'd35;
    parameter ASCII_DOLLAR = 8'd36;
    parameter ASCII_PERCENT = 8'd37;
    parameter ASCII_AMPERSAND = 8'd38;
    parameter ASCII_SINGLE_QUOTE = 8'd39;
    parameter ASCII_L_PAREN = 8'd40;
    parameter ASCII_R_PAREN = 8'd41;
    parameter ASCII_ASTERIK = 8'd42;
    parameter ASCII_PLUS = 8'd43;
    parameter ASCII_COMMA = 8'd44;
    parameter ASCII_MINUS = 8'd45;
    parameter ASCII_PERIOD = 8'd46;
    parameter ASCII_SLASH = 8'd47;
    parameter ASCII_0 = 8'd48;
    parameter ASCII_1 = 8'd49;
    parameter ASCII_2 = 8'd50;
    parameter ASCII_3 = 8'd51;
    parameter ASCII_4 = 8'd52;
    parameter ASCII_5 = 8'd53;
    parameter ASCII_6 = 8'd54;
    parameter ASCII_7 = 8'd55;
    parameter ASCII_8 = 8'd56;
    parameter ASCII_9 = 8'd57;
    parameter ASCII_COLON = 8'd58;
    parameter ASCII_SEMICOLON = 8'd59;
    parameter ASCII_LT = 8'd60; // less than
    parameter ASCII_EQ = 8'd61; // equal
    parameter ASCII_GT = 8'd62; // greater than
    parameter ASCII_QUESTION = 8'd63;
    parameter ASCII_AT = 8'd64;
    parameter ASCII_A = 8'd65;
    parameter ASCII_B = 8'd66;
    parameter ASCII_C = 8'd67;
    parameter ASCII_D = 8'd68;
    parameter ASCII_E = 8'd69;
    parameter ASCII_F = 8'd70;
    parameter ASCII_G = 8'd71;
    parameter ASCII_H = 8'd72;
    parameter ASCII_I = 8'd73;
    parameter ASCII_J = 8'd74;
    parameter ASCII_K = 8'd75;
    parameter ASCII_L = 8'd76;
    parameter ASCII_M = 8'd77;
    parameter ASCII_N = 8'd78;
    parameter ASCII_O = 8'd79;
    parameter ASCII_P = 8'd80;
    parameter ASCII_Q = 8'd81;
    parameter ASCII_R = 8'd82;
    parameter ASCII_S = 8'd83;
    parameter ASCII_T = 8'd84;
    parameter ASCII_U = 8'd85;
    parameter ASCII_V = 8'd86;
    parameter ASCII_W = 8'd87;
    parameter ASCII_X = 8'd88;
    parameter ASCII_Y = 8'd89;
    parameter ASCII_Z = 8'd90;
    parameter ASCII_L_BRACKET = 8'd91;
    parameter ASCII_BACKSLASH = 8'd92;
    parameter ASCII_R_BRACKET = 8'd93;
    parameter ASCII_CARET = 8'd94;
    parameter ASCII_UNDERSCORE = 8'd95;
    parameter ASCII_TICK = 8'd96;
    parameter ASCII_LOWER_A = 8'd97;
    parameter ASCII_LOWER_B = 8'd98;
    parameter ASCII_LOWER_C = 8'd99;
    parameter ASCII_LOWER_D = 8'd100;
    parameter ASCII_LOWER_E = 8'd101;
    parameter ASCII_LOWER_F = 8'd102;
    parameter ASCII_LOWER_G = 8'd103;
    parameter ASCII_LOWER_H = 8'd104;
    parameter ASCII_LOWER_I = 8'd105;
    parameter ASCII_LOWER_J = 8'd106;
    parameter ASCII_LOWER_K = 8'd107;
    parameter ASCII_LOWER_L = 8'd108;
    parameter ASCII_LOWER_M = 8'd109;
    parameter ASCII_LOWER_N = 8'd110;
    parameter ASCII_LOWER_O = 8'd111;
    parameter ASCII_LOWER_P = 8'd112;
    parameter ASCII_LOWER_Q = 8'd113;
    parameter ASCII_LOWER_R = 8'd114;
    parameter ASCII_LOWER_S = 8'd115;
    parameter ASCII_LOWER_T = 8'd116;
    parameter ASCII_LOWER_U = 8'd117;
    parameter ASCII_LOWER_V = 8'd118;
    parameter ASCII_LOWER_W = 8'd119;
    parameter ASCII_LOWER_X = 8'd120;
    parameter ASCII_LOWER_Y = 8'd121;
    parameter ASCII_LOWER_Z = 8'd122;
    parameter ASCII_L_CURLY = 8'd123;
    parameter ASCII_BAR = 8'd124;
    parameter ASCII_R_CURLY = 8'd125;
    parameter ASCII_TILDE = 8'd126;

    parameter ASCII_NUL = 8'd0; // null
    parameter ASCII_BS = 8'd8;  // backspace
    parameter ASCII_TAB = 8'd9;
    parameter ASCII_LF = 8'd10; // line feed
    parameter ASCII_CR = 8'd13; // carriage return
    parameter ASCII_ESC = 8'd27; // escape
    parameter ASCII_DEL = 8'd127; // delete
    parameter ASCII_UNKNOWN = 8'd254;


    // scan codes (set 2), obtained values from:
    // http://www.computer-engineering.org/ps2keyboard/scancodes2.html

    always @* begin
        case (scan_code)
	    8'h29: begin
		uppercase = ASCII_SPACE;		
		lowercase = ASCII_SPACE;		        
	    end
	    8'h45: begin
		uppercase = ASCII_R_PAREN;		
		lowercase = ASCII_0;		 
	    end
	    8'h16: begin
		uppercase = ASCII_EXCLAMATION;		
		lowercase = ASCII_1;		 
	    end
	    8'h1E: begin
		uppercase = ASCII_AT;		
		lowercase = ASCII_2;		 
	    end
	    8'h26: begin
		uppercase = ASCII_POUND;		
		lowercase = ASCII_3;		 
	    end
	    8'h25: begin
		uppercase = ASCII_DOLLAR;		
		lowercase = ASCII_4;		
	    end
	    8'h2E: begin
		uppercase = ASCII_PERCENT;		
		lowercase = ASCII_5;		 
	    end
	    8'h36: begin
		uppercase = ASCII_CARET;		
		lowercase = ASCII_6;		
	    end
	    8'h3D: begin
		uppercase = ASCII_AMPERSAND;		
		lowercase = ASCII_7;		
	    end
	    8'h3E: begin
		uppercase = ASCII_ASTERIK;		
		lowercase = ASCII_8;		
	    end
	    8'h46: begin
		uppercase = ASCII_L_PAREN;		 
		lowercase = ASCII_9;		        
	    end
	    8'h1C: begin
		uppercase = ASCII_A;		
		lowercase = ASCII_LOWER_A;		 
	    end
	    8'h32: begin
		uppercase = ASCII_B;		
		lowercase = ASCII_LOWER_B;		 
	    end
	    8'h21: begin
		uppercase = ASCII_C;		
		lowercase = ASCII_LOWER_C;		 
	    end
	    8'h23: begin
		uppercase = ASCII_D;		 
		lowercase = ASCII_LOWER_D;		 
	    end
	    8'h24: begin
		uppercase = ASCII_E;		 
		lowercase = ASCII_LOWER_E;		 
	    end
	    8'h2B: begin
		uppercase = ASCII_F;		 
		lowercase = ASCII_LOWER_F;		 
	    end
	    8'h34: begin
		uppercase = ASCII_G;		 
		lowercase = ASCII_LOWER_G;		 
	    end
	    8'h33: begin
		uppercase = ASCII_H;		 
		lowercase = ASCII_LOWER_H;		 
	    end
	    8'h43: begin
		uppercase = ASCII_I;		 
		lowercase = ASCII_LOWER_I;		 
	    end
	    8'h3B: begin
		uppercase = ASCII_J;		 
		lowercase = ASCII_LOWER_J;		 
	    end
	    8'h42: begin
		uppercase = ASCII_K;		 
		lowercase = ASCII_LOWER_K;		
	    end
	    8'h4B: begin
		uppercase = ASCII_L;		 
		lowercase = ASCII_LOWER_L;		
	    end
	    8'h3A: begin
		uppercase = ASCII_M;		 
		lowercase = ASCII_LOWER_M;		
	    end
	    8'h31: begin
		uppercase = ASCII_N;		
		lowercase = ASCII_LOWER_N;		
	    end
	    8'h44: begin
		uppercase = ASCII_O;		
		lowercase = ASCII_LOWER_O;		
	    end
	    8'h4D: begin
		uppercase = ASCII_P;		
		lowercase = ASCII_LOWER_P;		
	    end
	    8'h15: begin
		uppercase = ASCII_Q;		
		lowercase = ASCII_LOWER_Q;		
	    end
	    8'h2D: begin
		uppercase = ASCII_R;		
		lowercase = ASCII_LOWER_R;		
	    end
	    8'h1B: begin
		uppercase = ASCII_S;		
		lowercase = ASCII_LOWER_S;		
	    end
	    8'h2C: begin
		uppercase = ASCII_T;		
		lowercase = ASCII_LOWER_T;		
	    end
	    8'h3C: begin
		uppercase = ASCII_U;		
		lowercase = ASCII_LOWER_U;		
	    end
	    8'h2A: begin
		uppercase = ASCII_V;		
		lowercase = ASCII_LOWER_V;		
	    end
	    8'h1D: begin
		uppercase = ASCII_W;		
		lowercase = ASCII_LOWER_W;		
	    end
	    8'h22: begin
		uppercase = ASCII_X;		
		lowercase = ASCII_LOWER_X;		
	    end
	    8'h35: begin
		uppercase = ASCII_Y;		
		lowercase = ASCII_LOWER_Y;		
	    end
	    8'h1A: begin
		uppercase = ASCII_Z;		
		lowercase = ASCII_LOWER_Z;		
	    end
	    8'h0E: begin
		uppercase = ASCII_TILDE;		
		lowercase = ASCII_TICK;		
	    end
	    8'h4E: begin
		uppercase = ASCII_UNDERSCORE;		
		lowercase = ASCII_MINUS;		
	    end
	    8'h55: begin
		uppercase = ASCII_PLUS;		
		lowercase = ASCII_EQ;		
	    end
	    8'h5D: begin
		uppercase = ASCII_BAR;		
		lowercase = ASCII_BACKSLASH;		
	    end
	    8'h66: begin
		uppercase = ASCII_BS;		
		lowercase = ASCII_BS;		
	    end
	    8'h0D: begin
		uppercase = ASCII_TAB;		
		lowercase = ASCII_TAB;		
	    end
	    8'h58: begin
		//caps lock: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h12: begin
		//left shift: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h14: begin
		//left ctrl: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h11: begin
		//left alt: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h59: begin
		//right shift: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h5A: begin
		//enter: represent lowercase as LF, uppercase as CR
		uppercase = ASCII_CR;
		lowercase = ASCII_LF;
	    end
	    8'h76: begin
		uppercase = ASCII_ESC;
		lowercase = ASCII_ESC;
	    end
	    8'h05: begin
		//F1: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h06: begin
		//F2: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h04: begin
		//F3: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h0C: begin
		//F4: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h03: begin
		//F5: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h0B: begin
		//F6: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h83: begin
		//F7: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h0A: begin
		//F8: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h01: begin
		//F9: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h09: begin
		//F10: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h78: begin
		//F11: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h07: begin
		//F12: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h7E: begin
		//scroll lock: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h54: begin
		uppercase = ASCII_L_CURLY;		
		lowercase = ASCII_L_BRACKET;		
	    end
	    8'h77: begin
		//num lock: ignore it
		uppercase = ASCII_NUL;
		lowercase = ASCII_NUL;
	    end
	    8'h7C: begin
		//keypad asterik
		uppercase = ASCII_ASTERIK;
		lowercase = ASCII_ASTERIK;
	    end
	    8'h7B: begin
		//keypad minus
		uppercase = ASCII_MINUS;
		lowercase = ASCII_MINUS;
	    end
	    8'h79: begin
		//keypad plus
		uppercase = ASCII_PLUS;
		lowercase = ASCII_PLUS;
	    end
	    8'h71: begin
		//keypad period
		uppercase = ASCII_PERIOD;
		lowercase = ASCII_PERIOD;
	    end
	    8'h70: begin
		//keypad 0
		uppercase = ASCII_0;
		lowercase = ASCII_0;
	    end
	    8'h69: begin
		//keypad 1
		uppercase = ASCII_1;
		lowercase = ASCII_1;
	    end
	    8'h72: begin
		//keypad 2
		uppercase = ASCII_2;
		lowercase = ASCII_2;
	    end
	    8'h7A: begin
		//keypad 3
		uppercase = ASCII_3;
		lowercase = ASCII_3;
	    end
	    8'h6B: begin
		//keypad 4
		uppercase = ASCII_4;
		lowercase = ASCII_4;
	    end
	    8'h73: begin
		//keypad 5
		uppercase = ASCII_5;
		lowercase = ASCII_5;
	    end
	    8'h74: begin
		//keypad 6
		uppercase = ASCII_6;
		lowercase = ASCII_6;
	    end
	    8'h6C: begin
		//keypad 7
		uppercase = ASCII_7;
		lowercase = ASCII_7;
	    end
	    8'h75: begin
		//keypad 8
		uppercase = ASCII_8;
		lowercase = ASCII_8;
	    end
	    8'h7D: begin
		//keypad 9
		uppercase = ASCII_9;
		lowercase = ASCII_9;
	    end
	    8'h5B: begin
		uppercase = ASCII_R_CURLY;		
		lowercase = ASCII_R_BRACKET;		
	    end
	    8'h4C: begin
		uppercase = ASCII_COLON;		
		lowercase = ASCII_SEMICOLON;		
	    end
	    8'h52: begin
		uppercase = ASCII_DOUBLE_QUOTE;		
		lowercase = ASCII_SINGLE_QUOTE;		
	    end
	    8'h41: begin
		uppercase = ASCII_LT;		
		lowercase = ASCII_COMMA;		
	    end
	    8'h49: begin
		uppercase = ASCII_GT;		
		lowercase = ASCII_PERIOD;		
	    end
	    8'h4A: begin
		uppercase = ASCII_QUESTION;
		lowercase = ASCII_SLASH;
	    end
	    default: begin
		uppercase = ASCII_UNKNOWN;
		lowercase = ASCII_UNKNOWN;
	    end

	endcase
    end
endmodule
