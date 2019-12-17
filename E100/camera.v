/*
 * Copyright (c) 2010, Benjamin Kempke and Peter M. Chen.  All rights
 * reserved.  This software is supplied as is without expressed or implied
 * warranties of any kind.
 */
module camera(
    input clock_100m,
    input clock_valid,
    input reset,

    //Interface to ADV7180 codec
    input i2c_done,
    output reg TD_RESET_N,
    input TD_CLK27,
    input [7:0] TD_DATA,

    //Camera controller -> VGA controller interface
    output camera_to_vga_valid,
    input camera_to_vga_ack,
    output [9:0] camera_to_vga_x,
    output [9:0] camera_to_vga_y,
    output [14:0] camera_to_vga_color,

    //Camera controller -> E100 interface
    input camera_command,
    output reg camera_response,
    input [9:0] camera_x,
    input [9:0] camera_y,
    input [1:0] camera_scale,
    input camera_flip
);

//Window-size specifications
parameter start_x = 10'd12;
parameter start_y = 9'd22;
parameter end_x = 10'd650;
parameter end_y = 9'd503;

parameter size_x = 10'd640;

//Internal camera controller signals
wire vdf_rdempty;
wire vdf_wrfull;
wire [34:0] vdf_q;

//Definition and assignment of camera -> vga controller interface signals
assign camera_to_vga_valid = ~vdf_rdempty;
assign camera_to_vga_y = vdf_q[34:25];
assign camera_to_vga_x = vdf_q[24:15];
assign camera_to_vga_color = vdf_q[14:0];

/*
 * YCbCr to RGB Converter
 *   Input data from ADV7180 is in YCbCr format.  This is then passed through
 *   this converter block to yield data in the desired RGB format
 */
reg [7:0] cb, y1, cr, y2;
wire [7:0] y = (camera_x_pos) ? y2 : y1;
wire pixel_write;
wire convert_done;
wire [9:0] red, green, blue;
reg xoff_delayed;
reg [3:0] xoff_delay;
YCbCr2RGB cnv(
    .iY(y),
    .iCb(cb),
    .iCr(cr),
    .iDVAL(pixel_write),
    .oDVAL(convert_done),
    .iRESET(reset),
    .iCLK(clock_100m),
    .Red(red),
    .Green(green),
    .Blue(blue)
);

/*
 * Camera FIFO
 *   Handles data buffering and forwarding to VGA controller's SRAM.  It does
 *   not need to be implemented in dual-port mode because everything in this 
 *   module is synchronized to the 100MHz system clock
 */
reg [9:0] camera_x_latched;
reg [9:0] camera_x_pos, camera_abs_x_pos, camera_abs_x_pos_xoff, camera_abs_x_pos_scaled;
reg [9:0] camera_y_latched;
reg [8:0] camera_y_pos, camera_abs_y_pos, camera_abs_y_pos_scaled;
reg store_pixel1, store_pixel2, latch_cam_pos;
reg convert_done_scaled;
reg [26:0] fifo_data;
camera_fifo vdf1(
    .clock(clock_100m),
    .sclr(reset),
    .data(
        {camera_abs_y_pos_scaled + camera_y_latched,
        camera_abs_x_pos_scaled + camera_x_latched,
        red[9:5], green[9:5], blue[9:5]}
        ),
    .rdreq(camera_to_vga_ack),
    .wrreq(convert_done_scaled),
    .q(vdf_q),
    .empty(vdf_rdempty),
    .full(vdf_wrfull)
);

//Camera data interpretation controller
reg [3:0] state, next_state;
reg [23:0] data_shift_in;
reg start_acquisition, acquisition_done;
reg incr_x, incr_x_delayed, incr_x_delayed2, x_lsb_delayed, incr_y, incr_y_delayed;
reg data_valid, reset_x, reset_y;
reg [1:0] byte_counter;
reg td_clk27_meta_old, td_clk27_meta;
assign pixel_write = ((store_pixel1 || store_pixel2) && td_clk27_meta && ~td_clk27_meta_old);
reg halfdone, halfdone_clear, halfdone_set;

reg [23:0] i2c_done_count;

/*
 * Scaling logic
 */
