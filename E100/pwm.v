/*
 * Copyright (c) 2015, Michael Christen. All rights reserved.
 * Borrowing style & insight from P. Chen's extensive previous work.
 * This software is supplied as is without expressed or implied
 * warranties of any kind.
 */

/*
 * Controller to specify a PWM signal on the DE2-115 boards.
 * Sets a period and compare register, sets the output high until the
 * counter is greater than or equal to compare. If compare is greater than
 * period, then duty cycle will be 100%.
 * ie)
 * Period of 100 and compare of 10 would give 10% duty cycle
 * Period of 100 and compare of 70 would give 70% duty cycle
 * Period of 100 and compare of 120 would give 100% duty cycle
 */
module pwm(
	input wire clock,
	input wire clock_valid,
	input wire reset,

	//E100 Interface
	input wire pwm_command,
	output reg pwm_response,
	input wire [31:0] pwm_period,
	input wire [31:0] pwm_compare,

	//PWM Output pin
	output reg pwm_out,
	output reg pwm_in1,
	output reg pwm_in2);

	reg [2:0] state;
	reg [2:0] next_state;
	reg next_response;
	reg next_pwm_out;
	reg next_pwm_in1;
	reg next_pwm_in2;

	reg [31:0] period;
	reg [31:0] next_period;
	reg [31:0] compare;
	reg [31:0] next_compare;
	reg [31:0] counter;
	reg [31:0] next_counter;
	
	wire [31:0] abs_compare;
	
	assign abs_compare = ($signed(compare) > 32'sd0) ? $signed(compare) : (-32'sd1 * $signed(compare));

	parameter state_reset    = 2'h0;
	parameter state_idle     = 2'h1;
	parameter state_write    = 2'h2;
	parameter state_response = 2'h3;

	//PWM Control, set at own clock in case want to mess with
	//TODO: may want to just put in normal clock
	always @(posedge clock) begin
		if (clock_valid == 1'b0) begin
		end else if(reset == 1'b1) begin
			counter <= 0;
			pwm_out <= 0;
			period  <= 0;
			compare <= 0;
			state <= state_reset;
		end else begin
			counter <= next_counter;
			pwm_out <= next_pwm_out;
			pwm_in1 <= next_pwm_in1;
			pwm_in2 <= next_pwm_in2;
			period  <= next_period;
			compare <= next_compare;
			pwm_response <= next_response;
			state <= next_state;
		end
	end

	//State machine to implement IO Protocol
	//& Logic for pwm_out and counter
	always @* begin
		//Update counter appropriately
		if(counter == period) begin
			//Reset when hits period
			next_counter = 32'h0;
		end else begin
			next_counter = counter + 32'h1;
		end
		//Update PWM
		if(counter < abs_compare) begin
			//restart at 0
			next_pwm_out = 1'b1;
		end else begin
			next_pwm_out = 1'b0;
		end
		
		//if compare is positive then go forwards
		//if compare is negative then go backwards
		//else go into coast mode
		
		if($signed(compare) > 32'sd0) begin
		    next_pwm_in1 = 1'b1;
			next_pwm_in2 = 1'b0;
		end
		else if ($signed(compare) < 32'sd0) begin
		    next_pwm_in1 = 1'b0;
			next_pwm_in2 = 1'b1;
		end
		else begin
		    next_pwm_in1 = 1'b0;
			next_pwm_in2 = 1'b0;
		end
		
		next_state = state_reset;
		next_response = 1'b0;
		next_compare  = compare;
		next_period   = period;
		case (state)

			state_reset: begin
				next_state = state_idle;
				next_counter = 32'h0;
				next_compare = 32'h0;
				next_period  = 32'h0;
			end

			state_idle: begin
				if(pwm_command == 1'b1) begin
					next_state = state_write;
				end else begin
					next_state = state_idle;
				end
			end

			state_write: begin
				next_counter = 32'h0;
				next_compare = pwm_compare;
				next_period  = pwm_period;
				next_state   = state_response; 
			end

			state_response: begin
				next_response = 1'b1;
				if(pwm_command == 1'b1) begin
					//wait for command to go low
					next_state = state_response;
				end else begin
					next_state = state_idle;
				end
			end
		endcase
	end


endmodule



