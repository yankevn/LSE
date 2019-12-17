/*
 * Copyright (c) 2011, Mark Wu and Peter M. Chen.  All rights
 * reserved.  This software is supplied as is without expressed or implied
 * warranties of any kind.
 */
module sd(
    input wire osc_50,
    input wire clock_valid,
    input wire reset_50m,

    //SD Card Signals
    inout wire SD_CMD,
    inout reg SD_DAT3,
    inout wire SD_DAT,
    output wire SD_CLK,

    //Interface to CPU
    input wire sd_command,
    output reg sd_response,
    input wire sd_write,
    input wire [29:0] sd_address,	// (Word) address requested by E100
    input wire [31:0] sd_data_write,
    output reg [31:0] sd_data_read
);

// Addresses for SD card IP core registers.  Addresses are in units of
// 32-bit Avalon words.
parameter RXTX_BUFFER = 8'd0;
parameter CMD_ARG     = 8'd139;
parameter CMD         = 8'd140;
parameter ASR         = 8'd141;
parameter RR1         = 8'd142;

// Command numbers for SD card IP core
parameter READ_BLOCK = 32'h0011;
parameter WRITE_BLOCK = 32'h0018;
/*
 * Don't need a separate erase command for this IP core.  The note in
 * [Altera09] on the BLK_ERASE_COUNT command implies that the default behavior
 * is to erase 1 block before writing.
 */

reg i_avalon_chip_select;
reg i_avalon_chip_select_sync;
reg [7:0] i_avalon_address;
reg [7:0] i_avalon_address_sync;
reg [31:0] i_avalon_writedata;
reg [31:0] i_avalon_writedata_sync;
reg [31:0] o_avalon_readdata;
reg [31:0] o_avalon_readdata_sync;
reg [3:0] i_avalon_byteenable;
reg [3:0] i_avalon_byteenable_sync;
reg i_avalon_read;
reg i_avalon_read_sync;
reg i_avalon_write;
reg i_avalon_write_sync;
reg o_avalon_waitrequest;

reg [22:0] buffer_sector;               // Sector number of data in buffer (sector
                                        // has 512 bytes = 128 words)
reg buffer_sector_write;
reg buffer_valid;                       // Has buffer_sector been initialized?

reg buffer_dirty;                       // Does the data in buffer_sector need to
                                        // be written back to the SD card?
reg buffer_dirty_clear;
reg buffer_dirty_set;

reg sd_data_read_write;                 // controls the writing of sd_data_read

reg response_set;
reg response_clear;

reg [4:0] state;
reg [4:0] next_state;

/*
 * Use the Secure Data Card IP Core from Altera's University Program [altera09]
 */
Altera_UP_SD_Card_Avalon_Interface u1(
    .i_clock (osc_50),
    .i_reset_n (~reset_50m),
    .i_avalon_address (i_avalon_address_sync),
    .i_avalon_chip_select (i_avalon_chip_select_sync),
    .i_avalon_read (i_avalon_read_sync),
    .i_avalon_write (i_avalon_write_sync),
    .i_avalon_byteenable (i_avalon_byteenable_sync),
    .i_avalon_writedata (i_avalon_writedata_sync),
    .o_avalon_readdata (o_avalon_readdata),
    .o_avalon_waitrequest (o_avalon_waitrequest),
    .b_SD_cmd (SD_CMD),
    .b_SD_dat (SD_DAT),
    .b_SD_dat3 (SD_DAT3),
    .o_SD_clock (SD_CLK));

