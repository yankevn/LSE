/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * Maintains and displays the value of the reset signal.
 * Initialized to 1; push button toggles it.
 */
module reset_toggle(
    input wire osc_50,
    input wire push_button,
    output reg reset,
    output reg led);

    reg push_button_last, push_button_last1, push_button_last2;

    /*
     * Force power-up value to be 0.
     */
    (* altera_attribute = "-name POWER_UP_LEVEL LOW" *) reg reset_n;

    /*
     * Toggle reset on positive edges of push button (synchronized to OSC_50).
     */
    always @(posedge osc_50) begin
        push_button_last2 <= push_button_last1;
        push_button_last1 <= push_button_last;
        push_button_last <= push_button;
        if (push_button_last2 == 1'b0 && push_button_last1 == 1'b1) begin
            reset_n <= ~reset_n;
        end
    end

    always @* begin
        reset = ~reset_n;
        led = reset;
    end

endmodule
