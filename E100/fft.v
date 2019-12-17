/*
 * Copyright (c) 2009, Joshua Smith and Peter M. Chen.  All rights
 * reserved.  This software is supplied as is without expressed or implied
 * warranties of any kind.
 */
 
module fft(
    // normal system ports
    input wire          osc_50,
    input wire          clock_valid,
    input wire          reset_50m,
    
    // CPU interface ports
    // for writing samples
    input wire          fft_send_command,
    output reg          fft_send_response,
    input wire          fft_inverse_in,
    input wire  [15:0]  fft_data_real_in,
    input wire  [15:0]  fft_data_imag_in,
    input wire          fft_data_end_in,
    
    // for reading transform data
    input wire          fft_receive_command,
    output reg          fft_receive_response,
    output reg  [15:0]  fft_data_real_out,
    output reg  [15:0]  fft_data_imag_out,
    output reg          fft_data_end_out);
    
    parameter MAX_SAMPLES = 11'd1024;   // If you change this, remember to also
                                        // change the division by MAX_SAMPLES
                                        // that's implemented as a bit shift
                                        // (search for "divide by MAX_SAMPLES").
                                        // Also change fft_core.v (via the
                                        // megawizard tool).
    
    parameter state_reset         = 4'h0;
    parameter state_wait1         = 4'h1;
    parameter state_wait2         = 4'h2;
    parameter state_wait3         = 4'h3;
    parameter state_wait4         = 4'h4;
    parameter state_write_sop     = 4'h5;
    parameter state_write         = 4'h6;
    parameter state_write_eop     = 4'h7;
    parameter state_wait_sink1    = 4'h8;
    parameter state_wait_sink2    = 4'h9;
    parameter state_wait_read     = 4'ha;
    parameter state_wait_cpu_read = 4'hb;
    parameter state_set_data_end  = 4'hc;
    parameter state_fill          = 4'hd;
    
    parameter cpu_state_reset     = 4'h0;
    parameter cpu_state_idle      = 4'h1;
    parameter cpu_state_add       = 4'h2;
    parameter cpu_state_ack       = 4'h3;
    parameter cpu_state_delay_ack = 4'h4;
    parameter cpu_state_last_ack  = 4'h5;
    parameter cpu_state_read_idle = 4'h6;
    parameter cpu_state_wait_ack0 = 4'h7;
    parameter cpu_state_read_valid= 4'h8;
    parameter cpu_state_consume   = 4'h9;
    parameter cpu_state_flush     = 4'ha;
    
    // used to keep track of if we have data to send to FFT core
    reg           have_data;
    reg           set_have_data;
    reg           clear_have_data;
    
    // used to communicate to CPU state machine that FFT core gave data
    reg           have_read_data;
    reg           sample_consume;
    
    // used to keep track of if this is the first sample (for sop signal)
    reg           first_sample;
    reg           set_first_sample;
    reg           clear_first_sample;
    reg           inverse_write;

    // used to keep track of # samples sent (for eop signal)
    reg   [10:0]  sample_count;
    reg           incr_sample_count;
    reg           reset_sample_count;
    
    // used to reset the FFT at the beginning of a new block
    reg           force_reset;
    reg           set_force_reset;
    reg           clear_force_reset;

    // register input (CPU-> FFT) data
    reg   [15:0]  current_sample_real;
    reg   [15:0]  current_sample_imag;
    reg           current_sample_clear;
    reg           current_sample_write;

    // used for scaling output
    reg   [28:0]  source_real_scaled;
    reg   [28:0]  source_imag_scaled;

    reg           output_data_write;
    reg           prev_eop;
    reg           prev_eop_write;
    reg           set_fft_data_end_out;
    reg           clear_fft_data_end_out;
    reg   [3:0]   state, next_state;
    
    // FFT core inputs
    wire          reset_n = ~reset_50m & ~force_reset;
    reg           inverse;            // assert during sop for inverse transform
    reg           sink_valid;         // data input valid
    reg           sink_sop;           // assert on first sample
    reg           sink_eop;           // assert on last sample
    reg   [15:0]  sink_real;          // data input (real part)
    reg   [15:0]  sink_imag;          // data input (imaginary part)
    reg   [1:0]   sink_error;
    reg           source_ready;       // ready to accept transformed data
    
    // FFT core outputs
    wire          sink_ready;         // ready to accept input data
    wire  [1:0]   source_error;       // error occurred
    wire          source_sop;         // asserted on first transform data
    wire          source_eop;         // asserted on last transform data
    wire          source_valid;       // output data is valid
    wire [5:0]    source_exp;         // scaling exponent for data
    wire [15:0]   source_real;        // data output (real part)
    wire [15:0]   source_imag;        // data output (imaginary part)
    
    // FFT controller state machine
    always @* begin
        // assign safe defaults
        sink_valid          = 1'b0;
        sink_sop            = 1'b0;
        sink_eop            = 1'b0;
        sink_real           = 16'h0;
        sink_imag           = 16'h0;
        sink_error          = 2'h0;
        source_ready        = 1'b0;
        clear_have_data     = 1'b0;
        incr_sample_count   = 1'b0;
        reset_sample_count  = 1'b0;
        set_first_sample    = 1'b0;
        clear_first_sample  = 1'b0;
        output_data_write   = 1'b0;
        have_read_data      = 1'b0;
        set_fft_data_end_out  = 1'b0;
        prev_eop_write      = 1'b0;
        set_force_reset     = 1'b0;
        clear_force_reset   = 1'b0;
        inverse_write       = 1'b0;
        next_state          = state_reset;
        
        case(state)
          state_reset: begin
            clear_have_data     = 1'b1;
            reset_sample_count  = 1'b1;
            next_state          = state_wait1;
          end
          
          // wait for FFT module to assert sink_ready
          state_wait1: begin
            set_first_sample      = 1'b1;
            
            if (sink_ready) begin
              next_state = state_wait2;
            end else begin
              next_state = state_wait1;
            end
          end
          
          // Need to wait till we have data to send to FFT.
          // If it's the first sample, need to assert sop,
          // if it's the last sample, need to assert eop,
          // otherwise just send data
          state_wait2: begin
            if (~have_data) begin
              next_state = state_wait2;
            end else if (sample_count == (MAX_SAMPLES-1)) begin
              next_state = state_write_eop;
            end else if (fft_data_end_in) begin
              next_state = state_fill;
            end else if (first_sample) begin
              next_state =  state_wait3;
            end else begin
              next_state = state_write;
            end
          end
          
          // just assert reset on the FFT module for 2 cycles before sending
          // block of data (to avoid the necessary weird sop/eop behavior)
          state_wait3: begin
            set_force_reset     = 1'b1;
            inverse_write = 1'b1;
            if (force_reset) begin
              next_state = state_wait4;
            end else begin
              next_state = state_wait3;
            end
          end
          state_wait4: begin
            clear_force_reset = 1'b1;
            if (sink_ready) begin
              next_state = state_write_sop;
            end else begin
              next_state = state_wait4;
            end
          end

          // we got all samples from the CPU before MAX_SAMPLES, so just
          // pad with zeros
          state_fill: begin
            sink_valid        = 1'b1;
            incr_sample_count = 1'b1;
            next_state        = state_wait2;
          end

          // write sample and also assert Start of Packet (sop)
          state_write_sop: begin
            clear_first_sample  = 1'b1;
            sink_valid          = 1'b1;
            sink_sop            = 1'b1;
            sink_real           = current_sample_real;

            sink_imag           = current_sample_imag;
            clear_have_data     = 1'b1;
            incr_sample_count   = 1'b1;
            next_state          = state_wait2;
          end
          
          // just write sample
          state_write: begin
            sink_valid        = 1'b1;
            clear_have_data   = 1'b1;
            sink_real         = current_sample_real;
            sink_imag         = current_sample_imag;
            incr_sample_count = 1'b1;
            next_state        = state_wait2;
          end
          
          // write last sample and assert End of Packet (eop)
          state_write_eop: begin
            sink_valid          = 1'b1;
            sink_eop            = 1'b1;
            sink_real           = current_sample_real;
            sink_imag           = current_sample_imag;
            clear_have_data     = 1'b1;
            reset_sample_count  = 1'b1;
            next_state          = state_wait_sink1;
          end
          
          // for some reason the core needs us to send dummy samples, so assert
          // sop again and hold valid until sink_ready goes low
          state_wait_sink1: begin
            sink_valid    = 1'b1;
            sink_sop      = 1'b1;
            sink_real     = 16'h0;
            sink_imag     = 16'h0;
            
            if (~sink_ready) begin
              next_state  = state_wait_read;
            end else begin
              next_state  = state_wait_sink2;
            end
          end

          state_wait_sink2: begin
            sink_valid    = 1'b1;
            sink_real     = 16'h0;
            sink_imag     = 16'h0;
            
            if (~sink_ready) begin
              next_state = state_wait_read;
            end else begin
              next_state = state_wait_sink2;
            end
          end

          // wait until FFT core says data is available (source_valid)
          // Since the first sample comes at the same cycle as source_valid
          // we're going to just write to the fft_data_* output registers
          // (okay since we're not saying data is valid)
          state_wait_read: begin
            source_ready      = 1'b1;
            output_data_write = 1'b1;
            prev_eop_write    = 1'b1;
            
            if (~source_valid) begin
                next_state = state_wait_read;
            // if this is the last sample we need to set data_end_out
            end else if (source_eop) begin
                next_state = state_set_data_end;
            end else begin
                next_state = state_wait_cpu_read;
            end
          end
          
          // wait for CPU to take sample before getting next one
          // if we got eop in wait_read cycle then we're done
          state_wait_cpu_read: begin
            have_read_data = 1'b1;
            
            if (~sample_consume) begin
              next_state = state_wait_cpu_read;
            // if we communicated last sample then go back to beginning
            end else if (prev_eop) begin
              next_state = state_wait1;
            end else begin
              next_state = state_wait_read;
            end
          end
          
          // this will tell CPU state machine that we hit end of data
          state_set_data_end: begin
            set_fft_data_end_out = 1'b1;
            next_state = state_wait_cpu_read;
          end
          
        endcase
    end
    
    // scale output based on possible exponents
    always @* begin
      case (source_exp)
        // -13
        6'b110011: begin
          source_real_scaled[28:0] = {source_real[15:0], 13'b0};
          source_imag_scaled[28:0] = {source_real[15:0], 13'b0};
        end

        // -12
        6'b110100: begin
          source_real_scaled[28]    = source_real[15];
          source_real_scaled[27:0]  = {source_real[15:0], 12'b0};
          source_imag_scaled[28]    = source_imag[15];
          source_imag_scaled[27:0]  = {source_imag[15:0], 12'b0};
        end

        // -11
        6'b110101: begin
          source_real_scaled[28:27] = {2{source_real[15]}};
          source_real_scaled[26:0]  = {source_real[15:0], 11'b0};
          source_imag_scaled[28:27] = {2{source_imag[15]}};
          source_imag_scaled[26:0]  = {source_imag[15:0], 11'b0};
        end

        // -10
        6'b110110: begin
          source_real_scaled[28:26] = {3{source_real[15]}};
          source_real_scaled[25:0]  = {source_real[15:0], 10'b0};
          source_imag_scaled[28:26] = {2{source_imag[15]}};
          source_imag_scaled[25:0]  = {source_imag[15:0], 10'b0};
        end

        // -9
        6'b110111: begin
          source_real_scaled[28:25] = {4{source_real[15]}};
          source_real_scaled[24:0]  = {source_real[15:0], 9'b0};
          source_imag_scaled[28:25] = {4{source_imag[15]}};
          source_imag_scaled[24:0]  = {source_imag[15:0], 9'b0};
        end

        // -8
        6'b111000: begin
          source_real_scaled[28:24] = {5{source_real[15]}};
          source_real_scaled[23:0]  = {source_real[15:0], 8'b0};
          source_imag_scaled[28:24] = {5{source_imag[15]}};
          source_imag_scaled[23:0]  = {source_imag[15:0], 8'b0};
        end

        // -7
        6'b111001: begin
          source_real_scaled[28:23] = {6{source_real[15]}};
          source_real_scaled[22:0]  = {source_real[15:0], 7'b0};
          source_imag_scaled[28:23] = {6{source_imag[15]}};
          source_imag_scaled[22:0]  = {source_imag[15:0], 7'b0};
        end

        // -6
        6'b111010: begin
          source_real_scaled[28:22] = {7{source_real[15]}};
          source_real_scaled[21:0]  = {source_real[15:0], 6'b0};
          source_imag_scaled[28:22] = {7{source_imag[15]}};
          source_imag_scaled[21:0]  = {source_imag[15:0], 6'b0};
        end

        // -5
        6'b111011: begin
          source_real_scaled[28:21] = {8{source_real[15]}};
          source_real_scaled[20:0]  = {source_real[15:0], 5'b0};
          source_imag_scaled[28:21] = {8{source_imag[15]}};
          source_imag_scaled[20:0]  = {source_imag[15:0], 5'b0};
        end

        // -4
        6'b111100: begin
          source_real_scaled[28:20] = {9{source_real[15]}};
          source_real_scaled[19:0]  = {source_real[15:0], 4'b0};
          source_imag_scaled[28:20] = {9{source_imag[15]}};
          source_imag_scaled[19:0]  = {source_imag[15:0], 4'b0};
        end

        // -3
        6'b111101: begin
          source_real_scaled[28:19] = {10{source_real[15]}};
          source_real_scaled[18:0]  = {source_real[15:0], 3'b0};
          source_imag_scaled[28:19] = {10{source_imag[15]}};
          source_imag_scaled[18:0]  = {source_imag[15:0], 3'b0};
        end

        // -2
        6'b111110: begin
          source_real_scaled[28:18] = {11{source_real[15]}};
          source_real_scaled[17:0]  = {source_real[15:0], 2'b0};
          source_imag_scaled[28:18] = {11{source_imag[15]}};
          source_imag_scaled[17:0]  = {source_imag[15:0], 2'b0};
        end

        // -1
        6'b111111: begin
          source_real_scaled[28:17] = {12{source_real[15]}};
          source_real_scaled[16:0]  = {source_real[15:0], 1'b0};
          source_imag_scaled[28:17] = {12{source_imag[15]}};
          source_imag_scaled[16:0]  = {source_imag[15:0], 1'b0};
        end
      default: begin
          source_real_scaled[28:0] =  {source_real[15:0], 13'b0};
          source_imag_scaled[28:0] =  {source_imag[15:0], 13'b0};
      end
      endcase
    end

    always @(posedge osc_50) begin
      if (~clock_valid) begin
      end else if (reset_50m) begin
          state       <= state_reset;
          have_data   <= 1'b0;
          force_reset <= 1'b0;
      end else begin
          state <= next_state;
          
          if (clear_force_reset) begin
            force_reset <= 1'b0;
          end else if (set_force_reset) begin
            force_reset <= 1'b1;
          end

          // keep track of whether we got eop from FFT core
          if (prev_eop_write) begin
            prev_eop <= source_eop;
          end

          // register the output to CPU
          if (output_data_write) begin
            if (inverse == 1'b0) begin
              // divide by MAX_SAMPLES
              fft_data_real_out <= source_real_scaled[25:10];
              fft_data_imag_out <= source_imag_scaled[25:10];
            end else begin
              fft_data_real_out <= source_real_scaled[15:0];
              fft_data_imag_out <= source_imag_scaled[15:0];
            end
          end
          
          // register inputs (CPU->FFT)
          if (current_sample_clear) begin
            current_sample_real <= 16'h0;
            current_sample_imag <= 16'h0;
          end else if (current_sample_write) begin
            current_sample_real <= fft_data_real_in;
            current_sample_imag <= fft_data_imag_in;
          end
          
          // if we finished talking to FFT, we need to wait till
          // we have data. If we got data from CPU, we can start talking to FFT
          if (clear_have_data) begin
            have_data <= 1'b0;
          end else if (set_have_data) begin
            have_data <= 1'b1;
          end
          
          // keep track of whether we're sending first data sample (for sop)
          if (clear_first_sample) begin
            first_sample <= 1'b0;
          end else if (set_first_sample) begin
            first_sample <= 1'b1;
          end

          // save the first sample's inverse input
          if (inverse_write) begin
            inverse <= fft_inverse_in;
          end
          
          // keep track of # samples we've sent (for eop)
          if (reset_sample_count) begin
            sample_count <= 11'h0;
          end else if (incr_sample_count) begin
            sample_count <= sample_count + 11'h1;
          end
      end
    end
    
    // instantiate FFT core
    fft_core core(
      .clk(osc_50), 
      .reset_n(reset_n),
      .inverse(inverse),
      .sink_valid(sink_valid),
      .sink_sop(sink_sop),
      .sink_eop(sink_eop),
      .sink_real(sink_real),
      .sink_imag(sink_imag),
      .sink_error(sink_error),
      .source_ready(source_ready),
      .sink_ready(sink_ready),
      .source_error(source_error),
      .source_sop(source_sop),
      .source_eop(source_eop),
      .source_valid(source_valid),
      .source_exp(source_exp),
      .source_real(source_real),
      .source_imag(source_imag));
        
    // CPU state machine
    reg [3:0] cpu_state, next_cpu_state;
    reg       next_fft_send_response;
    reg       next_fft_receive_response;
    
    always @* begin
      current_sample_write      = 1'b0;
      current_sample_clear      = 1'b0;
      sample_consume            = 1'b0;
      set_have_data             = 1'b0;
      next_fft_send_response    = 1'b0;
      next_fft_receive_response = 1'b0;
      next_cpu_state            = cpu_state_reset;
      clear_fft_data_end_out    = 1'b0;
        
      case (cpu_state)
          cpu_state_reset: begin
              next_cpu_state = cpu_state_idle;
          end
            
          // wait for valid data from CPU
          cpu_state_idle: begin
            clear_fft_data_end_out = 1'b1;
            
            if (~fft_send_command) begin
              next_cpu_state = cpu_state_idle;
            // see if FFT module accepting data
            end else if (sink_ready) begin
              next_cpu_state = cpu_state_add;
            end else begin
              // need to wait for fft module
              next_cpu_state = cpu_state_idle;
            end
          end
            
          // add sample 
          cpu_state_add: begin
            current_sample_write  = 1'b1;
            set_have_data         = 1'b1;

            // we delay ack of last sample until transform is done
            if (sample_count == (MAX_SAMPLES-1) || fft_data_end_in) begin
              next_cpu_state  = cpu_state_delay_ack;
            end else begin
              next_cpu_state  = cpu_state_ack;
            end
          end
          
          // assert send_response and wait for send_command to go low
          cpu_state_ack: begin
            next_fft_send_response    = 1'b1;
            if (fft_send_command || first_sample) begin
              next_cpu_state = cpu_state_ack;
            end else begin
              next_cpu_state  = cpu_state_idle;
            end
          end
        
          // delay the ack for the final sample until transform done
          cpu_state_delay_ack: begin
            if (have_read_data) begin
              next_cpu_state = cpu_state_last_ack;
            end else begin
              next_cpu_state = cpu_state_delay_ack;
            end
          end

          // send last ack to CPU for input data
          cpu_state_last_ack: begin
            next_fft_send_response = 1'b1;
            if (fft_send_command) begin
              next_cpu_state = cpu_state_last_ack;
            end else begin
              next_cpu_state = cpu_state_read_idle;
            end
          end

          // wait for signal that we have transform data and CPU is requesting
          // data.
          // set current_sample to 0 in case we didn't get all MAX_SAMPLES
          // from CPU, in which case we pad with 0
          // if CPU sends new data for transformation, flush the current
          // pending results
          cpu_state_read_idle: begin
            current_sample_clear = 1'b1;

            if (fft_send_command) begin
              next_cpu_state = cpu_state_flush;
            end else if (have_read_data && fft_receive_command) begin
              next_cpu_state = cpu_state_read_valid;
            end else begin
              next_cpu_state = cpu_state_read_idle;
            end
          end
      
          // send data output and wait for CPU to lower fft_receive_command
          cpu_state_read_valid: begin
            next_fft_receive_response = 1'b1;

            if (~fft_receive_command) begin
              next_cpu_state = cpu_state_consume;
            end else begin
              next_cpu_state = cpu_state_read_valid;
            end
          end
          
          // say that we got the sample
          cpu_state_consume: begin
            sample_consume = 1'b1;
            
            // If we just sent the last transform sample, then go back to wait
            // for input from CPU
            if (fft_data_end_out) begin
              next_cpu_state  = cpu_state_idle;
            end else begin
              next_cpu_state = cpu_state_read_idle;
            end
          end
          
          // flush pending output transform data because CPU wants to start
          // new transform
          cpu_state_flush: begin
            sample_consume = 1'b1;
            if (fft_data_end_out) begin
              next_cpu_state = cpu_state_add;
            end else begin
              next_cpu_state = cpu_state_flush;
            end
          end

      endcase  
    end
    
    always @(posedge osc_50) begin
      if (~clock_valid) begin
      end else if(reset_50m) begin
        cpu_state <= cpu_state_idle;
      end else begin
        cpu_state <= next_cpu_state;
      end

      // register signals to prevent glitches
      fft_send_response <= next_fft_send_response;
      fft_receive_response <= next_fft_receive_response;
      
      if (clear_fft_data_end_out) begin
        fft_data_end_out  <= 1'b0;
      end else if (set_fft_data_end_out) begin
        fft_data_end_out  <= 1'b1;
      end
    end

endmodule
