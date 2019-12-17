// megafunction wizard: %FFT v13.0%
// GENERATION: XML

// ============================================================
// Megafunction Name(s):
// 			asj_fft_si_de_so_b_fft_130
// ============================================================
// Generated by FFT 13.0 [Altera, IP Toolbench 1.3.0 Build 232]
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
// ************************************************************
// Copyright (C) 1991-2013 Altera Corporation
// Any megafunction design, and related net list (encrypted or decrypted),
// support information, device programming or simulation file, and any other
// associated documentation or information provided by Altera or a partner
// under Altera's Megafunction Partnership Program may be used only to
// program PLD devices (but not masked PLD devices) from Altera.  Any other
// use of such megafunction design, net list, support information, device
// programming or simulation file, or any other related documentation or
// information is prohibited for any other purpose, including, but not
// limited to modification, reverse engineering, de-compiling, or use with
// any other silicon devices, unless such use is explicitly licensed under
// a separate agreement with Altera or a megafunction partner.  Title to
// the intellectual property, including patents, copyrights, trademarks,
// trade secrets, or maskworks, embodied in any such megafunction design,
// net list, support information, device programming or simulation file, or
// any other related documentation or information provided by Altera or a
// megafunction partner, remains with Altera, the megafunction partner, or
// their respective licensors.  No other licenses, including any licenses
// needed under any third party's intellectual property, are provided herein.


