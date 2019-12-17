/*
 * Copyright (c) 2006,2013 Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * I/O device register that can be written by the E100 *or* by the I/O device.
 * The direction of the port is set by the last operation: a write (by the E100)
 * causes the device register to be driven onto the port pins; a read (by the
 * E100) causes the device register to constantly store the value on the port
 * pins (the port pins are high impedance, i.e., not driven by the device
 * register).
 *
 * The E100 can also read the current value in the device register.  The
 * first read after a write changes the direction of the port; the value
 * returned by this read should be ignored, because the port may still have
 * the value that was last written by the E100.  Subsequent reads will get the
 * value from the port pins, assuming there's been enough time for the data
 * from the port pins to make it through the synchronizer.
 */
module inout_port #(parameter WIDTH=32) (
    input wire [31:0] port_number,
    input wire clock,
    input wire clock_io,
    input wire clock_valid,
    input wire reset,
    input wire [31:0] address,
    input wire memory_drive,
    input wire memory_write,
    inout wire [31:0] bus,
    inout wire [WIDTH-1:0] port_pins);

    reg port_selected;          // this port has been selected by the last address
    reg pin_drive;              // drive port register onto I/O pins

    wire [31:0] port_data;
    wire [31:0] port_data_sync;
    wire [WIDTH-1:0] port_pins_sync;

    wire [32-WIDTH-1:0] unused;

    always @* begin
	if (address == port_number) begin
	    port_selected = 1'b1;
	end else begin
	    port_selected = 1'b0;
	end
    end

    // control output to the bus
    synchronizer #(.WIDTH(WIDTH)) u1 (clock, port_pins, port_pins_sync);
    tristate u2 ( { {(32-WIDTH){1'b0}}, port_pins_sync}, bus,
                memory_drive & port_selected);

    // register value (E100 clock domain)
    register u3 (clock, clock_valid, reset, memory_write & port_selected,
		 { {(32-WIDTH){1'b0}}, bus[WIDTH-1:0]}, port_data);

    // control output to the I/O pins
    synchronizer u4 (clock_io, port_data, port_data_sync);
    tristate u5 (port_data_sync, {unused, port_pins}, pin_drive);

    always @(posedge clock) begin
	if (clock_valid == 1'b0) begin
	end else if (reset == 1'b1) begin
	    pin_drive <= 1'b0;
        end else if (port_selected == 1'b1) begin
	    if (memory_write == 1'b1) begin
		pin_drive <= 1'b1;
	    end else if (memory_drive == 1'b1) begin
		pin_drive <= 1'b0;
	    end
	end
    end

endmodule
