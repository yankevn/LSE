/*
 * Copyright (c) 2019, Devin Ardeshna, John Hill, Tara Sabbineni, Kevin Yan. 
 * All rights reserved. Borrowing style & insight from P. Chen's extensive previous work.
 * This software is supplied as is without expressed or implied
 * warranties of any kind.
 */

/*
 * Controller to help read and write data to IR reflectance sensor using the DE2-115's GPIO pins.
 * Sets a register ir_count, sets the output high, and counts how long the return value given by the sensor
 * (ir_capacitor_high) is high up until 3 ms in ir_count.
 */
 
module ir(
	input wire clock,
	input wire clock_valid,
	input wire reset,

	//E100 Interface
	output reg [18:0] ir_count, // Register to store count value, between 0 and 3000
	inout wire ir_readWrite); // Read in from sensor at GPIO8
	
	reg [2:0] state, next_state;
	wire ir_read, ir_read_sync;
	reg ir_write, next_ir_write; // Use to determine if reading or writing
	reg [18:0] counter, next_counter, next_ir_count;
	
	parameter state_reset = 2'h0;
	parameter state_charge   = 2'h1; // charge capacitor until 10 micro sec
	parameter state_read     = 2'h2; // read value from line sensor for 3 mili sec OR outputs 0

	// Combinational logic: if ir_write is 1, write; otherwise high impedance while reading
	assign ir_readWrite = ir_write ? 1'b1 : 1'bz;
	assign ir_read = ir_readWrite;
 
	// Synchronize ir_read with an extra register to prevent metastability
   synchronizer #(.WIDTH(1)) u3 (clock, ir_read, ir_read_sync);
 
	// Sequential logic to update states, counters, and ir_write on rising edge of clock
	always @(posedge clock) begin
		if (clock_valid == 1'b1) begin
			if(reset == 1'b1) begin
				counter <= 19'd0;
				ir_count <= 19'd0;
				ir_write <= 1'b0;
				state <= state_reset;
			end
			
			else begin
				ir_count <= next_ir_count;
				counter <= next_counter;
				ir_write <= next_ir_write;
				state <= next_state;
			end
		end
	end
	
	// Finite state machine to implement IO command/response protocol
	// & Logic for ir_count
	always @* begin
		next_ir_count = ir_count;
		next_ir_write = 1'b0;
		next_counter = 19'b0;
		next_state = state_reset;
		
		case (state)
			state_reset: begin
				next_state = state_charge;
			end
			
			state_charge: begin
				if(counter < 19'd1000) begin																																							
					next_ir_write = 1'b1;
					next_counter = counter + 19'd1;
					next_state = state_charge;
				end
				else begin
					next_counter = 19'd0;
					next_ir_write = 1'b0;
					next_state = state_read;
				end
				
			end
			
			state_read: begin
				if((counter >= 19'd300000) || (ir_read_sync == 1'b0)) begin
					next_ir_count = counter;
					next_counter = 19'd0;
					next_state = state_charge;
				end

				else begin
					next_counter = counter + 19'd1;
					next_state = state_read;
				end
			end
			
		endcase
	end
endmodule
