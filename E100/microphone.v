/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Microphone controller for Wolfson WM8731 codec.
 */
module microphone(
    input wire clock_25m,
    input wire clock_8_1k,
    input wire clock_valid,
    input wire reset_25m,
    input wire codec_initialized,
    input wire microphone_command,
    output reg microphone_response,
    output reg [31:0] microphone_sample,
    input wire AUD_BCLK,
    output reg AUD_ADCLRCK,
    input wire AUD_ADCDAT);

    reg sample_avail;		// 1 ==> cpu hasn't yet seen the sample
    reg sample_produce;		// microphone is producing a sample
    reg sample_consume;		// cpu is consuming a sample

    reg [5:0] count;		// # of AUD_BCLK rising edges since first
    				// sample bit.  Saturating counter.
    reg count_clear;

    reg adclrck_toggle;

    wire clock_8_1k_sync;
    reg clock_8_1k_sync_last;
    reg clock_8_1k_sync_last_write;

    reg [23:0] shift_reg;

    reg [1:0] cpu_state;
    reg [1:0] next_cpu_state;

    reg [2:0] mic_state;
    reg [2:0] next_mic_state;

    reg next_microphone_response;

    synchronizer #(.WIDTH(1)) u1 (clock_25m, clock_8_1k, clock_8_1k_sync);

    always @(posedge clock_25m) begin
	if (clock_valid == 1'b1) begin
	    if (reset_25m == 1'b1) begin
		cpu_state <= cpu_state_reset;
		mic_state <= mic_state_reset;
	        AUD_ADCLRCK <= 1'b0;
		sample_avail <= 1'b0;
		shift_reg <= 24'h0;
		count <= 6'h3f;
	    end else begin
		cpu_state <= next_cpu_state;
		mic_state <= next_mic_state;

		if (adclrck_toggle == 1'b1) begin
		    AUD_ADCLRCK <= ~AUD_ADCLRCK;
		end

		if (clock_8_1k_sync_last_write == 1'b1) begin
		    clock_8_1k_sync_last <= clock_8_1k_sync;
		end

		if (sample_produce == 1'b1) begin
		    /*
		     * It's not clear if sample_produce or sample_consume
		     * should have priority.  If a sample is produced and
		     * consumed at the same time, whether or not there should
		     * be a sample available afterwards depends on if the
		     * cpu got the old sample or the new sample.
		     */
		    sample_avail <= 1'b1;
		end else if (sample_consume == 1'b1) begin
		    sample_avail <= 1'b0;
		end

		if (sample_produce == 1'b1) begin
		    microphone_sample[31:8] <= shift_reg;
		    microphone_sample[7:0] <= 8'h0; // pad bits 7-0 with zeroes
		end

		/*
		 * Shift register captures data from ADCDAT for the specified
		 * number of cycles after a ADCLRC pulse.  Only capture
		 * sample on rising edge of AUD_BCLK.
		 */
		if (AUD_BCLK == 1'b0 && count < 6'h18) begin
		    shift_reg[23:1] <= shift_reg[22:0];
		    shift_reg[0] <= AUD_ADCDAT;
		end

		/*
		 * Saturating counter.  Counts only on rising edge of AUD_BCLK
		 */
		if (count_clear == 1'b1) begin
		    count <= 6'h0;
		end else if (AUD_BCLK == 1'b0 && count != 6'h3f) begin
		    count <= count + 6'h1;
		end

		/*
		 * Register microphone_response to prevent glitches.
		 */
		microphone_response <= next_microphone_response;
	    end
	end
    end

    parameter cpu_state_reset =    2'h0;
    parameter cpu_state_idle =     2'h1;
    parameter cpu_state_response = 2'h2;
    parameter cpu_state_consume =  2'h3;

    /*
     * State machine for cpu side.  Send samples to the cpu.
     */
    always @* begin
	/*
	 * Default values for control signals
	 */
	next_microphone_response = 1'b0;
	sample_consume = 1'b0;
	next_cpu_state = cpu_state_reset;

	case (cpu_state)

	    cpu_state_reset: begin
                next_cpu_state = cpu_state_idle;
	    end

            /*
             * Wait for codec_initialized before sending samples
             * to CPU.
             */
	    cpu_state_idle: begin
		if (microphone_command == 1'b0 || sample_avail == 1'b0 ||
                        codec_initialized == 1'b0) begin
		    next_cpu_state = cpu_state_idle;
		end else begin
		    next_cpu_state = cpu_state_response;
		end
	    end

	    cpu_state_response: begin
		next_microphone_response = 1'b1;
		if (microphone_command == 1'b0) begin
		    next_cpu_state = cpu_state_consume;
		end else begin
		    next_cpu_state = cpu_state_response;
		end
	    end

	    cpu_state_consume: begin
		sample_consume = 1'b1;
		next_cpu_state = cpu_state_idle;
	    end

	endcase
    end

    parameter mic_state_reset =      3'h0;
    parameter mic_state_receive0 =   3'h1;
    parameter mic_state_receive1 =   3'h2;
    parameter mic_state_samplesave = 3'h3;
    parameter mic_state_pulse0 =     3'h4;
    parameter mic_state_pulse1 =     3'h5;

    /*
     * State machine for getting input from microphone.
     * Use DSP mode (msb available on the 2nd rising edge of AUD_BCLK after
     * rising edge of AUD_ADCLRCK).
     *
     * AUD_ADCLRCK should change on falling edge of AUD_BCLK.
     */
    always @* begin
	/*
	 * Default values for control signals
	 */
	sample_produce = 1'b0;
	count_clear = 1'b0;
	clock_8_1k_sync_last_write = 1'b0;
	adclrck_toggle = 1'b0;
	next_mic_state = mic_state_reset;

	case (mic_state)

	    mic_state_reset: begin
		if (AUD_BCLK == 1'b0) begin
		    next_mic_state = mic_state_receive1;
		end else begin
		    next_mic_state = mic_state_receive0;
		end
	    end

	    mic_state_receive0: begin		// AUD_BCLK=0
		/*
		 * Receive sample from microphone.
		 */
		clock_8_1k_sync_last_write = 1'b1; // I only check this every
						   // other cycle, so I should
						   // only update it every other
						   // cycle

		if (clock_8_1k_sync_last == 1'b0 && clock_8_1k_sync == 1'b1) begin
		    /*
		     * Rising edge of clock_8_1k_sync, so save current sample.
		     */
		    next_mic_state = mic_state_samplesave;
		end else begin
		    /*
		     * Not a rising edge of clock_8_1k_sync, so keep receiving.
		     */
		    next_mic_state = mic_state_receive1;
		end
	    end

	    mic_state_receive1: begin		// AUD_BCLK=1
		/*
		 * Receive sample from microphone.
		 */
		next_mic_state = mic_state_receive0;
	    end

	    mic_state_samplesave: begin		// AUD_BCLK=1
		/*
		 * Save last sample.  This may change data that has been published
		 * to the CPU as valid (there's no way to avoid this, since the
		 * protocol allows the CPU to look at the microphone data without
		 * the device knowing).
		 * Raise AUD_ADCLRCK (pulse starts on next falling edge of
		 * AUD_BCLK).
		 */
		sample_produce = 1'b1;
		adclrck_toggle = 1'b1;
		next_mic_state = mic_state_pulse0;
	    end

	    mic_state_pulse0: begin		// AUD_BCLK=0
		next_mic_state = mic_state_pulse1;
	    end

	    mic_state_pulse1: begin		// AUD_BCLK=1
		count_clear = 1'b1;
		adclrck_toggle = 1'b1;
		next_mic_state = mic_state_receive0;
	    end

	endcase
    end

endmodule
