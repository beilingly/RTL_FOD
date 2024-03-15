`timescale 1s/1fs

`define WI 6
`define WF 16
`define WF_PHASE 24

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

assign phase_ana_norm = fod2_tb.phase_ana_norm;
// assign dphase_m = $rtoi(phase_ana_norm * (2**`WF_PHASE));
initial dphase_m = 0;
always @* begin
	// dphase_m = (phase_ana_norm>0.5)? (1'b1<<(`WF_PHASE-1)): 0;

	if (phase_ana_norm<1.0/16) 			dphase_m = 4'b0000 << (`WF_PHASE-4);
	else if (phase_ana_norm<2.0/16)		dphase_m = 4'b0001 << (`WF_PHASE-4);
	else if (phase_ana_norm<3.0/16)		dphase_m = 4'b0010 << (`WF_PHASE-4);
	else if (phase_ana_norm<4.0/16)		dphase_m = 4'b0011 << (`WF_PHASE-4);
	else if (phase_ana_norm<5.0/16)		dphase_m = 4'b0100 << (`WF_PHASE-4);
	else if (phase_ana_norm<6.0/16)		dphase_m = 4'b0101 << (`WF_PHASE-4);
	else if (phase_ana_norm<7.0/16)		dphase_m = 4'b0110 << (`WF_PHASE-4);
	else if (phase_ana_norm<8.0/16)		dphase_m = 4'b0111 << (`WF_PHASE-4);
	else if (phase_ana_norm<9.0/16)		dphase_m = 4'b1000 << (`WF_PHASE-4);
	else if (phase_ana_norm<10.0/16)	dphase_m = 4'b1001 << (`WF_PHASE-4);
	else if (phase_ana_norm<11.0/16)	dphase_m = 4'b1010 << (`WF_PHASE-4);
	else if (phase_ana_norm<12.0/16)	dphase_m = 4'b1011 << (`WF_PHASE-4);
	else if (phase_ana_norm<13.0/16)	dphase_m = 4'b1100 << (`WF_PHASE-4);
	else if (phase_ana_norm<14.0/16)	dphase_m = 4'b1101 << (`WF_PHASE-4);
	else if (phase_ana_norm<15.0/16)	dphase_m = 4'b1110 << (`WF_PHASE-4);
	else								dphase_m = 4'b1111 << (`WF_PHASE-4);

	// if (phase_ana_norm<1.0/32) 			dphase_m = 5'b00000 << (`WF_PHASE-5);
	// else if (phase_ana_norm<2.0/32)		dphase_m = 5'b00001 << (`WF_PHASE-5);
	// else if (phase_ana_norm<3.0/32)		dphase_m = 5'b00010 << (`WF_PHASE-5);
	// else if (phase_ana_norm<4.0/32)		dphase_m = 5'b00011 << (`WF_PHASE-5);
	// else if (phase_ana_norm<5.0/32)		dphase_m = 5'b00100 << (`WF_PHASE-5);
	// else if (phase_ana_norm<6.0/32)		dphase_m = 5'b00101 << (`WF_PHASE-5);
	// else if (phase_ana_norm<7.0/32)		dphase_m = 5'b00110 << (`WF_PHASE-5);
	// else if (phase_ana_norm<8.0/32)		dphase_m = 5'b00111 << (`WF_PHASE-5);
	// else if (phase_ana_norm<9.0/32)		dphase_m = 5'b01000 << (`WF_PHASE-5);
	// else if (phase_ana_norm<10.0/32)	dphase_m = 5'b01001 << (`WF_PHASE-5);
	// else if (phase_ana_norm<11.0/32)	dphase_m = 5'b01010 << (`WF_PHASE-5);
	// else if (phase_ana_norm<12.0/32)	dphase_m = 5'b01011 << (`WF_PHASE-5);
	// else if (phase_ana_norm<13.0/32)	dphase_m = 5'b01100 << (`WF_PHASE-5);
	// else if (phase_ana_norm<14.0/32)	dphase_m = 5'b01101 << (`WF_PHASE-5);
	// else if (phase_ana_norm<15.0/32)	dphase_m = 5'b01110 << (`WF_PHASE-5);
	// else if (phase_ana_norm<16.0/32)	dphase_m = 5'b01111 << (`WF_PHASE-5);
	// else if (phase_ana_norm<17.0/32)	dphase_m = 5'b10000 << (`WF_PHASE-5);
	// else if (phase_ana_norm<18.0/32)	dphase_m = 5'b10001 << (`WF_PHASE-5);
	// else if (phase_ana_norm<19.0/32)	dphase_m = 5'b10010 << (`WF_PHASE-5);
	// else if (phase_ana_norm<20.0/32)	dphase_m = 5'b10011 << (`WF_PHASE-5);
	// else if (phase_ana_norm<21.0/32)	dphase_m = 5'b10100 << (`WF_PHASE-5);
	// else if (phase_ana_norm<22.0/32)	dphase_m = 5'b10101 << (`WF_PHASE-5);
	// else if (phase_ana_norm<23.0/32)	dphase_m = 5'b10110 << (`WF_PHASE-5);
	// else if (phase_ana_norm<24.0/32)	dphase_m = 5'b10111 << (`WF_PHASE-5);
	// else if (phase_ana_norm<25.0/32)	dphase_m = 5'b11000 << (`WF_PHASE-5);
	// else if (phase_ana_norm<26.0/32)	dphase_m = 5'b11001 << (`WF_PHASE-5);
	// else if (phase_ana_norm<27.0/32)	dphase_m = 5'b11010 << (`WF_PHASE-5);
	// else if (phase_ana_norm<28.0/32)	dphase_m = 5'b11011 << (`WF_PHASE-5);
	// else if (phase_ana_norm<29.0/32)	dphase_m = 5'b11100 << (`WF_PHASE-5);
	// else if (phase_ana_norm<30.0/32)	dphase_m = 5'b11101 << (`WF_PHASE-5);
	// else if (phase_ana_norm<31.0/32)	dphase_m = 5'b11110 << (`WF_PHASE-5);
	// else								dphase_m = 5'b11111 << (`WF_PHASE-5);
