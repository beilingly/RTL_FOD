`define WI 6
`define WF 16
`define WF_PHASE 24

`include "../dcd_rls/dcd_rls.sv"

// -------------------------------------------------------
// Module Name: DSM_MASH1
// Function: MASH1
// Author: Yang Yumeng Date: 3/15 2023
// Version: v1p0
// -------------------------------------------------------
module DSM_MASH1(
CLK,
NRST,
EN,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input [`WF-1:0] IN;
output reg OUT; // ufix, 0 to 1
output reg [`WF-1:0] PHE; // ufix, 0<x<1

// internal signal
wire [`WF:0] sum1_temp;
wire [`WF-1:0] sum1;
reg [`WF-1:0] sum1_reg;
wire ca1;

// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE <= 0;
	end else if (EN) begin
		OUT <= ca1;
		PHE <= sum1;
	end
end

assign sum1_temp = sum1_reg + IN;
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = sum1_temp[`WF];
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum1_reg <= 0;
	else if (EN) begin 
		sum1_reg <= sum1;
	end
end

endmodule
// ------------------------------------------------------------
// Module Name: CALI_FMP_PHASEOFST
// Function: calibrate multi-phases offset in auxpll 
// Authot: Yumeng Yang Date: 2024-3-1
// Version: v1p0
// ------------------------------------------------------------
module CALI_FMP_PHASEOFST(
// input
NRST,
CLK,
EN,
PHE_MEASURE,
DPHASE_SEG_ARR
);

input NRST;
input CLK;
input EN; // cali en
input [2:0] PHE_MEASURE; // 0~7

output reg [8*`WF_PHASE-1:0] DPHASE_SEG_ARR; // dphase define array

// internal signal
reg [`WF_PHASE-1:0] dphase_seg [7:0];
reg [9:0] cntwin; // count window is 1024 CLK periods
reg [9:0] cnt [7:0], cnt_reg [7:0], cnt_reg_accum [7:0], cnt_reg_accum_iir [7:0];
integer i, j;

// counter window
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<8; i=i+1) begin
			cnt[i] <= 0;
			cnt_reg[i] <= 0;
		end
		cntwin <= 0;
	end else if (EN) begin
		// cnt window
		if (cntwin == ((1'b1<<10) - 1'b1)) begin
			cntwin <= 0;
		end else begin
			cntwin <= cntwin + 1;
		end
		// assert each dphase segments
		if (cntwin == 0) begin
			for (i=0; i<8; i=i+1) begin
				cnt[i] <= 0;
				cnt_reg[i] <= cnt[i];
			end
		end else begin
			cnt[PHE_MEASURE] <= cnt[PHE_MEASURE] + 1;
		end
	end
end

// accumulate cnt_reg
always @* begin
	for (i=0; i<8; i=i+1) begin
		cnt_reg_accum[i] = 0;
		for (j=0; j<=i; j=j+1) begin
			cnt_reg_accum[i] = cnt_reg_accum[i] + cnt_reg[j];
			// if (j < i) begin
			// 	cnt_reg_accum[i] = cnt_reg_accum[i] + cnt_reg[j];
			// end else begin
			// 	cnt_reg_accum[i] = cnt_reg_accum[i] + (cnt_reg[j] >> 1);
			// end
			
		end
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<8; i=i+1) begin
			cnt_reg_accum_iir[i] <= (i+1) << (10-3);
		end
	end else if (EN) begin
		if (cntwin == 0) begin
			for (i=0; i<8; i=i+1) begin
				cnt_reg_accum_iir[i] <= cnt_reg_accum_iir[i] - (cnt_reg_accum_iir[i]>>6) + (cnt_reg_accum[i]>>6);
				// cnt_reg_accum_iir[i] <= cnt_reg_accum[i];
			end
		end
	end
end

