/*
 * Copyright (c) 2006, 2013 Peter M. Chen and Steven Lieberman.  All rights
 * reserved.  This software is supplied as is without expressed or implied
 * warranties of any kind.
 */

/*
 * VGA controller for Analog Devices ADV7123 Video DAC (I think fCLK_MAX is
 * 140 MHz).  Uses ISSI IS61WV102416 (8 ns) SRAM.  vga.pdf has a timing
 * diagram that shows how I pipeline the accesses through the SRAM.
 */
module vga(
    input wire clock_100m,
    input wire clock_valid,
    input wire reset_100m,

    /*
     * Interface to E100
     */
    input wire vga_command,
    output reg vga_response,
    input wire vga_write,
    input wire [9:0] vga_x1,
    input wire [9:0] vga_y1,
    input wire [9:0] vga_x2,
    input wire [9:0] vga_y2,
    input wire [14:0] vga_color_write,   // write color data to screen
    output reg [14:0] vga_color_read,    // read color data from screen

    /*
     * Interface to camera controller.  Unlike the normal I/O protocol,
     * this is a synchronous interface: e.g., camera_to_vga_ack is asserted for
     * exactly one cycle (to pop the top element off the camera FIFO).
     */
    input wire camera_to_vga_valid,
    output reg camera_to_vga_ack,       // Tell camera controller that
                                        // vga has gotten the data.  This can
                                        // serve as a pop for the camera
                                        // controller's FIFO.
    input wire [9:0] camera_to_vga_x,
    input wire [9:0] camera_to_vga_y,
    input wire [14:0] camera_to_vga_color,

    /*
     * Interface to video DAC
     */
    output reg [7:0] VGA_R,
    output reg [7:0] VGA_G,
    output reg [7:0] VGA_B,
    output reg VGA_CLK,
    output reg VGA_BLANK_N,
    output reg VGA_HS,
    output reg VGA_VS,
    output reg VGA_SYNC_N,

    inout reg [15:0] SRAM_DQ,
    output reg SRAM_CE_N,
    output reg SRAM_OE_N,
    output reg SRAM_LB_N,
    output reg SRAM_UB_N,
    output reg SRAM_WE_N,
    output reg [19:0] SRAM_ADDR);

    reg [9:0] vga_horiz;
    reg [9:0] vga_vert;

    reg [9:0] vga_address_x;
    reg [9:0] vga_address_y;
    reg [9:0] cpu_address_x;
    reg [9:0] cpu_address_y;

    reg sram_write;			// write to SRAM

    reg [14:0] sram_color;              // color to write to the SRAM

    reg cpu_address_load;               // load the CPU address registers
    reg cpu_done;			// done carrying out the CPU's write request

    reg vga_response_clear;
    reg vga_response_set;

    reg camera_write;

    reg return_to_write;		// carrying out CPU's write request to
                                        // SRAM.  The camera states use this to
                                        // figure out which state to return to.
    reg return_to_write_clear;

    reg cpu_write_active;		// in the CPU write state
    reg cpu_read_active;		// in the CPU read state
    reg camera_active;			// in the camera state

    reg [3:0] phase;			// the state machine goes through 4 phases
    					// (0, 1, 2, 3) for each state.
					// Encoded in unary.
    reg [2:0] state;
    reg [2:0] next_state;

    /*
     * VGA parameters: from Altera's DE2_Default
     */
    parameter H_SYNC_CYC     = 10'd96;
    parameter H_SYNC_BACK    = 10'd45 + 10'd3;
    parameter H_SYNC_ACT     = 10'd640;    // 646
    parameter H_SYNC_TOTAL   = 10'd800;
    parameter V_SYNC_CYC     = 10'd2;
    parameter V_SYNC_BACK    = 10'd30 + 10'd2;
    parameter V_SYNC_ACT     = 10'd480;    // 484
    parameter V_SYNC_TOTAL   = 10'd525;
    parameter X_START  = H_SYNC_CYC+H_SYNC_BACK;
    parameter Y_START  = V_SYNC_CYC+V_SYNC_BACK;

    /*
     * VGA path.
     */
    always @(posedge clock_100m) begin
        if (reset_100m == 1'b1) begin
            vga_horiz <= 10'd0;
            vga_vert <= 10'd0;
	    VGA_CLK <= 1'b0;

        end else begin
            /*
             * VGA horizontal and vertical counters.
             */
            if (phase[1] == 1'b1) begin
                if (vga_horiz >= H_SYNC_TOTAL) begin

                    vga_horiz <= 10'd0; 

                    if (vga_vert >= V_SYNC_TOTAL) begin
                        vga_vert <= 10'd0;
                    end else begin
                        vga_vert <= vga_vert + 10'd1;
                    end

                end else begin
                    vga_horiz <= vga_horiz + 10'd1;
                end
            end

            /*
             * Calculate color and control signals.
             */
            if (phase[1] == 1'b1) begin
                if (vga_horiz >= X_START && vga_horiz < X_START+H_SYNC_ACT &&
                    vga_vert >= Y_START && vga_vert < Y_START+V_SYNC_ACT) begin

                    /*
                     * Red:   bits 14-10
                     * Green: bits 9-5
                     * Blue:  bits 4-0
                     * Convert to 8-bit value by repeating the bits.
                     */
                    VGA_R <= {SRAM_DQ[14:10], SRAM_DQ[14:12]};
                    VGA_G <= {SRAM_DQ[9:5], SRAM_DQ[9:7]};
                    VGA_B <= {SRAM_DQ[4:0], SRAM_DQ[4:2]};

                end else begin
                    VGA_R <= 8'b0;
                    VGA_G <= 8'b0;
                    VGA_B <= 8'b0;
                end

                if (vga_horiz < H_SYNC_CYC) begin
                    VGA_HS <= 1'b0; 
                end else begin
                    VGA_HS <= 1'b1; 
                end

                if (vga_vert < V_SYNC_CYC) begin
                    VGA_VS <= 1'b0; 
                end else begin
                    VGA_VS <= 1'b1; 
                end

                if (vga_horiz < H_SYNC_CYC || vga_vert < V_SYNC_CYC) begin
                    VGA_BLANK_N <= 1'b0;
                end else begin
                    VGA_BLANK_N <= 1'b1;
                end

            end

            /*
             * Remember the color to write to SRAM.
             */
            if (phase[1] == 1'b1) begin
		if (cpu_write_active == 1'b1) begin
		    sram_color <= vga_color_write;
		end else if (camera_active == 1'b1) begin
                    sram_color <= camera_to_vga_color;
                end
            end

	    /*
	     * Update VGA_CLK.
	     */
	    if (phase[0] == 1'b1) begin
		VGA_CLK <= 1'b0;
	    end else if (phase[2] == 1'b1) begin
		VGA_CLK <= 1'b1;
	    end
        end
    end

    always @* begin
        VGA_SYNC_N = 1'b0;
        vga_address_x = vga_horiz - X_START;
        vga_address_y = vga_vert - Y_START;
    end

    /*
     * SRAM
     */
    always @* begin
        SRAM_CE_N = 1'b0; // chip is always enabled
	SRAM_LB_N = 1'b0;
	SRAM_UB_N = 1'b0;
    end

    /*
     * SRAM_DQ needs to be in a separate always @* block from the ones that use
     * SRAM_DQ.  Otherwise the assignment of zzzz will affect the value read
     * from SRAM_DQ.
     */
    always @* begin
        if (SRAM_OE_N == 1'b0) begin
            SRAM_DQ = {16{1'bz}};
        end else begin
            SRAM_DQ = {1'b0, sram_color};
        end
    end

    /*
     * Compute SRAM_WE_N.
     */
    always @(posedge clock_100m) begin
        if (phase[2] == 1'b1 && sram_write == 1'b1) begin
	    SRAM_WE_N <= 1'b0;
	end else begin
	    SRAM_WE_N <= 1'b1;
	end
    end

    /*
     * Compute SRAM_ADDR and SRAM_OE_N.
     */
    always @(posedge clock_100m) begin
	case (phase)
	    4'b1000: begin
		SRAM_ADDR[19:0] <= {vga_address_y[9:0], vga_address_x[9:0]};
		SRAM_OE_N <= 1'b0;
	    end

	    4'b0010: begin
	        if (cpu_write_active == 1'b1 || cpu_read_active == 1'b1) begin
		    SRAM_ADDR[19:0] <= {cpu_address_y[9:0], cpu_address_x[9:0]};
	        end else if (camera_active == 1'b1) begin
		    SRAM_ADDR[19:0] <= {camera_to_vga_y[9:0], camera_to_vga_x[9:0]};
		end

	        if (cpu_write_active == 1'b1 || camera_active == 1'b1) begin
		    SRAM_OE_N <= 1'b1;
		end
	    end

	    default: begin
	    end
        endcase
    end

    /*
     * CPU path
     */
    always @(posedge clock_100m) begin
        if (clock_valid == 1'b0) begin
        end else if (cpu_address_load == 1'b1) begin
            cpu_address_x <= vga_x1;
            cpu_address_y <= vga_y1;
	    cpu_done <= 1'b0;
        end else if (cpu_write_active == 1'b1 && phase[2] == 1'b1) begin
	    if (cpu_address_x == vga_x2) begin
		if (cpu_address_y != vga_y2) begin
		    cpu_address_x <= vga_x1;
		    cpu_address_y <= cpu_address_y + 10'd1;
		end else begin
		    cpu_done <= 1'b1;
		end
	    end else begin
		cpu_address_x <= cpu_address_x + 10'd1;
	    end
        end

        if (cpu_read_active == 1'b1 && phase[3] == 1'b1) begin
            vga_color_read <= SRAM_DQ[14:0];
        end

        // register vga_response to prevent glitches
        if (reset_100m == 1'b1 || vga_response_clear == 1'b1) begin
            vga_response <= 1'b0;
        end else if (vga_response_set == 1'b1) begin
            vga_response <= 1'b1;
        end

        if (reset_100m == 1'b1 || return_to_write_clear == 1'b1) begin
            return_to_write <= 1'b0;
        end else if (cpu_write_active == 1'b1) begin
            return_to_write <= 1'b1;
        end
    end

    /*
     * Compute camera_to_vga_ack.
     */
    always @(posedge clock_100m) begin
        if (clock_valid == 1'b0) begin
        end else if (reset_100m == 1'b1) begin
            camera_to_vga_ack <= 1'b0;
        end else if (camera_active == 1'b1 && phase[1] == 1'b1) begin
            camera_to_vga_ack <= 1'b1;
        end else begin
            camera_to_vga_ack <= 1'b0;
        end
    end

    /*
     * Main state machine.
     */
    parameter state_reset =     3'h0;
    parameter state_idle =      3'h1;
    parameter state_write =     3'h2;
    parameter state_read =      3'h3;
    parameter state_response =  3'h4;
    parameter state_camera =    3'h5;

    always @* begin
        next_state = state_idle;

	cpu_write_active = 1'b0;
	cpu_read_active = 1'b0;
        camera_active = 1'b0;

        cpu_address_load = 1'b0;

	sram_write = 1'b0;

        vga_response_clear = 1'b0;
        vga_response_set = 1'b0;

        return_to_write_clear = 1'b0;

        case (state)

            state_reset: begin
                next_state = state_idle;
            end

            state_idle: begin
                vga_response_clear = 1'b1;
                cpu_address_load = 1'b1;    // get ready in case it's needed

                if (camera_to_vga_valid == 1'b1) begin
                    next_state = state_camera;
                end else if (vga_command == 1'b0) begin
                    next_state = state_idle;
                end else if (vga_write == 1'b0) begin
                    next_state = state_read;
                end else if (vga_x1 > vga_x2 || vga_y1 > vga_y2) begin
                    /*
                     * Don't change any pixels for negatively sized rectangle,
                     * but do finish the I/O protocol.
                     */
                    next_state = state_response;
                end else begin
                    next_state = state_write;
                end
            end

            /*
             * Write data from E100 to SRAM.
             */
            state_write: begin
	        sram_write = 1'b1;
                cpu_write_active = 1'b1;
                /*
                 * First check for end of write, so camera states don't
                 * need to check for end of write.  Camera data can wait
                 * until the ack states.
                 */
                if (cpu_done == 1'b1) begin
                    next_state = state_response;
                end else if (camera_to_vga_valid == 1'b1) begin
                    next_state = state_camera;
                end else begin
                    next_state = state_write;
                end
            end

            /*
             * Read data from SRAM to E100.  No need to check for camera
             * input while reading data--just wait until we get back to
             * state_response (which adds finite delay).
             */
            state_read: begin
	        cpu_read_active = 1'b1;
                next_state = state_response;
            end

            /*
             * Write data from camera controller to SRAM.
             */
            state_camera: begin
		sram_write = 1'b1;
		camera_active = 1'b1;

                if (camera_to_vga_valid == 1'b1) begin
                    next_state = state_camera;
                end else if (return_to_write == 1'b1) begin
                    next_state = state_write;
                end else if (vga_response == 1'b1) begin
                    next_state = state_response;
                end else begin
                    next_state = state_idle;
                end
            end

            /*
             * Respond to E100.
             */
            state_response: begin
                vga_response_set = 1'b1;
                return_to_write_clear = 1'b1;
                if (camera_to_vga_valid == 1'b1) begin
                    next_state = state_camera;
                end else if (vga_command == 1'b0) begin
                    next_state = state_idle;
                end else begin
                    next_state = state_response;
                end
            end

	    default: begin
	    end

        endcase
    end

    /*
     * Compute next phase and state.
     */
    always @(posedge clock_100m) begin
        if (clock_valid == 1'b0) begin
        end else if (reset_100m == 1'b1) begin
            state <= state_reset;
	    phase <= 4'b00000001;
        end else begin
	    if (phase[3] == 1'b1) begin
		state <= next_state;
	    end
	    phase[3:1] <= phase[2:0];
	    phase[0] <= phase[3];
        end

    end

endmodule
