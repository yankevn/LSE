/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module in_port #(parameter WIDTH=32) (
    input wire [31:0] port_number,
    input wire clock,
    input wire [31:0] address,
    input wire memory_drive,
    output reg [31:0] bus,
    input wire [WIDTH-1:0] port_pins);

    reg port_selected;				// this port has been selected by
    						// the last address

    wire [WIDTH-1:0] port_pins_sync;

    always @* begin
        if (address == port_number) begin
	    port_selected = 1'b1;
	end else begin
	    port_selected = 1'b0;
	end 
    end

    // control output to the bus
    synchronizer #(.WIDTH(WIDTH)) u1 (clock, port_pins, port_pins_sync);
    
    always @* begin
        if (memory_drive == 1'b1 && port_selected == 1'b1) begin
            bus = { {(32-WIDTH){1'b0}}, port_pins_sync };
        end else begin
            bus = {32{1'bz}};
        end
    end

endmodule
