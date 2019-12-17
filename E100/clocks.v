/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Produce clocks of various frequencies.
 */
module clocks(
    input wire osc_50,                  // 50 MHz oscillator from the board

    output reg clock,                   // main E100 clock
    output wire clock_100m,             // 100 MHz clock
    output wire clock_25m,              // 25 MHz clock
    output reg clock_1_6m,              // 1.6 MHz clock
    output reg clock_195k,              // 195 KHz clock
    output reg clock_8_1k,              // 8.1 KHz clock
    output wire clock_valid);           // 1 if E100 clock is valid; 0 otherwise

    reg [6:0] clock_slow;
    reg [11:0] counter_8k;
    wire clock_75m;			// 75 MHz clock

    /*
     * Generate 100 MHz, 75 MHz, 25 MHz clocks.
     */
    pll u1 (osc_50, clock_100m, clock_75m, clock_25m, clock_valid);

    /*
     * Compute clocks at various speeds, using a counter.
     */
    always @(posedge clock_25m) begin
        if (clock_valid == 1'b1) begin
            clock_slow <= clock_slow + 7'h1;
        end
    end

    always @* begin
	clock_1_6m = clock_slow[3];
        clock_195k = clock_slow[6];
    end

    /*
     * Create 8.1 KHz clock (needs to be a little faster than 8 KHz, otherwise
     * sound wavers or crackles).  Currently use 8138.0208333 Hz.
     */
    always @(posedge osc_50) begin
        if (counter_8k == 12'd3071) begin
            clock_8_1k <= ~clock_8_1k;
            counter_8k <= 12'd0;
        end else begin
            counter_8k <= counter_8k + 12'd1;
        end
    end

    always @* begin

        /*
         * Uncomment exactly one of these lines to choose a clock speed.
         * These clock speeds require the top.qsf from Lab 7.
         */

        // clock = clock_25m;                    // 25 MHz
        // clock = osc_50;                       // 50 MHz
        // clock = clock_75m;                    // 75 MHz
        clock = clock_100m;                      // 100 MHz
    end

endmodule
