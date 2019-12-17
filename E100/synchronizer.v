/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Synchronize to get rid of metastability.
 */
module synchronizer #(parameter WIDTH=32) (
    input wire clock,
    input wire [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out);

    reg [WIDTH-1:0] sync_reg_out;

    always @(posedge clock) begin
        sync_reg_out <= in;
	out <= sync_reg_out;
    end

endmodule
