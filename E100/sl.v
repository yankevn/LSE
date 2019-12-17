/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module sl(
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] out);

    always @* begin
        out = in1 << in2;
    end

endmodule
