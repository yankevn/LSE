/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Controller for configuring I2C devices:
 *     Wolfson WM8731 codec (used by speaker and microphone controllers)
 *     Analog Devices ADV7180 video decoder (used by camera controller)
 */
module i2c_config(
    input wire osc_50,
    input wire clock_8_1k,
    input wire clock_valid,
    input wire reset_50m,
    inout reg I2C_SDAT,
    output reg I2C_SCLK,
    output reg i2c_audio_done,
    output reg i2c_video_done);

    reg sclk;
    reg sclk_toggle;
    reg sdat_read;			// 1 ==> I2C slave drives I2C_SDAT
    reg sdat_in;
    reg sdat_out;
    reg [1:0] sdat_out_write;		// which data to write into sdat_out
    					// (if any).
					// 0 ==> leave sdat_out unchanged
					// 1 ==> load shift_reg[23]
					// 2 ==> load 0
					// 3 ==> load 1

    reg [23:0] shift_reg;
    reg shift_reg_write;
    reg shift_reg_shift;
    reg [4:0] shift_count;		// counts how many times shift register
    					// has been shifted
    reg [4:0] item;			// which item we're on
    reg item_incr;
    reg i2c_audio_done_set;
    reg i2c_video_done_set;

    wire clock_8_1k_sync;
    reg clock_8_1k_sync_last;

    reg [4:0] state;
    reg [4:0] next_state;

    synchronizer #(.WIDTH(1)) u1 (osc_50, clock_8_1k, clock_8_1k_sync);

    always @(posedge osc_50) begin
	clock_8_1k_sync_last <= clock_8_1k_sync;
    end

    always @* begin
        /*
         * Set I2C_SDAT.
         */
        if (sdat_read == 1'b1) begin
	    /*
	     * Read input from I2C slave.
	     */
	    I2C_SDAT = 1'bz;
	end else begin
	    /*
	     * Write data to I2C slave.
	     */
            if (sdat_out == 1'b1) begin
                /*
                 * Let pullup resistor set I2C_SDAT to 1 (I2C uses
                 * open-drain lines).
                 */
                I2C_SDAT = 1'bz;
            end else begin
                I2C_SDAT = 1'b0;
            end
	end

        /*
         * Set I2C_SCLK.
         */
        if (sclk == 1'b1) begin
            /*
             * Let pullup resistor set I2C_SCLK to 1 (I2C uses
             * open-drain lines).
             */
            I2C_SCLK = 1'bz;
        end else begin
            I2C_SCLK = 1'b0;
        end
    end

    always @(posedge osc_50) begin
        /*
	 * Only advance state on 8 KHz clock.  Could trigger on 8 KHz clock
	 * directly, but it's safer to use osc_50 because it's synchronized
	 * to the system clock.
	 */
	if (clock_valid == 1'b1 &&
	        clock_8_1k_sync_last == 1'b0 && clock_8_1k_sync == 1'b1) begin
	    if (reset_50m == 1'b1) begin
	        sclk <= 1'b0;
		sdat_out <= 1'b0;
		item <= 5'h0;
		state <= state_reset;
                i2c_audio_done <= 1'b0;
                i2c_video_done <= 1'b0;
	    end else begin

		sdat_in <= I2C_SDAT;	// register inputs from I2C slave to
					// protect against glitching

		if (sclk_toggle == 1'b1) begin
		    sclk <= ~sclk;
		end

		if (sdat_out_write == 2'h1) begin
		    sdat_out <= shift_reg[23];
		end if (sdat_out_write == 2'h2) begin
		    sdat_out <= 1'b0;
		end if (sdat_out_write == 2'h3) begin
		    sdat_out <= 1'b1;
		end

                if (i2c_audio_done_set == 1'b1) begin
                    i2c_audio_done <= 1'b1;
                end
                if (i2c_video_done_set == 1'b1) begin
                    i2c_video_done <= 1'b1;
                end

		/*
		 * Load shift register with data to send to I2C slave.
		 * Bits 23-16 are the 7-bit device address (0011010), followed
		 * by r/!w bit (0).
		 */
		if (shift_reg_write == 1'b1) begin
		    case (item)
                        /*
                         * Audio configuration
                         * Bits 15-9 are the register address.
                         * Bits 8-0 are the data.
                         */
			5'h00: begin
			    // reset codec
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0001111;
			    shift_reg[8:0] <= 9'b000000000;
			end

			5'h01: begin
			    // power up
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0000110;
			    shift_reg[8:0] <= 9'b000000000;
			end

			5'h02: begin
			    // output DAC; input microphone
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0000100;
			    shift_reg[8:0] <= 9'b000010100;

			    // ??? uncomment this to boost microphone
			    // shift_reg[8:0] <= 9'b000010101;
			end

			5'h03: begin
			    // disable soft mute
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0000101;
			    shift_reg[8:0] <= 9'b000000000;
			end

			5'h04: begin
			    // set sampling rate
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0001000;
			    shift_reg[8:0] <= 9'b000001100;
			end

			5'h05: begin
			    // set digital audio interface format
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0000111;
			    shift_reg[8:0] <= 9'b000011011;
			end

			5'h06: begin
			    // activate audio
			    shift_reg[23:16] <= 8'b00110100;
			    shift_reg[15:9] <= 7'b0001001;
			    shift_reg[8:0] <= 9'b000000001;
			end

                        /*
                         * Video configuration.  Command sequence comes
                         * from the DE2-115 demonstration project
			 * (DE2_115_TV/I2C_AV_Config.v)
                         * Bits 15-8 are the register address.
                         * Bits 7-0 are the data.
                         */
			5'h07: begin
                            // input control
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0000; // ??? maybe should be 0050 (NTSC M)
			end
			5'h08: begin
                            // ADC switch 1
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'hc301;
			end
			5'h09: begin
                            // ADC switch 2
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'hc480;
			end
			5'h0a: begin
                            // extended output control
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0457; // ??? maybe bit2 should be 0 (to match old DE2_TV)
			end
			5'h0b: begin
                            // shaping filter control 1
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h1741;
			end
			5'h0c: begin
                            // VS/FIELD pin control
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h5801;
			end
			5'h0d: begin
                            // manual window control
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h3da2;
			end
			5'h0e: begin
                            // polarity
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h37a0;
			end
			5'h0f: begin
                            // BLM optimization (p. 105)
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h3e6a;
			end
			5'h10: begin
                            // BGB optimization (p. 105)
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h3fa0;
			end
			5'h11: begin
                            // ADI control 1
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0e80; // ??? bit 7 is reserved and should be 0
			end
			5'h12: begin
                            // ADC configuration (p. 105)
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h5581;
			end

			// ??? DE2_115_TV sets polarity register again here

			5'h13: begin
                            // contrast
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0880;
			end
			5'h14: begin
                            // brightness
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0a18;
			end
			5'h15: begin
                            // AGC mode control
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h2c8e;
			end
			5'h16: begin
                            // chroma gain control 1
			    // ??? this shouldn't be needed, since we're in
			    // auto mode
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h2df8;
			end
			5'h17: begin
                            // chroma gain control 2
			    // ??? this shouldn't be needed, since we're in
			    // auto mode
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h2ece;
			end

			5'h18: begin
                            // luma gain control 1
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h2ff4;
			end
			5'h19: begin
                            // luma gain control 2
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h30b2;
			end
			5'h1a: begin
                            // ADI control 1
			    shift_reg[23:16] <= 8'b01000000;
			    shift_reg[15:0] <= 16'h0e00;
			end
		    endcase

		    shift_count <= 5'h0;

		end else if (shift_reg_shift == 1'b1) begin
		    shift_reg[23:1] <= shift_reg[22:0];
		    shift_reg[0] <= 1'b0;
		    shift_count <= shift_count + 5'h1;
		end

                if (item_incr == 1'b1) begin
		    item <= item + 5'h1;
                end

		state <= next_state;
	    end
	end
    end

    parameter state_reset =       4'h00;
    parameter state_start1 =      4'h01;
    parameter state_start2 =      4'h02;
    parameter state_start3 =      4'h03;
    parameter state_data1 =       4'h04;
    parameter state_data2 =       4'h05;
    parameter state_data3 =       4'h06;
    parameter state_data_ack1 =   4'h07;
    parameter state_data_ack2 =   4'h08;
    parameter state_stop1 =       4'h09;
    parameter state_stop1_error = 4'h0a;
    parameter state_stop2 =       4'h0b;
    parameter state_stop3 =       4'h0c;
    parameter state_audio_done =  4'h0d;
    parameter state_video_done =  4'h0e;

    always @* begin
	/*
	 * Default values for control signals
	 */
	sclk_toggle = 1'b0;
	sdat_read = 1'b0;
	sdat_out_write = 2'h0;
	shift_reg_write = 1'b0;
	shift_reg_shift = 1'b0;
	i2c_audio_done_set = 1'b0;
	i2c_video_done_set = 1'b0;
        item_incr = 1'b0;
	next_state = state_reset;

	case (state)

	    state_reset: begin
		next_state = state_start1;
	    end

	    /*
	     * Send a command (start condition, data/ack, stop condition).
	     */
	    state_start1: begin				// SCLK=0
		/*
		 * Load shift register with the current item.
		 *
		 * Start condition.  sdat 1->0 while sclk=1
		 * sdat_out and sclk are registered, so these changes don't occur
		 * until the beginning of the next state.
		 */
		shift_reg_write = 1'b1;
		sdat_out_write = 2'h3;
		sclk_toggle = 1'b1;
		next_state = state_start2;
	    end

	    state_start2: begin				// SCLK=1
		sdat_out_write = 2'h2;
		next_state = state_start3;
	    end

	    state_start3: begin				// SCLK=1
		sclk_toggle = 1'b1;
		next_state = state_data1;
	    end

	    state_data1: begin				// SCLK=0
		sdat_out_write = 2'h1;
		shift_reg_shift = 1'b1;
		next_state = state_data2;
	    end

	    state_data2: begin				// SCLK=0
		sclk_toggle = 1'b1;
		next_state = state_data3;
	    end

	    state_data3: begin				// SCLK=1
		sclk_toggle = 1'b1;
		/*
		 * Check for ack after each 8 bits
		 */
		if (shift_count[2:0] == 3'h0) begin
		    next_state = state_data_ack1;
		end else begin
		    next_state = state_data1;
		end
	    end

	    state_data_ack1: begin			// SCLK=0
		sdat_read = 1'b1;
		sclk_toggle = 1'b1;
		next_state = state_data_ack2;
	    end

            /*
             * Get the ack bit.  If 0, continue.  If 1, stop the transaction
             * and re-send the command.
             */
	    state_data_ack2: begin			// SCLK=1
		sdat_read = 1'b1;
		sclk_toggle = 1'b1;

                if (sdat_in == 1'b0) begin
                    /*
                     * Ack received.
                     */
                    if (shift_count == 5'd24) begin
                        next_state = state_stop1;
                    end else begin
                        next_state = state_data1;
                    end
                end else begin
                    /*
                     * No ack.  Stop the transaction and re-send the command.
                     */
                    next_state = state_stop1_error;
                end
	    end

	    state_stop1: begin				// SCLK=0
		/*
		 * Stop condition.  sdat 0->1 while sclk=1
                 * Increment item.
		 */
		sdat_out_write = 2'h2;
		sclk_toggle = 1'b1;
                item_incr = 1'b1;
		next_state = state_stop2;
	    end

	    state_stop1_error: begin			// SCLK=0
		/*
		 * Stop condition.  sdat 0->1 while sclk=1
                 * Don't increment item (so the command gets resent).
		 */
		sdat_out_write = 2'h2;
		sclk_toggle = 1'b1;
		next_state = state_stop2;
	    end

	    state_stop2: begin				// SCLK=1
		sdat_out_write = 2'h3;
		next_state = state_stop3;
	    end

	    state_stop3: begin				// SCLK=1
		sclk_toggle = 1'b1;
		if (item == 5'h07) begin
		    next_state = state_audio_done;
		end else if (item == 5'h1b) begin
		    next_state = state_video_done;
		end else begin
		    next_state = state_start1;
		end
	    end

	    state_audio_done: begin
                i2c_audio_done_set = 1'b1;
                next_state = state_start1;
	    end

	    state_video_done: begin
                i2c_video_done_set = 1'b1;
                next_state = state_video_done;
	    end

	endcase
    end

endmodule