always @ (posedge osc_50) begin
    if (~clock_valid) begin
    end else if (reset_50m == 1'b1) begin
        state <= state_reset;
    end else begin
        state <= next_state;
    end

    if (i_avalon_read_sync == 1'b1) begin
        o_avalon_readdata_sync <= o_avalon_readdata;
    end

    i_avalon_chip_select_sync <= i_avalon_chip_select;
    i_avalon_address_sync <= i_avalon_address;
    i_avalon_writedata_sync <= i_avalon_writedata;
    i_avalon_byteenable_sync <= i_avalon_byteenable;
    i_avalon_read_sync <= i_avalon_read;
    i_avalon_write_sync <= i_avalon_write;

    if (reset_50m == 1'b1) begin
        buffer_valid <= 1'b0;
        buffer_sector <= 23'h0;
    end else if (buffer_sector_write == 1'b1) begin
        buffer_valid <= 1'b1;
        buffer_sector <= sd_address[29:7];
    end

    if (reset_50m == 1'b1) begin
        buffer_dirty <= 1'b0;
    end else if (buffer_dirty_clear == 1'b1) begin
        buffer_dirty <= 1'b0;
    end else if (buffer_dirty_set == 1'b1) begin
        buffer_dirty <= 1'b1;
    end

    if (sd_data_read_write == 1'b1) begin
	sd_data_read <= o_avalon_readdata_sync;
    end

    if (reset_50m == 1'b1) begin
        sd_response <= 1'b0;
    end else if (response_set == 1'b1) begin
        sd_response <= 1'b1;
    end else if (response_clear == 1'b1) begin
        sd_response <= 1'b0;
    end
end

parameter state_reset          = 5'h00;
parameter state_init1          = 5'h01;
parameter state_init2          = 5'h02;
parameter state_init3          = 5'h03;
parameter state_idle           = 5'h04;
parameter state_write_sdcard1  = 5'h05;
parameter state_write_sdcard2  = 5'h06;
parameter state_write_sdcard3  = 5'h07;
parameter state_write_sdcard4  = 5'h08;
parameter state_write_sdcard5  = 5'h09;
parameter state_write_sdcard6  = 5'h0a;
parameter state_write_sdcard7  = 5'h0b;
parameter state_write_sdcard8  = 5'h0c;
parameter state_write_sdcard9  = 5'h0d;
parameter state_write_sdcard10 = 5'h0e;
parameter state_read_sdcard1   = 5'h0f;
parameter state_read_sdcard2   = 5'h10;
parameter state_read_sdcard3   = 5'h11;
parameter state_read_sdcard4   = 5'h12;
parameter state_read_sdcard5   = 5'h13;
parameter state_read_sdcard6   = 5'h14;
parameter state_read_sdcard7   = 5'h15;
parameter state_read_sdcard8   = 5'h16;
parameter state_read_sdcard9   = 5'h17;
parameter state_read_sdcard10  = 5'h18;
parameter state_write_buffer1  = 5'h19;
parameter state_write_buffer2  = 5'h1a;
parameter state_write_buffer3  = 5'h1b;
parameter state_read_buffer1   = 5'h1c;
parameter state_read_buffer2   = 5'h1d;
parameter state_read_buffer3   = 5'h1e;
parameter state_response       = 5'h1f;

/*
 * State machine
 */
always @* begin
    /*
     * Default values for control signals
     */
    i_avalon_chip_select = 1'b1;
    i_avalon_address = 8'b0;
    i_avalon_writedata = 32'b0;
    i_avalon_byteenable = 4'b1111;
    i_avalon_read = 1'b0;
    i_avalon_write = 1'b0;
    buffer_sector_write = 1'b0;
    buffer_dirty_clear = 1'b0;
    buffer_dirty_set = 1'b0;
    sd_data_read_write = 1'b0;
    response_set = 1'b0;
    response_clear = 1'b0;
    next_state = state_reset;

    case (state)

        state_reset: begin
            next_state = state_init1;
        end

        /*
         * Wait for SD card to be ready to access (ASR[1]==1)
         */
        state_init1: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            next_state = state_init2;
        end

        state_init2: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_init2;
            end else begin
                next_state = state_init3;
            end
        end

        /*
         * Is SD card ready for access (ASR[1]==1)?
         * Also serves as idle cycle on Avalon bus.
         */
        state_init3: begin
            if (o_avalon_readdata_sync[1] == 1'b1) begin
                next_state = state_idle;
            end else begin
                next_state = state_init1;
            end
        end

        state_idle: begin
            response_clear = 1'b1;

            if (sd_command == 1'b0) begin
                next_state = state_idle;

            end else if (buffer_valid == 1'b1 &&
                         buffer_sector == sd_address[29:7]) begin
                if (sd_write == 1'b1) begin
                    next_state = state_write_buffer1;
                end else begin
                    next_state = state_read_buffer1;
                end

            end else if (buffer_valid == 1'b1 && buffer_dirty == 1'b1) begin
                next_state = state_write_sdcard1;

            end else begin
                next_state = state_read_sdcard1;
            end
        end

        /*
         * Write the RXTX buffer back to the SD card.
         */

        /*
         * Write the (byte) address of the current sector in the RXTX buffer
         * to CMD_ARG.  This isn't really needed, since CMD_ARG should have
         * this address from the last read.
         */
        state_write_sdcard1: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD_ARG;
            i_avalon_writedata[31:9] = buffer_sector;
            i_avalon_writedata[8:0] = 9'h0;
            next_state = state_write_sdcard2;
        end

        state_write_sdcard2: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD_ARG;
            i_avalon_writedata[31:9] = buffer_sector;
            i_avalon_writedata[8:0] = 9'h0;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_write_sdcard2;
            end else begin
                next_state = state_write_sdcard3;
            end
        end

        /*
         * Idle cycle on Avalon bus (just to be safe).
         */
        state_write_sdcard3: begin
            next_state = state_write_sdcard4;
        end
        
        state_write_sdcard4: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD;
            i_avalon_byteenable = 4'b0011;
            i_avalon_writedata = WRITE_BLOCK;
            next_state = state_write_sdcard5;
        end

        state_write_sdcard5: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD;
            i_avalon_byteenable = 4'b0011;
            i_avalon_writedata = WRITE_BLOCK;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_write_sdcard5;
            end else begin
                next_state = state_write_sdcard6;
            end
        end

        /*
         * Idle cycle on Avalon bus (just to be safe).
         */
        state_write_sdcard6: begin
            next_state = state_write_sdcard7;
        end
        
        /*
         * Read ASR[2] to see if command is still in progress
         */
        state_write_sdcard7: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            next_state = state_write_sdcard8;
        end

        state_write_sdcard8: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_write_sdcard8;
            end else begin
                next_state = state_write_sdcard9;
            end
        end
        
        /*
         * Did last write complete (ASR[2]==0)?
         * Also serves as idle cycle on Avalon bus.
         */
        state_write_sdcard9: begin
            if (o_avalon_readdata_sync[0] == 1'b0 ||
                    o_avalon_readdata_sync[1] == 1'b0 ||
                    o_avalon_readdata_sync[4] == 1'b1) begin
                // Some error occurred.  Try again.
                next_state = state_write_sdcard1;

            end else if (o_avalon_readdata_sync[2] == 1'b1) begin
                // Write still in progress.
                next_state = state_write_sdcard7;

            end else begin
                // Write completed.
                next_state = state_write_sdcard10;
            end
        end

        /*
         * Clear buffer_dirty.
         */
        state_write_sdcard10: begin
            buffer_dirty_clear = 1'b1;
            next_state = state_read_sdcard1;
        end

        /*
         * Read the relevant sector into the RXTX buffer
         */

        /*
         * Write the (byte) address of the desired sector to CMD_ARG
         */
        state_read_sdcard1: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD_ARG;
            i_avalon_writedata[31:9] = sd_address[29:7];
            i_avalon_writedata[8:0] = 9'h0;
            next_state = state_read_sdcard2;
        end

        state_read_sdcard2: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD_ARG;
            i_avalon_writedata[31:9] = sd_address[29:7];
            i_avalon_writedata[8:0] = 9'h0;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_read_sdcard2;
            end else begin
                next_state = state_read_sdcard3;
            end
        end

        /*
         * Idle cycle on Avalon bus (just to be safe).
         */
        state_read_sdcard3: begin
            next_state = state_read_sdcard4;
        end
        
        state_read_sdcard4: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD;
            i_avalon_byteenable = 4'b0011;
            i_avalon_writedata = READ_BLOCK;
            next_state = state_read_sdcard5;
        end

        state_read_sdcard5: begin
            i_avalon_write = 1'b1;
            i_avalon_address = CMD;
            i_avalon_byteenable = 4'b0011;
            i_avalon_writedata = READ_BLOCK;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_read_sdcard5;
            end else begin
                next_state = state_read_sdcard6;
            end
        end

        /*
         * Idle cycle on Avalon bus (just to be safe).
         */
        state_read_sdcard6: begin
            next_state = state_read_sdcard7;
        end
        
        /*
         * Read ASR[2] to see if command is still in progress
         */
        state_read_sdcard7: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            next_state = state_read_sdcard8;
        end

        state_read_sdcard8: begin
            i_avalon_read = 1'b1;
            i_avalon_byteenable = 4'b0011;
            i_avalon_address = ASR;
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_read_sdcard8;
            end else begin
                next_state = state_read_sdcard9;
            end
        end
        
        /*
         * Did last read complete (ASR[2]==0)?
         * Also serves as idle cycle on Avalon bus.
         */
        state_read_sdcard9: begin
            if (o_avalon_readdata_sync[0] == 1'b0 ||
                    o_avalon_readdata_sync[1] == 1'b0 ||
                    o_avalon_readdata_sync[4] == 1'b1) begin
                // Some error occurred.  Try again.
                next_state = state_read_sdcard1;

            end else if (o_avalon_readdata_sync[2] == 1'b1) begin
                // Read still in progress.
                next_state = state_read_sdcard7;

            end else begin
                // Read completed.
                next_state = state_read_sdcard10;
            end
        end

        /*
         * Update buffer_sector.
         */
        state_read_sdcard10: begin
            buffer_sector_write = 1'b1;
            if (sd_write == 1'b1) begin
                next_state = state_write_buffer1;
            end else begin
                next_state = state_read_buffer1;
            end
        end

        /*
         * Write sd_data_write to RXTX buffer.
         */
        state_write_buffer1: begin
            i_avalon_write = 1'b1;
            i_avalon_writedata = sd_data_write;
            // Avalon addresses are in units of 32 bits
            i_avalon_address = RXTX_BUFFER + sd_address[6:0];
            next_state = state_write_buffer2;
        end

        state_write_buffer2: begin
            i_avalon_write = 1'b1;
            i_avalon_writedata = sd_data_write;
            // Avalon addresses are in units of 32 bits
            i_avalon_address = RXTX_BUFFER + sd_address[6:0];

            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_write_buffer2;
            end else begin
                next_state = state_write_buffer3;
            end
        end

        /*
         * Set buffer_dirty.
         * Also serves as idle cycle on Avalon bus.
         */
        state_write_buffer3: begin
            buffer_dirty_set = 1'b1;
            next_state = state_response;
        end
        
        /*
         * Read relevant 32-bit Avalon word from RXTX buffer to
         * o_avalon_readdata_sync
         */
        state_read_buffer1: begin
            i_avalon_read = 1'b1;
            // Avalon addresses are in units of 32 bits
            i_avalon_address = RXTX_BUFFER + sd_address[6:0];
            next_state = state_read_buffer2;
        end

        state_read_buffer2: begin
            i_avalon_read = 1'b1;
            // Avalon addresses are in units of 32 bits
            i_avalon_address = RXTX_BUFFER + sd_address[6:0];
            if (o_avalon_waitrequest == 1'b1) begin
                next_state = state_read_buffer2;
            end else begin
                next_state = state_read_buffer3;
            end
        end

        /*
         * Copy E100 word from o_avalon_readdata_sync.
         * Also serves as idle cycle on Avalon bus.
         */
        state_read_buffer3: begin
            sd_data_read_write = 1'b1;
            next_state = state_response;
        end

        state_response: begin
            response_set = 1'b1;
            if (sd_command == 1'b1) begin
                next_state = state_response;
            end else begin
                next_state = state_idle;
            end
        end

    endcase
end

endmodule