always @* begin
    // scale=0 ==> shift right by 3 bits; mask = 0x7
    // scale=1 ==> shift right by 2 bits; mask = 0x3
    // scale=2 ==> shift right by 1 bits; mask = 0x1
    // scale=3 ==> shift right by 0 bits; mask = 0x0

    camera_abs_x_pos_xoff = {camera_abs_x_pos[8:0],xoff_delayed};

    if (camera_flip == 1'b1) begin
        // horizontally flip the image
        camera_abs_x_pos_scaled = (size_x - camera_abs_x_pos_xoff) >> (2'h3 - camera_scale);
    end else begin
        camera_abs_x_pos_scaled = camera_abs_x_pos_xoff >> (2'h3 - camera_scale);
    end

    camera_abs_y_pos_scaled = camera_abs_y_pos >> (2'h3 - camera_scale);

    if ((camera_abs_x_pos_xoff[6:0] & ((1'b1 << (2'h3 - camera_scale)) - 2'h1)) == 3'h0 &&
            (camera_abs_y_pos[6:0] & ((1'b1 << (2'h3 - camera_scale)) - 2'h1)) == 3'h0) begin
        convert_done_scaled = convert_done;
    end else begin
        convert_done_scaled = 1'b0;
    end
end

/*
 * Data input FSM 
 *   Changes state based upon ITU656 data stream coming from video codec.
 */
parameter state_reset             = 4'd0;
parameter state_idle              = 4'd1;
parameter state_wait_frame_begin  = 4'd2;
parameter state_frame_record1     = 4'd3;
parameter state_frame_record2     = 4'd4;
parameter state_frame_record3     = 4'd5;
parameter state_frame_record4     = 4'd6;
parameter state_frame_record5     = 4'd7;
parameter state_frame_halfdone    = 4'd8;
parameter state_frame_done        = 4'd9;

always @(posedge clock_100m) begin
    //Since there is a 4-cycle total delay through the YCbCr to RGB converter, this is
    // used to represent the LSB of the x-coordinate of the current pixel being output
    // from cnv
    {xoff_delayed, xoff_delay} <= {xoff_delay, store_pixel1};

    //Clock Synchronization Logic
    td_clk27_meta <= TD_CLK27;
    td_clk27_meta_old <= td_clk27_meta;

    // positive edge of line-locked clock (27 MHz)
    if(td_clk27_meta && ~td_clk27_meta_old) begin

        if(reset) begin
            state <= state_reset;
        end else begin
            state <= next_state;

            //Shift in data, searching for control sequences
            //  Ref: http://www.docstoc.com/docs/478402/ITU656
            //  [ITU656_98]
            data_shift_in[23:8] <= data_shift_in[15:0];
            data_shift_in[7:0] <= TD_DATA;

            if(data_shift_in == 24'hff0000 && TD_DATA[7]) begin
                //24'ff0000 is a control sequence, so update accordingly
                //  TD_DATA[6] = interlaced frame
                //    0: first field ==> even video lines (2,4,6,...) ==>
                //       vga rows 1,3,5,...
                //    1: second field ==> odd video lines (1,3,5,...) ==>
                //       vga rows 0,2,4,...
                //  TD_DATA[5] = during field blanking (not outputting pixel data)
                //  TD_DATA[4] = row increment (not outputting pixel data)
                //  TD_DATA[3:0] = protection bits (ignored)

                data_valid <= ~TD_DATA[4] && ~TD_DATA[5];
                byte_counter <= 2'b0;
                camera_x_pos <= 10'b0;

                if(TD_DATA[5]) begin
                    // I think this is set to 0x1fe so that it increments to 0x0
                    camera_y_pos <= 9'h1FE;
                end else if(TD_DATA[4]) begin
                    if(camera_y_pos[8:1] != end_y[8:1]) begin
                        camera_y_pos[8:1] <= camera_y_pos[8:1] + 8'd1;
                    end
                    /*
                     * We're processing the "end of active video (EAV)" timing
                     * reference code (TD_DATA[4]==1), so this control
                     * sequence is for the *prior* row.  The upcoming row will
                     * have an F field value of ~TD_DATA[6].  Thus,
                     * TD_DATA[6]=0 ==> the upcoming row's F=1 ==> field 2 ==>
                     * odd video line (1,3,5,...) ==> even vga row (0,2,4,...).
                     * In the same way, TD_DATA[6]=1 ==> the upcoming row's
                     * F=0 ==> field 1 ==> even video line (2,4,6,...) ==>
                     * odd vga row (1,3,5,...).
                     * The easiest way to see if this is right is by taking
                     * a picture of an almost-horizontal sheet of paper: if
                     * you get this wrong, it will look jagged (since a pair
                     * rows will appear in switched order).
                     */
                    camera_y_pos[0] <= TD_DATA[6];
                end
            end else if(data_valid) begin
                //If current data stream is valid, record YCbCr data
                //  It comes in as {Cb, Y1, Cr, Y2} for two pixels worth of data
                byte_counter <= byte_counter + 2'b1;

                if(byte_counter == 2'd0) begin
                    cb <= TD_DATA;
                    camera_x_pos <= camera_x_pos + 10'b1;
                end else if(byte_counter == 2'd1) begin
                    y1 <= TD_DATA;
                    camera_x_pos <= camera_x_pos + 10'b1;
                end else if(byte_counter == 2'd2) begin
                    cr <= TD_DATA;
                end else begin
                    y2 <= TD_DATA;
                end
            end

            //Only increment the camera x position every two pixels
            // The LSB of the x position is handled differently (through xoff_delayed)
            incr_x_delayed <= incr_x;
            incr_x_delayed2 <= incr_x_delayed;
            x_lsb_delayed <= camera_x_pos[0];

            if(reset_x) begin
                camera_abs_x_pos <= 10'h0;
            end else if(incr_x_delayed2 && x_lsb_delayed) begin
                camera_abs_x_pos <= camera_abs_x_pos + 10'b1;
            end

            //Increment the y position if requested
            incr_y_delayed <= incr_y;
            if(reset_y) begin
                camera_abs_y_pos[8:1] <= 8'b0;
                camera_abs_y_pos[0] <= camera_y_pos[0];
            end else if(incr_y_delayed) begin
                camera_abs_y_pos[8:1] <= camera_abs_y_pos[8:1] + 8'b1;
                camera_abs_y_pos[0] <= camera_y_pos[0];
            end

            // Note whether the first half-frame (i.e. either the even or
            // odd rows) has been captured.
            if (halfdone_set == 1'b1) begin
                halfdone <= 1'b1;
            end else if (halfdone_clear == 1'b1) begin
                halfdone <= 1'b0;
            end

        end
    end
end

always @* begin
    next_state = state_reset;
    store_pixel1 = 1'b0;
    store_pixel2 = 1'b0;
    incr_x = 1'b0;
    incr_y = 1'b0;
    reset_x = 1'b0;
    reset_y = 1'b0;
    acquisition_done = 1'b0;
    TD_RESET_N = 1'b1;		// ??? do I need to reset the ADV7180 at power up?
    halfdone_clear = 1'b0;
    halfdone_set = 1'b0;

    case(state)
        state_reset: begin
            next_state = state_idle;
        end

        state_idle: begin
            //Wait for a capture frame request from E100
            halfdone_clear = 1'b1;
            if(start_acquisition) begin
                next_state = state_wait_frame_begin;
            end else begin
                next_state = state_idle;
            end
        end

        state_wait_frame_begin: begin
            //We are only interested in a portion of the incoming picture defined by 
            //  start_x, end_x, start_y, and end_y
            reset_x = 1'b1;
            reset_y = 1'b1;
            if(camera_y_pos[8:1] == start_y[8:1] && camera_x_pos == start_x && data_valid) begin
                next_state = state_frame_record1;
            end else begin
                next_state = state_wait_frame_begin;
            end
        end

        state_frame_record1: begin
            //Here, decide if done, starting the interlaced frame, within the defined window, or otherwise
            if(camera_y_pos[8:1] == end_y[8:1]) begin
                if (halfdone == 1'b0) begin
                    // finished capturing all rows of the first half-frame
                    // (either all the even rows or all the odd rows)
                    next_state = state_frame_halfdone;
                end else begin
                    next_state = state_frame_done;
                end
            end else if(camera_y_pos <= end_y && camera_y_pos >= start_y && byte_counter == 2'd3 && data_valid) begin
                next_state = state_frame_record2;
            end else begin
                next_state = state_frame_record1;
            end
        end

        state_frame_record2: begin
            //All four bytes of data stream captured, now queue first pixel for storage
            store_pixel1 = 1'b1;
            incr_x = 1'b1;
            next_state = state_frame_record3;
        end

        state_frame_record3: begin
            //Queue second pixel for storage
            store_pixel2 = 1'b1;
            incr_x = 1'b1;
            if(camera_x_pos < end_x) begin
                next_state = state_frame_record1;
            end else begin
                next_state = state_frame_record4;
            end
        end

        state_frame_record4: begin
            //End of current row has been reached
            incr_y = 1'b1;
            next_state = state_frame_record5;
        end

        state_frame_record5: begin
            //Reset x to start a new row and wait for the new row to start
            reset_x = 1'b1;
            if(camera_x_pos == start_x && data_valid) begin
                next_state = state_frame_record1;
            end else begin
                next_state = state_frame_record5;
            end
        end

        state_frame_halfdone: begin
            halfdone_set = 1'b1;
            next_state = state_wait_frame_begin;
        end

        state_frame_done: begin
            //All pixels for this frame have been written to the pixel FIFO
            acquisition_done = 1'b1;
            if(start_acquisition) begin
                next_state = state_frame_done;
            end else begin
                next_state = state_idle;
            end
        end
    endcase
end

//E100 Interface controller
parameter cpu_state_reset = 3'h0;
parameter cpu_state_idle  = 3'h1;
parameter cpu_state_start = 3'h2;
parameter cpu_state_ack   = 3'h3;
reg next_camera_response;
reg [2:0] cpu_state, next_cpu_state;

always @(posedge clock_100m) begin
    if(~clock_valid) begin
    end else begin
        if(reset) begin
            cpu_state <= cpu_state_reset;
            i2c_done_count <= 24'h0;
        end else begin
            cpu_state <= next_cpu_state;

            if(latch_cam_pos) begin
                camera_x_latched <= camera_x - 10'b1;
                camera_y_latched <= camera_y;
            end

            // wait a few frames (168 ms) before capturing first frame (gives the
            // video dac a chance to synchronize); otherwise the first captured
            // image sometimes has errors (which manifest as restarting the image,
            // i.e. a taller image).
            if (i2c_done && i2c_done_count != 24'hffffff) begin
                i2c_done_count <= i2c_done_count + 24'h1;
            end
        end

    end
    camera_response <= next_camera_response;
end

always @* begin
    next_cpu_state = cpu_state_reset;
    next_camera_response = 1'b0;
    latch_cam_pos = 1'b0;
    start_acquisition = 1'b0;

    case(cpu_state)
        cpu_state_reset: begin
            //Wait for 168ms before allowing frame captures from the video codec
            if (i2c_done_count == 24'hffffff) begin
                next_cpu_state = cpu_state_idle;
            end else begin
                next_cpu_state = cpu_state_reset;
            end
        end

        cpu_state_idle: begin
            //Wait for a valid signal from E100
            latch_cam_pos = 1'b1;
            if(camera_command) begin
                next_cpu_state = cpu_state_start;
            end else begin
                next_cpu_state = cpu_state_idle;
            end
        end

        cpu_state_start: begin
            //Wait for the frame acquisition to be done before proceeding
            start_acquisition = 1'b1;
            if(acquisition_done) begin
                next_cpu_state = cpu_state_ack;
            end else begin
                next_cpu_state = cpu_state_start;
            end
        end

        cpu_state_ack: begin
            next_camera_response = 1'b1;
            // In addition to waiting for !camera_command, also wait for !acquisition_done.
            // This ensures that the camera state machine has gone to state_idle, so the
            // CPU state machine can't start a new acquisition (and raise
            // start_acquisition)
            if(camera_command || acquisition_done) begin
                next_cpu_state = cpu_state_ack;
            end else begin
                next_cpu_state = cpu_state_idle;
            end
        end
    endcase
end

endmodule
