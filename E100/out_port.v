/*
 * Copyright (c) 2006,2013 Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * I/O device register that can be written by the E100.  The E100 can also
 * read back the last value written to the device register (this differs
 * from a true inout port, for which the E100 can read a value that is
 * written by the I/O device).
 */
module out_port #(parameter WIDTH=32) (
    input wire [31:0] port_number,
    input wire clock,
    input wire clock_io,
    input wire clock_valid,
    input wire reset,
    input wire [31:0] address,
    input wire memory_drive,
    input wire memory_write,
    input wire [31:0] bus,
    output wire [WIDTH-1:0] port_pins);

    reg port_selected;                          // this port has been selected by
						// the last address

    wire [31:0] port_data;

    always @* begin
        if (address == port_number) begin
	    port_selected = 1'b1;
	end else begin
	    port_selected = 1'b0;
	end
    end

    // register value (E100 clock domain)
    register u1 (clock, clock_valid, reset, memory_write & port_selected,
                 {{(32-WIDTH){1'b0}}, bus[WIDTH-1:0]}, port_data);

    // output to the I/O pins (I/O clock domain)
    synchronizer #(.WIDTH(WIDTH)) u2 (clock_io, port_data[WIDTH-1:0], port_pins);

endmodule
