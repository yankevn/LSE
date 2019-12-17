/*
 * Copyright (c) 2007, John Dydo and Peter M. Chen.  All rights reserved.
 * This software is supplied as is without expressed or implied warranties of
 * any kind.
 */

/*
 * Controller for RS-232 serial port receive.
 * Assumes serial port is set for 8 data bits, no parity, 1 stop bit,
 * 115200 baud
 */
module serial_receive(
    input wire OSC_50,
    input wire clock_valid,
    input wire reset_50m,

    input wire UART_RXD,

    input wire serial_receive_command,
    output reg serial_receive_response,
    output wire [7:0] serial_receive_data);

    reg uart_rxd_sync;

    reg [2:0] receive_state;
    reg [2:0] next_receive_state;

    reg [1:0] cpu_state;
    reg [1:0] next_cpu_state;

    reg [31:0] timer;
    reg timer_setfull;
    reg timer_setfullandhalf;

    reg [7:0] uart_data;
    reg uart_data_write;

    reg [2:0] count;
    reg count_set7;
    reg count_decr;

    reg fifo_read;
    reg fifo_write;
    reg fifo_clear;
    wire fifo_empty;
    wire fifo_full;

    reg next_serial_receive_response;

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

    serial_receive_fifo u1 (OSC_50, uart_data, fifo_read, fifo_clear, fifo_write,
                         fifo_empty, fifo_full, serial_receive_data);

    parameter receive_state_reset       = 3'h0;
    parameter receive_state_idle        = 3'h1;
    parameter receive_state_delay       = 3'h2;
    parameter receive_state_read        = 3'h3;
    parameter receive_state_delay1      = 3'h4;
    parameter receive_state_push        = 3'h5;

    parameter cpu_state_reset    = 2'h0;
    parameter cpu_state_idle     = 2'h1;
    parameter cpu_state_read     = 2'h2;
    parameter cpu_state_response = 2'h3;

    always @(posedge OSC_50) begin
        if (clock_valid == 1'b0) begin

        end else if (reset_50m == 1'b1) begin
            fifo_clear <= 1'b1;
            receive_state <= receive_state_reset;
            cpu_state <= cpu_state_reset;

        end else begin
            fifo_clear <= 1'b0;

            if (timer_setfull == 1'b1) begin
                // 1 bit time (in cycles) 
                timer <= CLOCK_RATE / BAUD;

            end else if (timer_setfullandhalf == 1'b1) begin
                // 1.5 bit time (in cycles)
                timer <= ((CLOCK_RATE * 32'd3) >> 1'b1) / BAUD;

            end else begin
                timer <= timer - 32'h1;
            end

            if (count_set7 == 1'b1) begin
                count <= 3'h7;
            end else if (count_decr == 1'b1) begin
                count <= count - 3'h1;
            end

            if (uart_data_write == 1'b1) begin
                uart_data[6:0] <= uart_data[7:1];
                uart_data[7] <= uart_rxd_sync;
            end

            // synchronize UART_RXD to avoid glitches
            uart_rxd_sync <= UART_RXD;

            // register serial_receive_response to prevent glitches
            serial_receive_response <= next_serial_receive_response;

            receive_state <= next_receive_state;
            cpu_state <= next_cpu_state;

        end

    end

    /*
     * Serial port state machine
     */
    always @* begin
        /*
         * Default values for control signals
         */
        timer_setfull = 1'b0;
        timer_setfullandhalf = 1'b0;
        count_set7 = 1'b0;
        count_decr = 1'b0;
        uart_data_write = 1'b0;
        fifo_write = 1'b0;
        next_receive_state = receive_state_reset;

        case (receive_state)

            receive_state_reset: begin
                next_receive_state = receive_state_idle;
            end

            // wait for start bit
            receive_state_idle: begin
                // get ready to delay, in case I see a start bit
                timer_setfullandhalf = 1'b1;
                count_set7 = 1'b1;

                // look for start bit
                if (uart_rxd_sync == 1'b0) begin
                    next_receive_state = receive_state_delay;
                end else begin
                    next_receive_state = receive_state_idle;
                end
            end

            // wait 1 or 1.5 bit times
            receive_state_delay: begin
                if (timer == 32'h0) begin
                    next_receive_state = receive_state_read;
                end else begin
                    next_receive_state = receive_state_delay;
                end
            end

            // read bit
            receive_state_read: begin
                timer_setfull = 1'b1;
                count_decr = 1'b1;
                uart_data_write = 1'b1;

                // this tests count before it's decremented, which is why
                // setting count to 7 results in receiving 8 bits
                if (count != 3'h0) begin
                    // receive next bit
                    next_receive_state = receive_state_delay;

                end else begin
                    // delay until stop bit
                    next_receive_state = receive_state_delay1;
                end
            end

            // delay 1 more bit time, to reading last data bit and get to stop bit 
            receive_state_delay1: begin
                if (timer != 32'h0) begin
                    next_receive_state = receive_state_delay1;
                end else if (fifo_full == 1'b1) begin
                    // fifo is full; drop this byte
                    next_receive_state = receive_state_idle;
                end else begin
                    // add to fifo
                    next_receive_state = receive_state_push;
                end
            end

            // write byte to fifo
            receive_state_push: begin
                fifo_write = 1'b1;
                next_receive_state = receive_state_idle;
            end

        endcase

    end

    /*
     * CPU state machine
     */
    always @* begin
        /*
         * Default values for control signals
         */
        next_serial_receive_response = 1'b0;
        fifo_read = 1'b0;
        next_cpu_state = cpu_state_reset;

        case (cpu_state)

            cpu_state_reset: begin
                next_cpu_state = cpu_state_idle;
            end

            cpu_state_idle: begin
                if (serial_receive_command == 1'b1 && fifo_empty == 1'b0) begin
                    next_cpu_state = cpu_state_read;
                end else begin
                    next_cpu_state = cpu_state_idle;
                end
            end

            cpu_state_read: begin
                fifo_read = 1'b1;       // fifo doesn't output data until
                                        // it gets a read request
                next_cpu_state = cpu_state_response;
            end

            cpu_state_response: begin
                next_serial_receive_response = 1'b1;
                if (serial_receive_command == 1'b0) begin
                    next_cpu_state = cpu_state_idle;
                end else begin
                    next_cpu_state = cpu_state_response;
                end
            end

        endcase
    end

endmodule
