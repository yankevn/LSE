/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

module mult(
    input wire clock,
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] mult_out_reg);

    reg [31:0] out;

    always @* begin
        /*
	 * Amazingly, this works for 2s complement negative numbers.
	 */
        out = in1 * in2;
    end

    /*
     * This register exists (and is named uniquely) so I can specify
     * it as a destination for a multicycle timing constraint.
     */
    always @(posedge clock) begin
        mult_out_reg <= out;
    end

endmodule