// dphase segments define
always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<8; i=i+1) begin
			DPHASE_SEG_ARR[(i+1)*`WF_PHASE-1-:`WF_PHASE] <= (i+1) << (`WF_PHASE-3);
		end

		// DPHASE_SEG_ARR[1*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 1/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[2*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 3/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[3*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 5/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[4*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 7/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[5*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 9/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[6*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 11/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[7*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 13/16 * (2**`WF_PHASE);
		// DPHASE_SEG_ARR[8*`WF_PHASE-1-:`WF_PHASE] <= 1.0 * 15/16 * (2**`WF_PHASE);

	end else if (EN) begin
		if (cntwin == 0) begin
			for (i=0; i<8; i=i+1) begin
				DPHASE_SEG_ARR[(i+1)*`WF_PHASE-1-:`WF_PHASE] <= cnt_reg_accum_iir[i] << (`WF_PHASE-10);
			end
		end
	end
end

endmodule
// ------------------------------------------------------------
// Module Name: CALI_PHASESYNC
// Function: a NCO operates at same freq with FOD and calibrate the phase equale to it
// Authot: Yumeng Yang Date: 2023-11-21
// Version: v1p0
// ------------------------------------------------------------
module CALI_PHASESYNC (
// input 
NRST,
CLK,
EN,
FCW_FOD,
FCW_PLL_MAIN_S,
FCW_PLL_AUX_S,
PHE_MEASURE,
// output
PHE_NORM
);

// delay information
// PHE_MEASURE -> PHE_NORM delay 1 cycle

input NRST;
input CLK;
input EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] FCW_PLL_MAIN_S; // default to 32(2^5)
input [2:0] FCW_PLL_AUX_S; // defualt to 16(2^4)
input [2:0] PHE_MEASURE; // 0~7
// input [3:0] PHE_MEASURE; // 0~15

output [`WF-1:0] PHE_NORM; // 0<=x<1

// Numeric Controled Oscillator

reg [2:0] os_main_aux; // 0~5
reg [`WI+`WF-1:0] fcw_os_aux;
reg [`WI+`WF-1:0] fcw_os_aux_residual;
reg [`WI+`WF-1:0] module_threshold;
reg [`WI+`WF-1:0] nco_phase;
reg [`WI+`WF-1:0] nco_phase_d1;

// calculate oversampling rate fmod/fpll_aux

