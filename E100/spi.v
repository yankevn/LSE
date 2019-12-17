/*
 * SPI Master found @
 * https://embeddedmicro.com/tutorials/mojo/serial-peripheral-interface-spi
 * Embedded Micro implementation
 */

module spi_master #(parameter CLK_DIV = 2)(
        input clk,
        input rst,
        input miso,
        output mosi,
        output sck,
        input start,
        input[7:0] data_in,
        output[7:0] data_out,
        output busy,
        output new_data
    );
     
    localparam STATE_SIZE = 2;
    localparam IDLE = 2'd0,
            WAIT_HALF = 2'd1,
            TRANSFER = 2'd2;
     
    reg [STATE_SIZE-1:0] state_d, state_q;
     
    reg [7:0] data_d, data_q;
    reg [CLK_DIV-1:0] sck_d, sck_q;
    reg mosi_d, mosi_q;
    reg [2:0] ctr_d, ctr_q;
    reg new_data_d, new_data_q;
    reg [7:0] data_out_d, data_out_q;
     
    assign mosi = mosi_q;
    assign sck = ((sck_q[CLK_DIV-1]) & (state_q == TRANSFER)) | (state_q == IDLE); //changed to delay
    assign busy = state_q != IDLE;
    assign data_out = data_out_q;
    assign new_data = new_data_q;
     
    always @(*) begin
        sck_d = sck_q;
        data_d = data_q;
        mosi_d = mosi_q;
        ctr_d = ctr_q;
        new_data_d = 1'b0;
        data_out_d = data_out_q;
        state_d = state_q;
         
        case (state_q)
            IDLE: begin
                sck_d = 4'b0;
                ctr_d = 3'b0;
                if (start == 1'b1) begin
                    data_d = data_in;
                    state_d = WAIT_HALF;
                end
            end
            WAIT_HALF: begin
                sck_d = sck_q + 1'b1;
                if (sck_q == {CLK_DIV-1{1'b1}}) begin
                    sck_d = 1'b0;
                    state_d = TRANSFER;
                end
            end
            TRANSFER: begin
                sck_d = sck_q + 1'b1;
                if (sck_q == 4'b0000) begin
                    mosi_d = data_q[7];
                end else if (sck_q == {CLK_DIV-1{1'b1}}) begin
                    data_d = {data_q[6:0], miso};
                end else if (sck_q == {CLK_DIV{1'b1}}) begin
                    ctr_d = ctr_q + 1'b1;
                    if (ctr_q == 3'b111) begin
                        state_d = IDLE;
                        data_out_d = data_q;
                        new_data_d = 1'b1;
                    end
                end
            end
        endcase
    end
     
    always @(posedge clk) begin
        if (rst) begin
            ctr_q <= 3'b0;
            data_q <= 8'b0;
            sck_q <= 4'b0;
            mosi_q <= 1'b0;
            state_q <= IDLE;
            data_out_q <= 8'b0;
            new_data_q <= 1'b0;
        end else begin
            ctr_q <= ctr_d;
            data_q <= data_d;
            sck_q <= sck_d;
            mosi_q <= mosi_d;
            state_q <= state_d;
            data_out_q <= data_out_d;
            new_data_q <= new_data_d;
        end
    end
     
endmodule

/* 
 * SPI wrapper written by
 * Michael Christen - 2015
 */

module spi (
	//STD
	input wire clock,
	input wire clock_valid,
	input wire reset,
	//GPIO pins
	input wire miso,
	output wire mosi,
	output wire sck,
	output wire ss,
	//E100 Interface
	input wire spi_command,
	output reg spi_response,
	input wire [7:0] spi_send_data,
	output wire [7:0] spi_receive_data);

	reg next_response;
	//Input to module
	reg start, next_start;
	//Output from module
	wire busy, new_data;
	assign ss = ~busy; //active low

	reg [1:0] state;
	reg [1:0] next_state;
	parameter state_reset = 2'h0;
	parameter state_idle  = 2'h1;
	parameter state_busy  = 2'h2;
	parameter state_done  = 2'h3;

	spi_master #(.CLK_DIV(10)) spi_impl (
			clock & clock_valid, 
			reset,
			miso,
			mosi,
			sck,
			start,
			spi_send_data,
			spi_receive_data,
			busy,
			new_data);

	always @(posedge clock) begin
		if(clock_valid == 1'b0) begin
		end else if(reset == 1'b1) begin
			spi_response <= 1'b0;
			state <= state_reset;
			start <= 1'b0;
		end else begin
			spi_response <= next_response;
			state        <= next_state;
			start		 <= next_start;
		end
	end

	always @* begin
		next_state = state_reset;	
		next_response = 1'b0;
		next_start    = 1'b0;

		case (state)
			state_reset: begin
				next_state = state_idle;
			end

			state_idle: begin
				if(spi_command == 1'b1) begin
					next_start  = 1'b1;
					next_state = state_busy;
				end else begin
					next_state = state_idle;
				end
			end

			state_busy: begin
				if(new_data == 1'b1) begin
					next_state = state_done;
				end else begin
					next_state = state_busy;
				end
			end

			state_done: begin
				next_response = 1'b1;
				if(spi_command == 1'b0) begin
					next_state = state_idle;
				end else begin
					next_state = state_done;
				end
			end

		endcase
	end

endmodule
