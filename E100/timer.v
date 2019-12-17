/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module timer(
    input wire clock,
    input wire clock_8_1k,
    input wire clock_valid,
    input wire reset,
    output reg [31:0] timer_out);           // real-time clock (each clock tick
                                            // is .125 ms, i.e. 8000 Hz)
    wire clock_8_1k_sync;
    reg clock_8_1k_sync_last;
    reg clock_8_1k_sync_last1;

    synchronizer #(.WIDTH(1)) u1 (clock, clock_8_1k, clock_8_1k_sync);

    always @(posedge clock) begin
	clock_8_1k_sync_last1 <= clock_8_1k_sync_last;
	clock_8_1k_sync_last <= clock_8_1k_sync;
    end

    // Detect a positive edge of clock_8_1k by sampling it, rather than
    // via (posedge clock_8_1k).  This reduces timing warnings when using
    // a 50 MHz clock.
    always @(posedge clock) begin

        if (clock_valid == 1'b0) begin
	end else if (reset == 1'b1) begin
            timer_out <= 32'h0;
        end else if (clock_8_1k_sync_last1 == 1'b0 && clock_8_1k_sync_last == 1'b1) begin
	    timer_out <= timer_out + 32'h1;
        end
    end

endmodule
