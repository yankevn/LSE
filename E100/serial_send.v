/*
 * Copyright (c) 2007, John Dydo and Peter M. Chen.  All rights reserved.
 * This software is supplied as is without expressed or implied warranties of
 * any kind.
 */

/*
 * Controller for RS-232 serial port send.
 * Assumes serial port is set for 8 data bits, no parity bit, 1 stop bit,
 * 115200 baud
 */
module serial_send(
    input wire OSC_50,
    input wire clock_valid,
    input wire reset_50m,

    output reg UART_TXD,

    input wire serial_send_command,
    output reg serial_send_response,
    input wire [7:0] serial_send_data
    );

    reg [2:0] state;
    reg [2:0] next_state;

    reg [9:0] shift_reg;
    reg shift_reg_load;
    reg shift_reg_shift;

    reg [31:0] timer;
    reg timer_setfull;

    reg [3:0] count;
    reg count_set10;
    reg count_decr;

    reg next_serial_send_response;

    parameter CLOCK_RATE = 32'd50000000;
    parameter BAUD = 32'd113500;        // The standard baud rate would be 115200.
                                        // However, XBee modules can't achieve
                                        // 115200 baud, due to limited clock
                                        // resolution.  The closest baud rate for
                                        // an XBee module is 111111.  So, the
                                        // serial controller uses a rate that
                                        // is close enough to 115200 to communicate
                                        // reliably with a PC (-1.4%), and is close
                                        // enough to 111111 (+2.3%) to communicate
                                        // reliably with an XBee module.


    always @(posedge OSC_50) begin
        if (clock_valid == 1'b0) begin

        end else if (reset_50m == 1'b1) begin
            state <= state_reset;
            UART_TXD <= 1'b1;
            shift_reg <= 10'h3ff;

        end else begin

            if (shift_reg_load == 1'b1) begin
                shift_reg[0] <= 1'b0;                   // start bit
                shift_reg[8:1] <= serial_send_data;
                shift_reg[9] <= 1'b1;                   // stop bit

            end else if (shift_reg_shift == 1'b1) begin
                UART_TXD <= shift_reg[0];       // data is sent LSB first
                shift_reg[8:0] <= shift_reg[9:1];

            end

            if (timer_setfull == 1'b1) begin
                // 1 bit time (in cycles)
                timer <= CLOCK_RATE / BAUD;

            end else begin
                timer <= timer - 32'h1;
            end

            if (count_set10 == 1'b1) begin
                count <= 4'd10;
            end else if (count_decr == 1'b1) begin
                count <= count - 4'd1;
            end

            // register serial_send_response to prevent glitches
            serial_send_response <= next_serial_send_response;

            state <= next_state;

        end

    end

    parameter state_reset       = 3'h0;
    parameter state_idle        = 3'h1;
    parameter state_shift       = 3'h2;
    parameter state_delay       = 3'h3;
    parameter state_response    = 3'h4;

    always @* begin
        next_state = state_reset;
        shift_reg_load = 1'b0;
        shift_reg_shift = 1'b0;
        count_set10 = 1'b0;
        count_decr = 1'b0;
        timer_setfull = 1'b0;
        next_serial_send_response = 1'b0;

        case (state)

            state_reset: begin
                next_state = state_idle;
            end

            state_idle: begin
                // load shift register in case incoming data is valid
                shift_reg_load = 1'b1;
                count_set10 = 1'b1;
                
                if (serial_send_command == 1'b0) begin
                    next_state = state_idle;
                end else begin
                    next_state = state_shift;
                end
            end

            state_shift: begin
                shift_reg_shift = 1'b1;
                count_decr = 1'b1;
                timer_setfull = 1'b1;
                next_state = state_delay;
            end

            state_delay: begin
                if (timer != 32'h0) begin
                    next_state = state_delay;

                end else if (count != 4'h0) begin
                    next_state = state_shift;

                end else begin
                    next_state = state_response;
                end
            end

            state_response: begin
                next_serial_send_response = 1'b1;
                if (serial_send_command == 1'b0) begin
                    next_state = state_idle;
                end else begin
                    next_state = state_response;
                end
            end

        endcase
    end

endmodule
