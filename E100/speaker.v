/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Speaker controller for Wolfson WM8731 codec.
 */
module speaker(
    input wire clock_25m,
    input wire clock_8_1k,
    input wire clock_valid,
    input wire reset_25m,
    input wire codec_initialized,
    input wire speaker_command,
    output reg speaker_response,
    input wire [31:0] speaker_sample,
    output reg AUD_XCK,
    output reg AUD_BCLK,
    output reg AUD_DACLRCK,
    output reg AUD_DACDAT);

    reg [23:0] current_sample;  // next sample to be played
    reg current_sample_write;

    reg current_sample_played;
    reg current_sample_played_set;

    reg daclrck_toggle;

    wire clock_8_1k_sync;
    reg clock_8_1k_sync_last;
    reg clock_8_1k_sync_last_write;

    reg [23:0] shift_reg;       // shift register (contains the sample being
                                // played)
    reg shift_reg_write;
    reg shift_reg_shift;

    reg [1:0] cpu_state;
    reg [1:0] next_cpu_state;

    reg [2:0] play_state;
    reg [2:0] next_play_state;

    reg next_speaker_response;

    synchronizer #(.WIDTH(1)) u1 (clock_25m, clock_8_1k, clock_8_1k_sync);

    always @(posedge clock_25m) begin
        if (clock_valid == 1'b1) begin
            if (reset_25m == 1'b1) begin
                AUD_BCLK <= 1'b0;
                AUD_DACLRCK <= 1'b0;
                current_sample <= 24'h0;
                current_sample_played <= 1'b1;
                cpu_state <= cpu_state_reset;
                play_state <= play_state_reset;
            end else begin
                /*
                 * Could use clock_12_5m, but this is tightly synchronized (by
                 * pll) with clock_25m, so it might be dangerous to look at it
                 * at posedge clock_25m.
                 */
                AUD_BCLK <= ~AUD_BCLK;

                if (daclrck_toggle == 1'b1) begin
                    AUD_DACLRCK <= ~AUD_DACLRCK;
                end

                cpu_state <= next_cpu_state;
                play_state <= next_play_state;

                if (clock_8_1k_sync_last_write == 1'b1) begin
                    clock_8_1k_sync_last <= clock_8_1k_sync;
                end

                if (shift_reg_write == 1'b1) begin
                    shift_reg <= current_sample;

		    // Without new samples from the E100, cause current_sample
		    // to decay toward 0 (over a maximum interval of about
		    // .5 second).  Without this, the speaker could constantly
		    // play a large value (which should be silent, but actually
		    // creates a quiet, high-pitched whine).  current_sample is a
		    // signed value, so decay toward 0xffffff for negative numbers.
		    if (current_sample[23] == 1'b0) begin
			if (current_sample[22:11] != 12'h0) begin
			    current_sample[22:11] <= current_sample[22:11] - 12'h1;
			end
		    end else begin
			if (current_sample[22:11] != 12'hfff) begin
			    current_sample[22:11] <= current_sample[22:11] + 12'h1;
			end
		    end
		    current_sample[10:0] <= {11{current_sample[23]}};

                end else if (shift_reg_shift == 1'b1) begin
                    /*
                     * Wraparound shift register, so the same sample gets
                     * sent to the left and right channels.
                     */
                    shift_reg[23:1] <= shift_reg[22:0];
                    shift_reg[0] <= shift_reg[23];
                end

                if (current_sample_write == 1'b1) begin
                    current_sample <= speaker_sample[31:8];	// discard bits 7-0
                    current_sample_played <= 1'b0;
                end else if (current_sample_played_set == 1'b1) begin
                    current_sample_played <= 1'b1;
                end

                /*
                 * Register speaker_response to prevent glitches.
                 */
                speaker_response <= next_speaker_response;
            end
        end
    end

    parameter cpu_state_reset =    2'h0;
    parameter cpu_state_idle =     2'h1;
    parameter cpu_state_add =      2'h2;
    parameter cpu_state_response = 2'h3;

    /*
     * State machine for cpu side.  Receive samples from the cpu.
     */
    always @* begin
        /*
         * Default values for control signals
         */
        next_speaker_response = 1'b0;
        current_sample_write = 1'b0;
        next_cpu_state = cpu_state_reset;

        case (cpu_state)

            cpu_state_reset: begin
                next_cpu_state = cpu_state_idle;
            end

            cpu_state_idle: begin
                /*
                 * Wait for codec_initialized before accepting samples
                 * from CPU.
                 */
                if (speaker_command == 1'b0 || codec_initialized == 1'b0) begin
                    next_cpu_state = cpu_state_idle;
                end else if (current_sample_played == 1'b1) begin
                    /*
                     * Current sample has been played, so CPU is allowed to add
                     * a new sample.
                     */
                    next_cpu_state = cpu_state_add;
                end else begin
                    /*
                     * Wait for current sample to be played.
                     */
                    next_cpu_state = cpu_state_idle;
                end
            end

            cpu_state_add: begin
                /*
                 * Add sample.
                 */
                current_sample_write = 1'b1;
                next_cpu_state = cpu_state_response;
            end

            cpu_state_response: begin
                next_speaker_response = 1'b1;
                if (speaker_command == 1'b1) begin
                    next_cpu_state = cpu_state_response;
                end else begin
                    next_cpu_state = cpu_state_idle;
                end
            end

        endcase
    end

    parameter play_state_reset =        3'h0;
    parameter play_state_play0 =        3'h1;
    parameter play_state_play1 =        3'h2;
    parameter play_state_shiftregload = 3'h3;
    parameter play_state_pulse0 =       3'h4;
    parameter play_state_pulse1 =       3'h5;

    /*
     * State machine for playing samples on the speaker.
     * Use DSP mode (msb available on the 2nd rising edge of AUD_BCLK after
     * rising edge of AUD_DACLRCK).
     *
     * AUD_DACLRCK and AUD_DACDAT should change on falling edge of AUD_BCLK.
     */
    always @* begin
        /*
         * Default values for control signals
         */
        shift_reg_write = 1'b0;
        shift_reg_shift = 1'b0;
        current_sample_played_set = 1'b0;
        clock_8_1k_sync_last_write = 1'b0;
        daclrck_toggle = 1'b0;
        AUD_DACDAT = shift_reg[23];
        AUD_XCK = AUD_BCLK;
        next_play_state = play_state_reset;

        case (play_state)

            /*
             * Must play samples during codec initialization;
             * if I keep the playing state machine in reset during codec
             * initialization, too much time elapses between finishing
             * codec initialization and playing samples and the speaker
             * doesn't work (this may be because I don't send AUD_BCLK
             * or AUD_XCK during reset).
             */
            play_state_reset: begin
                if (AUD_BCLK == 1'b0) begin
                    next_play_state = play_state_play1;
                end else begin
                    next_play_state = play_state_play0;
                end
            end

            play_state_play0: begin // AUD_BCLK=0
                clock_8_1k_sync_last_write = 1'b1;  // I only check this every
                                                    // other cycle, so I should
                                                    // only update it every other
                                                    // cycle

                if (clock_8_1k_sync_last == 1'b0 && clock_8_1k_sync == 1'b1) begin
                    /*
                     * Rising edge of clock_8_1k_sync, so get next sample.
                     */
                    next_play_state = play_state_shiftregload;

                end else begin
                    /*
                     * Not a rising edge of clock_8_1k_sync, so keep playing
                     * current sample.
                     */
                    next_play_state = play_state_play1;
                end
            end

            play_state_play1: begin // AUD_BCLK=1
                /*
                 * Continue to play current sample.
                 * Shift bits (shift will occur on AUD_BCLK falling edge)
                 */
                shift_reg_shift = 1'b1;
                next_play_state = play_state_play0;
            end

            play_state_shiftregload: begin // AUD_BCLK=1
                /*
                 * Load shift register from current_sample.
                 * Raise AUD_DACLRCK (pulse starts on next falling edge of
                 * AUD_BCLK).
                 */
                shift_reg_write = 1'b1;
                current_sample_played_set = 1'b1;
                daclrck_toggle = 1'b1;
                next_play_state = play_state_pulse0;
            end

            play_state_pulse0: begin // AUD_BCLK=0
                next_play_state = play_state_pulse1;
            end

            play_state_pulse1: begin // AUD_BCLK=1
                /*
                 * Lower AUD_DACLRCK (pulse ends on next falling edge of
                 * AUD_BCLK)
                 */
                daclrck_toggle = 1'b1;
                next_play_state = play_state_play0;
            end

        endcase
    end

endmodule