end

// calibrete phase offset
reg [`WF_PHASE-1:0] nco_phase_s;
reg [`WF_PHASE-1:0] nco_phase_s_rnd; // 0<x<1
reg signed [`WF_PHASE-1:0] diff_phase_rnd, diff_phase_rnd_c; // -1<x<1
reg signed [`WF_PHASE-1:0] dphase_c, dphase_c_step, dphase_c_accum, dphase_c_ofst; // dphase for offset calibration
reg [`WF_PHASE-1:0] dphase_m_c;
reg [`WF_PHASE-1:0] rand_u24;

always @* begin
	nco_phase_s = nco_phase << (`WF_PHASE-`WF-os_main_aux);
	// rand_u24 = $random>>>(8+1);
	rand_u24 = 0;
	nco_phase_s_rnd = nco_phase_s + rand_u24;
	dphase_c = dphase_c_accum + dphase_c_ofst;
	dphase_m_c = dphase_m + dphase_c_accum;
	diff_phase_rnd = nco_phase_s_rnd - dphase_m_c;
	diff_phase_rnd_c = diff_phase_rnd - dphase_c_ofst;
	// dphase_c_step = diff_phase_rnd[`WF_PHASE-1]? (-`WF_PHASE'd256): (`WF_PHASE'd256);
	dphase_c_step = diff_phase_rnd>>>12;
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		dphase_c_accum <= 0;
		dphase_c_ofst <= 0;
	end else if (EN) begin 
		dphase_c_accum <= dphase_c_step + dphase_c_accum;
		// dphase_c_ofst <= 0.08*2**24;
		dphase_c_ofst <= 0;
	end
end

// ouput normalized phase error
// diffphase of dig and analog
// diffphase of dig and analog with digital random dither
assign PHE_NORM = diff_phase_rnd_c[`WF_PHASE-`WF-1]? (diff_phase_rnd_c[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase_rnd_c[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit

// test
integer fp1;
real r_dphase_c, r_rand_u24, r_diff_phase_rnd;

always @* begin
	r_dphase_c = $unsigned(dphase_c) * (2.0**-`WF_PHASE);
	r_rand_u24 = $unsigned(rand_u24) * (2.0**-`WF_PHASE);
	r_diff_phase_rnd = $signed(diff_phase_rnd) * (2.0**-`WF_PHASE);
end

initial begin
	fp1 = $fopen("diff_phase.txt");
end

always @(posedge CLK) begin
	$fstrobe(fp1, "%d", $signed(diff_phase_rnd));
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
reg [`WF-1:0] dsm_phe_remain;
reg [`WF-1:0] dsm_phe_remain_sl; // shift left 1bit
real dsm_phe_remain_real;
real err;

always @* begin
	dsm_phe_remain = DSM_PHE[`WF-1:0]; // 0<=x<1
	dsm_phe_remain_sl = dsm_phe_remain; // 0<=2*x<1.0
	dsm_phe_remain_real = $unsigned(dsm_phe_remain_sl) * (2.0**-`WF);
	// phase error between fod and pllaux
	err = 1.0 * $signed(PHE_NORM) * (2.0**-`WF);
	// err = (err>0)? 1: -1;
end

// LMS kdtc cali
real kdtc;
real x, x_d1, x_d2;

assign x = dsm_phe_remain_real;
assign dtc_dcw = x * kdtc;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		kdtc <= 900;
		x_d1 <= 0;
		x_d2 <= 0;
	end else if (EN) begin
		x_d1 <= x;
		x_d2 <= x_d1;
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
// output
MMD_DCW,
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
// input [2:0] PHE;

output reg [5:0] MMD_DCW; // MMD div range 4~63
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
	DTC_DCW <= dtc_dcw;
end

always @ (posedge CLK or negedge NRST) begin
    if (!NRST) begin
        FCW_FOD_I_sync <= 4;
    end else begin
        FCW_FOD_I_sync <= FCW_FOD_I; // sync with DSM_CAR, DSM_PHE
    end
end

assign {FCW_FOD_I, FCW_FOD_F} = FCW_FOD;

// translate fcw into mmd/dtc ctrl word
DSM_MASH1 U1_FOD_CTRL_DSM_MASH1 ( .CLK (CLK), .NRST (NRST), .EN (DSM_EN), .IN (FCW_FOD_F), .OUT (DSM_CAR), .PHE (DSM_PHE) );

// 0.5 quantization
assign phe_remain = DSM_PHE[`WF-1:0];

// calibration
// phase sync
wire [`WF-1:0] PHE_NORM;
reg PCALI_EN;

initial begin
	PCALI_EN = 1;
	#20e-6;
	PCALI_EN = 1;
end

CALI_PHASESYNC U1_FOD_CTRL_CALI_PHASESYNC (
.NRST(NRST),
.CLK(CLK),
.EN(PCALI_EN),
.FCW_FOD(FCW_FOD),
.FCW_PLL_MAIN_S(3'd5),
.FCW_PLL_AUX_S(3'd4),
.PHE_MEASURE(),
.PHE_NORM(PHE_NORM)
);

// dtc cali
real dtc_dcw_real;
reg DTCCALI_EN;

initial begin
	DTCCALI_EN = 0;
	#20e-6;
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