module fft_core (
	clk,
	reset_n,
	inverse,
	sink_valid,
	sink_sop,
	sink_eop,
	sink_real,
	sink_imag,
	sink_error,
	source_ready,
	sink_ready,
	source_error,
	source_sop,
	source_eop,
	source_valid,
	source_exp,
	source_real,
	source_imag);


	input		clk;
	input		reset_n;
	input		inverse;
	input		sink_valid;
	input		sink_sop;
	input		sink_eop;
	input	[15:0]	sink_real;
	input	[15:0]	sink_imag;
	input	[1:0]	sink_error;
	input		source_ready;
	output		sink_ready;
	output	[1:0]	source_error;
	output		source_sop;
	output		source_eop;
	output		source_valid;
	output	[5:0]	source_exp;
	output	[15:0]	source_real;
	output	[15:0]	source_imag;


	asj_fft_si_de_so_b_fft_130	asj_fft_si_de_so_b_fft_130_inst(
		.clk(clk),
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

	defparam
		asj_fft_si_de_so_b_fft_130_inst.nps = 1024,
		asj_fft_si_de_so_b_fft_130_inst.bfp = 1,
		asj_fft_si_de_so_b_fft_130_inst.nume = 2,
		asj_fft_si_de_so_b_fft_130_inst.mpr = 16,
		asj_fft_si_de_so_b_fft_130_inst.twr = 16,
		asj_fft_si_de_so_b_fft_130_inst.bpr = 16,
		asj_fft_si_de_so_b_fft_130_inst.bpb = 4,
		asj_fft_si_de_so_b_fft_130_inst.fpr = 4,
		asj_fft_si_de_so_b_fft_130_inst.mram = 0,
		asj_fft_si_de_so_b_fft_130_inst.m512 = 0,
		asj_fft_si_de_so_b_fft_130_inst.mult_type = 1,
		asj_fft_si_de_so_b_fft_130_inst.mult_imp = 0,
		asj_fft_si_de_so_b_fft_130_inst.dsp_arch = 0,
		asj_fft_si_de_so_b_fft_130_inst.srr = "AUTO_SHIFT_REGISTER_RECOGNITION=OFF",
		asj_fft_si_de_so_b_fft_130_inst.rfs1 = "fft_core_1n1024sin.hex",
		asj_fft_si_de_so_b_fft_130_inst.rfs2 = "fft_core_2n1024sin.hex",
		asj_fft_si_de_so_b_fft_130_inst.rfs3 = "fft_core_3n1024sin.hex",
		asj_fft_si_de_so_b_fft_130_inst.rfc1 = "fft_core_1n1024cos.hex",
		asj_fft_si_de_so_b_fft_130_inst.rfc2 = "fft_core_2n1024cos.hex",
		asj_fft_si_de_so_b_fft_130_inst.rfc3 = "fft_core_3n1024cos.hex";
endmodule

// =========================================================
// FFT Wizard Data
// ===============================
// DO NOT EDIT FOLLOWING DATA
// @Altera, IP Toolbench@
// Warning: If you modify this section, FFT Wizard may not be able to reproduce your chosen configuration.
// 
// Retrieval info: <?xml version="1.0"?>
// Retrieval info: <MEGACORE title="FFT MegaCore Function"  version="13.0"  build="232"  iptb_version="1.3.0 Build 232"  format_version="120" >
// Retrieval info:  <NETLIST_SECTION class="altera.ipbu.flowbase.netlist.model.FFTModelClass"  active_core="asj_fft_si_de_so_b_fft_130" >
// Retrieval info:   <STATIC_SECTION>
// Retrieval info:    <PRIVATES>
// Retrieval info:     <NAMESPACE name = "parameterization">
// Retrieval info:      <PRIVATE name = "use_mem" value="1"  type="BOOLEAN"  enable="1" />
// Retrieval info:      <PRIVATE name = "mem_type" value="M512"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "DEVICE" value="Cyclone IV E"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "NPS" value="1024"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "MPR" value="16"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "TWR" value="16"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "OPR" value="29"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "ARCH" value="2"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUME" value="2"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "ENGINE_THROUGHPUT" value="4"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "BFP" value="1"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "MULT_TYPE" value="1"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "MULT_IMP" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "MEGA" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "M512" value="1"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "LOGIC_IN_RAM" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_LE" value="6512"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_M4K" value="7"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_MEGA" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_M512" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_DSP" value="48"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_CALC_CYCLES" value="601"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_BLK_THROUGHPUT_CYCLES" value="2650"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfs1" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfs2" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfs3" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfc1" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfc2" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "rfc3" value="romfile_1024.hex"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "ENA" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "NUM_MEMBITS" value="57344"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "INPUT_ORDER" value="1"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "OUTPUT_ORDER" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "REPRESENTATION" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "ENGINE_ONLY" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "DSP_ARCH" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:      <PRIVATE name = "DIRECTION" value="0"  type="INTEGER"  enable="1" />
// Retrieval info:     </NAMESPACE>
// Retrieval info:     <NAMESPACE name = "simgen_enable">
// Retrieval info:      <PRIVATE name = "language" value="Verilog HDL"  type="STRING"  enable="1" />
// Retrieval info:     </NAMESPACE>
// Retrieval info:     <NAMESPACE name = "simgen">
// Retrieval info:      <PRIVATE name = "filename" value="fft_core.vo"  type="STRING"  enable="1" />
// Retrieval info:     </NAMESPACE>
// Retrieval info:     <NAMESPACE name = "greybox">
// Retrieval info:      <PRIVATE name = "filename" value="fft_core_syn.v"  type="STRING"  enable="1" />
// Retrieval info:     </NAMESPACE>
// Retrieval info:     <NAMESPACE name = "quartus_settings">
// Retrieval info:      <PRIVATE name = "WEB_BROWSER" value="/usr/bin/firefox"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "LICENSE_FILE" value="/home/pmchen/src/quartus/license.dat"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "DEVICE" value="EP4CE115F29C7"  type="STRING"  enable="1" />
// Retrieval info:      <PRIVATE name = "FAMILY" value="Cyclone IV E"  type="STRING"  enable="1" />
// Retrieval info:     </NAMESPACE>
// Retrieval info:     <NAMESPACE name = "serializer"/>
// Retrieval info:    </PRIVATES>
// Retrieval info:    <FILES/>
// Retrieval info:    <PORTS/>
// Retrieval info:    <LIBRARIES/>
// Retrieval info:   </STATIC_SECTION>
// Retrieval info:  </NETLIST_SECTION>
// Retrieval info: </MEGACORE>
// =========================================================