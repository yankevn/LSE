/*
 * Copyright (c) 2006, Peter M. Chen.  All rights reserved.  This software is
 * supplied as is without expressed or implied warranties of any kind.
 */

/*
 * SDRAM controller (two ISSI IS42S16320-7 chips, each 32M x 16bit)
 */
module sdram(
    input wire osc_50,
    input wire clock_195k,
    input wire clock_valid,
    input wire reset_50m,
    input wire sdram_command,
    output reg sdram_response,
    input wire sdram_write,
    input wire [24:0] sdram_address,	// address of SDRAM location being accessed
    input wire [31:0] sdram_data_write,	// data to write to sdram
    output reg [31:0] sdram_data_read,	// data read from sdram
    output reg [12:0] DRAM_ADDR,
    output reg [1:0] DRAM_BA,
    output reg DRAM_CS_N,
    output reg DRAM_RAS_N,
    output reg DRAM_CAS_N,
    output reg DRAM_WE_N,
    output reg DRAM_CKE,
    output reg DRAM_CLK,
    inout reg [31:0] DRAM_DQ,
    output reg [3:0] DRAM_DQM);

    reg [4:0] refresh_needed;
    reg refresh_needed_set8;
    reg refresh_needed_decr;

    /*
     * Force power-up value to be 0.
     */
    (* altera_attribute = "-name POWER_UP_LEVEL LOW" *) reg initialized;

    reg initialized_set;

    wire clock_195k_sync;
    reg clock_195k_sync_last;
    reg clock_195k_sync_last1;

    reg response_set;
    reg response_clear;

    reg dq_write;
    reg sdram_data_read_write;			// latch data from sdram

    reg [5:0] state;
    reg [5:0] next_state;

    parameter state_reset =    5'h0;
    parameter state_init1 =    5'h1;
    parameter state_init2 =    5'h2;
    parameter state_init3 =    5'h3;
    parameter state_init4 =    5'h4;
    parameter state_idle =     5'h5;
    parameter state_read1 =    5'h6;
    parameter state_read2 =    5'h7;
    parameter state_read3 =    5'h8;
    parameter state_read4 =    5'h9;
    parameter state_read5 =    5'ha;
    parameter state_write1 =   5'hb;
    parameter state_write2 =   5'hc;
    parameter state_write3 =   5'hd;
    parameter state_refresh1 = 5'he;
    parameter state_refresh2 = 5'hf;
    parameter state_refresh3 = 5'h10;
    parameter state_refresh4 = 5'h11;
    parameter state_refresh5 = 5'h12;
    parameter state_response = 5'h13;

    synchronizer #(.WIDTH(1)) u1 (osc_50, clock_195k, clock_195k_sync);

    always @* begin
        if (dq_write == 1'b1) begin
	    DRAM_DQ = sdram_data_write;
	end else begin
	    DRAM_DQ = {32{1'bz}};
	end
    end

    always @(posedge osc_50) begin
        if (clock_valid == 1'b1) begin
	    /*
	     * Only initialize once.  This allows the SDRAM to keep refreshing
	     * while the rest of the system is in reset.
	     *
	     * No need to force FSM to a particular state when the rest of
	     * the system resets.  The FSM will naturally progress to
	     * state_idle (even in state_response, since sdram_command will be 0
	     * in reset).
	     */
	    if (reset_50m == 1'b1 && initialized == 1'b0) begin
	        refresh_needed <= 5'h0;
		sdram_response <= 1'b0;
	        state <= state_reset;

	    end else begin
		/*
		 * Refresh of all (8192) rows must occur at least every 64 ms.
		 * 1 row every 7.8125 us ==> 128 KHz, so 195 KHz should be safe.
		 */
		if (refresh_needed_set8 == 1'b1) begin
		    refresh_needed <= 5'h8;
		end else if (clock_195k_sync_last1 == 1'b0
		        && clock_195k_sync_last == 1'b1
			&& refresh_needed != 5'h1f) begin
		    refresh_needed <= refresh_needed + 5'h1;
		end else if (refresh_needed_decr == 1'b1) begin
		    refresh_needed <= refresh_needed - 5'h1;
		end

		if (response_set == 1'b1) begin
		    sdram_response <= 1'b1;
		end else if (response_clear == 1'b1) begin
		    sdram_response <= 1'b0;
		end

		if (initialized_set == 1'b1) begin
		    initialized <= 1'b1;
		end

		if (sdram_data_read_write == 1'b1) begin
		    sdram_data_read <= DRAM_DQ;
		end

		clock_195k_sync_last1 <= clock_195k_sync_last;
		clock_195k_sync_last <= clock_195k_sync;

	        state <= next_state;

	    end
	end
    end

    always @* begin
        /*
	 * Default values for control signals.
	 */
	DRAM_CLK = osc_50;
	DRAM_CS_N = 1'b0;
	DRAM_CKE = 1'b1;
	DRAM_DQM[3:0] = 4'h0;

	DRAM_RAS_N = 1'b1;
	DRAM_CAS_N = 1'b1;
	DRAM_WE_N = 1'b1;

	/*
	 * sdram_address[24:23] select the bank
	 * sdram_address[22:10] select the row
	 * sdram_address[9:0] select the column
	 */
	DRAM_BA[1:0] = sdram_address[24:23];
	DRAM_ADDR[12:0] = sdram_address[22:10];

	initialized_set = 1'b0;
	response_set = 1'b0;
	response_clear = 1'b0;
	refresh_needed_set8 = 1'b0;
	refresh_needed_decr = 1'b0;
	dq_write = 1'b0;
	sdram_data_read_write = 1'b0;

	next_state = state_reset;

	case (state)

	    state_reset: begin
		next_state = state_init1;
	    end

	    state_init1: begin
		/*
		 * Wait at least 100 us, i.e. about 20 refresh cycles (assuming
		 * refresh happens at 195 KHz).  Wait 32 refresh cycles to be safe.
		 * Issue NOP during this period.
		 */
		if (refresh_needed < 5'h1f) begin
		    next_state = state_init1;
		end else begin
		    next_state = state_init2;
		end
	    end

	    state_init2: begin
		/*
		 * Precharge all banks (takes 20 ns => 2 cycles (to be safe)).
		 * Also ask for 8 refreshes.
		 */
		DRAM_RAS_N = 1'b0;
		DRAM_WE_N = 1'b0;
		DRAM_ADDR[10] = 1'b1;
		refresh_needed_set8 = 1'b1;
		next_state = state_init3;
	    end

	    state_init3: begin
	        /*
		 * Idle cycle to make sure that precharge of all banks is
		 * complete.
		 */
		next_state = state_refresh1;
	    end

	    state_init4: begin
		/*
		 * Mode register set: CAS latency 2, burst length 1.
		 * Takes 14 ns => 1 cycle.
		 */
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b0;
		DRAM_BA[1:0] = 2'b0;
		DRAM_ADDR[12:11] = 2'b0;
		DRAM_ADDR[10] = 1'b0;
		DRAM_ADDR[9] = 1'b1;
		DRAM_ADDR[8:7] = 2'b0;
		DRAM_ADDR[6:4] = 3'b010;
		DRAM_ADDR[3] = 1'b0;
		DRAM_ADDR[2:0] = 3'b0;
		initialized_set = 1'b1;
		next_state = state_idle;
	    end

	    state_idle: begin
		response_clear = 1'b1;
		
		if (refresh_needed != 5'h0) begin
		    next_state = state_refresh1;
		end else if (sdram_command == 1'b0) begin
		    next_state = state_idle;
		end else if (sdram_write == 1'b0) begin
		    next_state = state_read1;
		end else begin
		    next_state = state_write1;
		end
	    end

	    state_read1: begin
		/*
		 * Activate bank (takes 20 ns => 2 cycles (to be safe)).
		 */
		DRAM_RAS_N = 1'b0;
		next_state = state_read2;
	    end

	    state_read2: begin
		next_state = state_read3;
	    end

	    state_read3: begin
		/*
		 * Read with auto-precharge.  Data is ready 2 cycles later (with
		 * CAS latency 2 cycles).  Auto precharge happens simultaneously.
		 */
		DRAM_CAS_N = 1'b0;
		DRAM_ADDR[10] = 1'b1;
		DRAM_ADDR[9:0] = sdram_address[9:0];
		next_state = state_read4;
	    end

	    state_read4: begin
		next_state = state_read5;
	    end

	    state_read5: begin
		/*
		 * Latch the data read from the sdram.
		 */
		sdram_data_read_write = 1'b1;
		next_state = state_response;
	    end

	    state_write1: begin
		/*
		 * Activate bank (takes 20 ns => 2 cycles (to be safe)).
		 */
		DRAM_RAS_N = 1'b0;
		next_state = state_write2;
	    end

	    state_write2: begin
		next_state = state_write3;
	    end

	    state_write3: begin
		/*
		 * Write with auto-precharge.  Data is ready 2 cycles later (with
		 * CAS latency 2 cycles).  Auto precharge happens simultaneously.
		 */
		DRAM_CAS_N = 1'b0;
		DRAM_WE_N = 1'b0;

		DRAM_ADDR[10] = 1'b1;
		DRAM_ADDR[9:0] = sdram_address[9:0];
		dq_write = 1'b1;
		next_state = state_response;
	    end

	    state_refresh1: begin
		/*
		 * Auto refresh (takes 70 ns => 4 cycles).
		 */
		refresh_needed_decr = 1'b1;
		DRAM_RAS_N = 1'b0;
		DRAM_CAS_N = 1'b0;
		next_state = state_refresh2;
	    end

	    state_refresh2: begin
		next_state = state_refresh3;
	    end

	    state_refresh3: begin
		next_state = state_refresh4;
	    end

	    state_refresh4: begin
		next_state = state_refresh5;
	    end

	    state_refresh5: begin
		if (refresh_needed != 5'h0) begin
		    next_state = state_refresh1;
		end else if (initialized == 1'b0) begin
		    next_state = state_init4;
		end else if (sdram_response == 1'b1) begin
		    next_state = state_response;
		end else begin
		    next_state = state_idle;
		end
	    end

	    state_response: begin
		response_set = 1'b1;
		if (refresh_needed != 5'h0) begin
		    next_state = state_refresh1;
		end else if (sdram_command == 1'b1) begin
		    next_state = state_response;
		end else begin
		    next_state = state_idle;
		end
	    end

	endcase
    end

endmodule