always @* begin
	os_main_aux = FCW_PLL_MAIN_S - FCW_PLL_AUX_S;
	fcw_os_aux = FCW_FOD; // shift right by os_main_aux
	fcw_os_aux_residual = ( (fcw_os_aux<<(`WI-os_main_aux)) >> (`WI-os_main_aux) ); // fracional part
	module_threshold = 1'b1<<(`WF+os_main_aux);
	// nco phase accumulate
	nco_phase = nco_phase_d1 + fcw_os_aux_residual;
	if (nco_phase >= module_threshold) begin
		nco_phase = nco_phase - module_threshold;
	end else begin
		nco_phase = nco_phase;
	end
	// nco_phase_s = nco_phase[os_main_aux]? ((nco_phase>>os_main_aux) + 1'b1): (nco_phase>>os_main_aux); // shift right and round
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		nco_phase_d1 <= 0;
	end else begin
		nco_phase_d1 <= nco_phase;
	end
end

// map analog phase to digital
reg [`WF_PHASE-1:0] dphase_m;
real phase_ana_norm;

assign phase_ana_norm = simpleFOD2_TB.phase_ana_norm;

initial dphase_m = 0;
always @* begin
	// dphase_m = $rtoi(phase_ana_norm * (2**`WF_PHASE));
	// dphase_m = (phase_ana_norm>0.5)? (1'b1<<(`WF_PHASE-1)): 0;

	// if (phase_ana_norm<1.0/4) dphase_m = 2'b00 << (`WF_PHASE-2);
	// else if (phase_ana_norm<2.0/4) dphase_m = 2'b01 << (`WF_PHASE-2);
	// else if (phase_ana_norm<3.0/4) dphase_m = 2'b10 << (`WF_PHASE-2);
	// else dphase_m = 2'b11 << (`WF_PHASE-2);

	// if (phase_ana_norm<1.0/8) dphase_m = 3'b000 << (`WF_PHASE-3);
	// else if (phase_ana_norm<2.0/8) dphase_m = 3'b001 << (`WF_PHASE-3);
	// else if (phase_ana_norm<3.0/8) dphase_m = 3'b010 << (`WF_PHASE-3);
	// else if (phase_ana_norm<4.0/8) dphase_m = 3'b011 << (`WF_PHASE-3);
	// else if (phase_ana_norm<5.0/8) dphase_m = 3'b100 << (`WF_PHASE-3);
	// else if (phase_ana_norm<6.0/8) dphase_m = 3'b101 << (`WF_PHASE-3);
	// else if (phase_ana_norm<7.0/8) dphase_m = 3'b110 << (`WF_PHASE-3);
	// else dphase_m = 3'b111 << (`WF_PHASE-3);

	if (phase_ana_norm<1.0/32) 			dphase_m = 5'b00000 << (`WF_PHASE-5);
	else if (phase_ana_norm<2.0/32)		dphase_m = 5'b00001 << (`WF_PHASE-5);
	else if (phase_ana_norm<3.0/32)		dphase_m = 5'b00010 << (`WF_PHASE-5);
	else if (phase_ana_norm<4.0/32)		dphase_m = 5'b00011 << (`WF_PHASE-5);
	else if (phase_ana_norm<5.0/32)		dphase_m = 5'b00100 << (`WF_PHASE-5);
	else if (phase_ana_norm<6.0/32)		dphase_m = 5'b00101 << (`WF_PHASE-5);
	else if (phase_ana_norm<7.0/32)		dphase_m = 5'b00110 << (`WF_PHASE-5);
	else if (phase_ana_norm<8.0/32)		dphase_m = 5'b00111 << (`WF_PHASE-5);
	else if (phase_ana_norm<9.0/32)		dphase_m = 5'b01000 << (`WF_PHASE-5);
	else if (phase_ana_norm<10.0/32)	dphase_m = 5'b01001 << (`WF_PHASE-5);
	else if (phase_ana_norm<11.0/32)	dphase_m = 5'b01010 << (`WF_PHASE-5);
	else if (phase_ana_norm<12.0/32)	dphase_m = 5'b01011 << (`WF_PHASE-5);
	else if (phase_ana_norm<13.0/32)	dphase_m = 5'b01100 << (`WF_PHASE-5);
	else if (phase_ana_norm<14.0/32)	dphase_m = 5'b01101 << (`WF_PHASE-5);
	else if (phase_ana_norm<15.0/32)	dphase_m = 5'b01110 << (`WF_PHASE-5);
	else if (phase_ana_norm<16.0/32)	dphase_m = 5'b01111 << (`WF_PHASE-5);
	else if (phase_ana_norm<17.0/32)	dphase_m = 5'b10000 << (`WF_PHASE-5);
	else if (phase_ana_norm<18.0/32)	dphase_m = 5'b10001 << (`WF_PHASE-5);
	else if (phase_ana_norm<19.0/32)	dphase_m = 5'b10010 << (`WF_PHASE-5);
	else if (phase_ana_norm<20.0/32)	dphase_m = 5'b10011 << (`WF_PHASE-5);
	else if (phase_ana_norm<21.0/32)	dphase_m = 5'b10100 << (`WF_PHASE-5);
	else if (phase_ana_norm<22.0/32)	dphase_m = 5'b10101 << (`WF_PHASE-5);
	else if (phase_ana_norm<23.0/32)	dphase_m = 5'b10110 << (`WF_PHASE-5);
	else if (phase_ana_norm<24.0/32)	dphase_m = 5'b10111 << (`WF_PHASE-5);
	else if (phase_ana_norm<25.0/32)	dphase_m = 5'b11000 << (`WF_PHASE-5);
	else if (phase_ana_norm<26.0/32)	dphase_m = 5'b11001 << (`WF_PHASE-5);
	else if (phase_ana_norm<27.0/32)	dphase_m = 5'b11010 << (`WF_PHASE-5);
	else if (phase_ana_norm<28.0/32)	dphase_m = 5'b11011 << (`WF_PHASE-5);
	else if (phase_ana_norm<29.0/32)	dphase_m = 5'b11100 << (`WF_PHASE-5);
	else if (phase_ana_norm<30.0/32)	dphase_m = 5'b11101 << (`WF_PHASE-5);
	else if (phase_ana_norm<31.0/32)	dphase_m = 5'b11110 << (`WF_PHASE-5);
	else								dphase_m = 5'b11111 << (`WF_PHASE-5);
