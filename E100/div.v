/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Compute signed division.
 */

module div(
    input wire clock,
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] div_out_reg);

    reg [31:0] in1_pos;
    reg [31:0] in2_pos;
    reg [31:0] out;

    always @* begin
        // out = in1 / in2;
	if (in1[31] == 1'b1) begin
	    in1_pos = -in1;
	end else begin
	    in1_pos = in1;
	end

	if (in2[31] == 1'b1) begin
	    in2_pos = -in2;
	end else begin
	    in2_pos = in2;
	end

        out = in1_pos / in2_pos;

	if (in1[31] != in2[31]) begin
	    out = -out;
	end
    end

    /*
     * This register exists (and is named uniquely) so I can specify
     * it as a destination for a multicycle timing constraint.
     */
    always @(posedge clock) begin
        div_out_reg <= out;
    end

endmodule
