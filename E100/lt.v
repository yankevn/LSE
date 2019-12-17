/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module lt(
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg out);

    always @* begin
        if (in1[31] != in2[31]) begin
	    out = in1[31];
	end else begin
	    if (in1 < in2) begin
		out = 1'b1;
	    end else begin
		out = 1'b0;
	    end
	end 
    end

endmodule