end

// AUXPLL multi-phase cali
wire [8*`WF_PHASE-1:0] DPHASE_SEG_ARR;
CALI_FMP_PHASEOFST U2_PHASESYNC_FMP_PHASEOFST ( .NRST(NRST), .CLK(CLK), .EN(1'b0), .PHE_MEASURE(PHE_MEASURE), .DPHASE_SEG_ARR(DPHASE_SEG_ARR) );

// always @(posedge CLK or negedge NRST) begin
// 	if (!NRST) dphase_m <= 0;
// 	else begin
// 		case (PHE_MEASURE)
// 			3'b000: dphase_m <= 0; // 000 deg
// 			3'b001: dphase_m <= {3'b001, {(`WF_PHASE-3){1'b0}}}; // 045deg
// 			3'b010: dphase_m <= {3'b010, {(`WF_PHASE-3){1'b0}}}; // 090deg
// 			3'b011: dphase_m <= {3'b011, {(`WF_PHASE-3){1'b0}}}; // 135deg
// 			3'b100: dphase_m <= {3'b100, {(`WF_PHASE-3){1'b0}}}; // 180deg
// 			3'b101: dphase_m <= {3'b101, {(`WF_PHASE-3){1'b0}}}; // 224deg
// 			3'b110: dphase_m <= {3'b110, {(`WF_PHASE-3){1'b0}}}; // 270deg
// 			3'b111: dphase_m <= {3'b111, {(`WF_PHASE-3){1'b0}}}; // 315deg
// 		endcase
// 		// dphase_m <= PHE_MEASURE << (`WF_PHASE-4);
// 	end
// end

// always @(posedge CLK or negedge NRST) begin
// 	if (!NRST) dphase_m <= 0;
// 	else begin
// 		case (PHE_MEASURE)
// 			3'b000: dphase_m <= DPHASE_SEG_ARR[1*`WF_PHASE-1-:`WF_PHASE]; // 000 deg
// 			3'b001: dphase_m <= DPHASE_SEG_ARR[2*`WF_PHASE-1-:`WF_PHASE]; // 045deg
// 			3'b010: dphase_m <= DPHASE_SEG_ARR[3*`WF_PHASE-1-:`WF_PHASE]; // 090deg
// 			3'b011: dphase_m <= DPHASE_SEG_ARR[4*`WF_PHASE-1-:`WF_PHASE]; // 135deg
// 			3'b100: dphase_m <= DPHASE_SEG_ARR[5*`WF_PHASE-1-:`WF_PHASE]; // 180deg
// 			3'b101: dphase_m <= DPHASE_SEG_ARR[6*`WF_PHASE-1-:`WF_PHASE]; // 224deg
// 			3'b110: dphase_m <= DPHASE_SEG_ARR[7*`WF_PHASE-1-:`WF_PHASE]; // 270deg
// 			3'b111: dphase_m <= DPHASE_SEG_ARR[8*`WF_PHASE-1-:`WF_PHASE]; // 315deg
// 		endcase
// 		// dphase_m <= PHE_MEASURE << (`WF_PHASE-4);
// 	end
// end

// calibrete phase offset
reg [`WF_PHASE-1:0] nco_phase_s; // 0<x<1
reg signed [`WF_PHASE-1:0] diff_phase; // -1<x<1
reg signed [`WF_PHASE-1:0] dphase_c, dphase_c_step; // dphase for offset calibration
wire [`WI+`WF-1:0] PHASE_CALI;

assign PHASE_CALI = dphase_c_step >>> (`WF_PHASE - `WI - `WF);

always @* begin
	nco_phase_s = nco_phase << (`WF_PHASE-`WF-os_main_aux);
	diff_phase = nco_phase_s - dphase_m;
	// phase sync convergence rate
	// shift 12, 20us, error<1e-3; shift 16, 500us, error<1e-5
	dphase_c_step = EN? (diff_phase[`WF_PHASE-1]? (-`WF_PHASE'd16): (`WF_PHASE'd16)): 0;
	// dphase_c_step = EN? diff_phase >>> 8: 0;
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		dphase_c <= 0;
	end else if (EN) begin 
		// dphase_c has a pattern with 1200ns period, maybe lead to a spur, but that can be suppressed with a digital random dither
		dphase_c <= dphase_c_step + dphase_c;
	end
end

// ouput normalized phase error
// diffphase of dig and analog
// assign PHE_NORM = diff_phase[`WF_PHASE-`WF-1]? (diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit
// diffphase of dig and analog with digital random dither
assign PHE_NORM = diff_phase[`WF_PHASE-`WF-1]? (diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit

// test
integer fp1;
real r_dphase_c, r_diff_phase;

always @* begin
	r_dphase_c = $unsigned(dphase_c) * (2.0**-`WF_PHASE);
	r_diff_phase = $signed(diff_phase) * (2.0**-`WF_PHASE);
end

initial begin
	fp1 = $fopen("diff_phase.txt");
end

always @(posedge CLK) begin
	$fstrobe(fp1, "%d", $signed(diff_phase));
end

endmodule

// ------------------------------------------------------------
// Module Name: CALI_DTCINL
// Function: 0th/1st/2nd-order calibrate DTC INL；
// 			calibration method: piecewise + LMS/RLS + 0th/1st/2nd-order
// Authot: Yumeng Yang Date: 2023-11-27
// Version: v1p0
// ------------------------------------------------------------
module CALI_DTCINL (
// input
NRST,
CLK,
EN,
DSM_PHE,
PHE_NORM,
CALI_MODE_RLS,
// output
dtc_dcw
);

// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NRST;
input CLK;
input EN; // calibration en
input [`WF-1:0] DSM_PHE; // DSM output
input [`WF-1:0] PHE_NORM; // normalized phe
input CALI_MODE_RLS; // calibration method

output real dtc_dcw;

// internal signal
reg dsm_phe_qt;
reg [`WF-1:0] dsm_phe_remain;
reg [`WF-1:0] dsm_phe_remain_sl; // shift left 1bit
real dsm_phe_remain_real;
real err;

always @* begin
	dsm_phe_qt = DSM_PHE[`WF-1];
	dsm_phe_remain = DSM_PHE[`WF-2:0]; // 0<=x<0.5
	dsm_phe_remain_sl = dsm_phe_remain << 1; // 0<=2*x<1.0
	dsm_phe_remain_real = $unsigned(dsm_phe_remain_sl) * (2.0**-`WF);
	// phase error between fod and pllaux
	err = 1.0 * $signed(PHE_NORM) * (2.0**-`WF);
end

// internal signals

// CALI_RLS_PSEG U2_CALI_DTCINL_CALI_RLS_PSEG (
// .NRST(NRST),
// .EN(EN),
// .CLK(CLK),
// .CALI_MODE_RLS(CALI_MODE_RLS),
// .X(dsm_phe_remain_real),
// .sync_dly(3'd1),
// .ERR(err),
// .PSEGS(2'd0),
// .KDTC_INIT(400),
// .Y(dtc_dcw)
// );

// LMS kdtc cali
real kdtc;
real x, x_d1, x_d2, x_d3;

assign x = dsm_phe_remain_real;
assign dtc_dcw = x * kdtc;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		kdtc <= 390;
		x_d1 <= 0;
		x_d2 <= 0;
		x_d3 <= 0;
	end else if (EN) begin
		x_d1 <= x;
		x_d2 <= x_d1;
		x_d3 <= x_d2;
		kdtc <= kdtc + err * x_d2 * 1;
	end
end

// test
integer fp1;

initial begin
	fp1 = $fopen("corr_dsm_err.txt");
end

always @(posedge CLK) begin
	$fstrobe(fp1, "%3.15e %.8f %.8f", $realtime, dsm_phe_remain_real, err);
end


endmodule
// ------------------------------------------------------------
// Module Name: FOD_CTRL
// Function: generate DTC/RT/MMD ctrl word
// Authot: Yumeng Yang Date: 2023-11-14
// Version: v1p0
// ------------------------------------------------------------

module FOD_CTRL (
// input
NARST,
CLK,
DSM_EN,
FCW_FOD,
PHE,
// output
MMD_DCW,
RT_DCW,
DTC_DCW
);

parameter real KDTC = 1/8e9/160e-15 * 1.0;

// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NARST;
input CLK;
input DSM_EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] PHE;
// input [3:0] PHE;

output reg [5:0] MMD_DCW; // MMD div range 4~63
output reg RT_DCW; // 0: posedge retimer; 1: negedge retimer(delay for 0.5 FPLL8G cycle)
output reg [9:0] DTC_DCW;

wire NRST;
wire [`WI+`WF-1:0] FCW_FOD;
wire [`WI-1:0] FCW_FOD_I;
wire [`WF-1:0] FCW_FOD_F;
wire DSM_CAR;
wire [`WF-1:0] DSM_PHE; // ufix, 0<x<1
wire phe_quant;
wire [`WF-1:0] phe_remain; // 0<x<0.5
wire [9:0] dtc_dcw;
reg [`WI-1:0] FCW_FOD_I_sync;

assign NRST = NARST;

// DCW output
always @* begin
    MMD_DCW = FCW_FOD_I_sync + DSM_CAR;
end

always @ (posedge CLK) begin
	RT_DCW <= phe_quant;
	DTC_DCW <= dtc_dcw;
end

always @ (posedge CLK or negedge NRST) begin
    if (!NRST) begin
        FCW_FOD_I_sync <= 4;
    end else begin
        FCW_FOD_I_sync <= FCW_FOD_I; // sync with DSM_CAR, DSM_PHE
    end
end

// FOD phase adjust according PCALI 
wire [`WI+`WF-1:0] phase_cali;

assign phase_cali = U1_FOD_CTRL_CALI_PHASESYNC.PHASE_CALI;

assign {FCW_FOD_I, FCW_FOD_F} = FCW_FOD + phase_cali;

// translate fcw into mmd/dtc ctrl word
DSM_MASH1 U1_FOD_CTRL_DSM_MASH1 ( .CLK (CLK), .NRST (NRST), .EN (DSM_EN), .IN (FCW_FOD_F), .OUT (DSM_CAR), .PHE (DSM_PHE) );

// 0.5 quantization
assign phe_quant = DSM_PHE[`WF-1];
assign phe_remain = DSM_PHE[`WF-2:0];

// calibration
// phase sync
wire [`WF-1:0] PHE_NORM;
reg PCALI_EN;

initial begin
	PCALI_EN = 1;
	#5e-6;
	PCALI_EN = 1;
end

CALI_PHASESYNC U1_FOD_CTRL_CALI_PHASESYNC (
.NRST(NRST),
.CLK(CLK),
.EN(PCALI_EN),
.FCW_FOD(FCW_FOD),
.FCW_PLL_MAIN_S(3'd5),
.FCW_PLL_AUX_S(3'd4),
.PHE_MEASURE(PHE),
.PHE_NORM(PHE_NORM)
);

// dtc cali
real dtc_dcw_real;
reg DTCCALI_EN;

initial begin
	DTCCALI_EN = 0;
	#5e-6;
	DTCCALI_EN = 1;
end

CALI_DTCINL U1_FOD_CTRL_CALI_DTCINL (
.NRST(NRST),
.CLK(CLK),
.EN(DTCCALI_EN),
.DSM_PHE(DSM_PHE),
.PHE_NORM(PHE_NORM),
.CALI_MODE_RLS(1'd0), // 0:LMS, 1:RLS
.dtc_dcw(dtc_dcw_real)
);

// dtc dcw calc
// assign dtc_dcw = (phe_remain * (2.0**-`WF)) * KDTC * 1.0 ;
assign dtc_dcw = dtc_dcw_real * 1.0;

// test
real fcw_real;
real dsmphe_real;

always @* begin
	fcw_real = FCW_FOD * (2.0**-`WF);
	dsmphe_real = DSM_PHE * (2.0**-`WF);
end

endmodule