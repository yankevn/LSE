/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */
module register(
    input wire clock,
    input wire clock_valid,
    input wire reset,
    input wire write,
    input wire [31:0] data_in,
    output reg [31:0] data_out);

    always @(posedge clock) begin
        if (clock_valid == 1'b0) begin
        end else if (reset == 1'b1) begin
            data_out <= 32'h0;
        end else if (write == 1'b1) begin
            data_out <= data_in;
        end
    end

endmodule
