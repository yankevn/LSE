/*
 * Copyright (c) 2006, Steven Lieberman.  All rights reserved.  This software
 * is supplied as is without expressed or implied warranties of any kind.
 */
module ps2_serial(
    input wire clock_25m,  // The clock can be any speed that's sufficiently
                           // faster than the 10-16.7 kHz signal produced
                           // by the PS/2 serial interface.
    input wire clock_valid,
    input wire reset_25m,
    input wire PS2_CLK,
    input wire PS2_DAT,
    input wire ack,
    output wire [7:0] data,
    output reg valid);

reg ps2_dat_sync;
reg ps2_clk_sync;
reg [7:0] ps2_clk_history;
reg data_reg_shift;

reg buf_read;
reg buf_write;
reg buf_write_if_not_full;
reg [7:0] buf_in;
wire buf_empty;
wire buf_full;

/*
 * We need to register PS2_DAT because the state machine calculates
 * the next state based on it, and since we're registering PS2_DAT, we
 * should do the same for PS2_CLK.
 */
always @(posedge clock_25m) begin
    ps2_dat_sync <= PS2_DAT;
    ps2_clk_sync <= PS2_CLK;
end

always @(posedge clock_25m) begin
    if (clock_valid == 1'b1) begin
        if (reset_25m == 1'b1) begin
	    ps2_clk_history <= 8'h0;
	    buf_in <= 8'h0;
	end else begin
	    /*
	     * ps2_clk_history maintains the last 8 seen values of PS2_CLK.
	     * It is always shifting right, filling in the leftmost bits with
	     * the new values of PS2_CLK.
	     */
	    ps2_clk_history[7] <= ps2_clk_sync;
	    ps2_clk_history[6:0] <= ps2_clk_history[7:1];

	    /*
	     * buf_in records the data bits that come in off the serial
	     * interface (LSB first).
	     */
	    if (data_reg_shift == 1'b1) begin
		buf_in[7] <= ps2_dat_sync;
		buf_in[6:0] <= buf_in[7:1];
	    end
	end
    end
end

//TODO: incorporate clock_valid
ps2_serial_buf u1 (clock_25m, buf_in, buf_read, reset_25m, buf_write, 
             buf_empty, buf_full, data);

always @* begin
    if (buf_full == 1'b1) begin
        buf_write = 1'b0;
    end else begin
        buf_write = buf_write_if_not_full;
    end
end

//===========================================================================


reg [1:0] consumer_state;
reg [1:0] next_consumer_state;

parameter state_consumer_reset    = 2'h0;
parameter state_consumer_idle     = 2'h1;
parameter state_consumer_valid    = 2'h2;
parameter state_consumer_validlow = 2'h3;

always @(posedge clock_25m) begin
    if (clock_valid == 1'b0) begin
    end else if (reset_25m == 1'b1) begin
        consumer_state <= state_consumer_reset;
    end else begin
        consumer_state <= next_consumer_state;
    end
end

always @* begin
    valid = 1'b0;
    buf_read = 1'b0;   // normally, don't consume values
    next_consumer_state = state_consumer_reset;

    case (consumer_state)

	state_consumer_reset: begin
	    next_consumer_state = state_consumer_idle;
	end

	state_consumer_idle: begin
	    if (buf_empty == 1'b1) begin
		next_consumer_state = state_consumer_idle; // loop
	    end else begin
		next_consumer_state = state_consumer_valid;
	    end
	end

	state_consumer_valid: begin
	    valid = 1'b1;

	    if (ack == 1'b0) begin
		next_consumer_state = state_consumer_valid; // loop
	    end else begin
		next_consumer_state = state_consumer_validlow;
	    end
	end

	state_consumer_validlow: begin
	    buf_read = 1'b1;  // consume the value we sent out last cycle

	    if (ack == 1'b1) begin
		next_consumer_state = state_consumer_validlow; // loop
	    end else begin
		next_consumer_state = state_consumer_idle;
	    end
	end

    endcase
end


//===========================================================================



reg next_active_state_wr_en;
reg [3:0] next_active_state_in;
reg [3:0] next_active_state;

reg [3:0] state;
reg [3:0] next_state;

parameter state_start     = 4'h0;
parameter state_data0     = 4'h1;
parameter state_data1     = 4'h2;
parameter state_data2     = 4'h3;
parameter state_data3     = 4'h4;
parameter state_data4     = 4'h5;
parameter state_data5     = 4'h6;
parameter state_data6     = 4'h7;
parameter state_data7     = 4'h8;
parameter state_parity    = 4'h9;
parameter state_stop      = 4'hA;
parameter state_clocklow  = 4'hB;
parameter state_clockhigh = 4'hC;

always @(posedge clock_25m) begin
    if (clock_valid == 1'b0) begin
    end else if (reset_25m == 1'b1) begin
        state <= state_clockhigh;
        next_active_state <= state_start;
    end else begin
        state <= next_state;    

        if (next_active_state_wr_en == 1'b1) begin
            next_active_state <= next_active_state_in;
        end
    end
end

always @* begin
    next_active_state_in = state_start;
    next_active_state_wr_en = 1'b0;
    data_reg_shift = 1'b0;
    buf_write_if_not_full = 1'b0;

    /*
     * Default to state_clockhigh, since the 'active states' all occur just
     * after a positive clock edge -- when they are finished, the clock
     * should still be high.
     */
    next_state = state_clockhigh; 

    case (state)
    
	state_start: begin
	    /*
	     * Attempts to start; if the bit is start, we'll progress to accept
	     * data, otherwise, we'll just jump loop back to here.
	     */
	    next_active_state_wr_en = 1'b1;
	    if (PS2_DAT == 1'b1) begin
		next_active_state_in = state_start; // loop
	    end else begin
		next_active_state_in = state_data0;
	    end
	end

	state_data0: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data1;
	end

	state_data1: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data2;
	end

	state_data2: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data3;
	end

	state_data3: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data4;
	end

	state_data4: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data5;
	end

	state_data5: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data6;
	end

	state_data6: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_data7;
	end

	state_data7: begin
	    data_reg_shift = 1'b1;
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_parity;
	end

	state_parity: begin
	    //TODO: do something with the parity bit -- for now, it's ignored
	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_stop;
	end

	state_stop: begin
	    buf_write_if_not_full = 1'b1;

	    next_active_state_wr_en = 1'b1;
	    next_active_state_in = state_start;    
	end

	state_clocklow: begin
	    if (ps2_clk_history == 8'hFF) begin
		/*
		 * On the positive edges of the ps2_clk_history, which serves
		 * as our filtered clock, we want to transistion to the next
		 * 'true state.'
		 */
		next_state = next_active_state;
	    end else begin
		next_state = state_clocklow; // loop
	    end
	end

	state_clockhigh: begin
	    if (ps2_clk_history == 8'h00) begin
		/*
		 * This is the negative edge, don't do any processing here.
		 * Just go and wait for the positive clock edge.
		 */
		next_state = state_clocklow;
	    end else begin
		next_state = state_clockhigh;
	    end
	end

    endcase
end

endmodule
