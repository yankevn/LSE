/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module tristate(
    input wire [31:0] in,
    output reg [31:0] out,
    input wire drive);

    always @* begin
        if (drive == 1'b1) begin
            out = in;
        end else begin
            out = {32{1'bz}};
        end
    end

endmodule
