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

always @(posedge CLK or negedge NRST) begin
	if (!NRST) dphase_m <= 0;
	else begin
		case (PHE_MEASURE)
			3'b000: dphase_m <= 0; // 000 deg
			3'b001: dphase_m <= {3'b001, {(`WF_PHASE-3){1'b0}}}; // 045deg
			3'b010: dphase_m <= {3'b010, {(`WF_PHASE-3){1'b0}}}; // 090deg
			3'b011: dphase_m <= {3'b011, {(`WF_PHASE-3){1'b0}}}; // 135deg
			3'b100: dphase_m <= {3'b100, {(`WF_PHASE-3){1'b0}}}; // 180deg
			3'b101: dphase_m <= {3'b101, {(`WF_PHASE-3){1'b0}}}; // 224deg
			3'b110: dphase_m <= {3'b110, {(`WF_PHASE-3){1'b0}}}; // 270deg
			3'b111: dphase_m <= {3'b111, {(`WF_PHASE-3){1'b0}}}; // 315deg
		endcase
	end
end

// calibrete phase offset
reg [`WF_PHASE-1:0] nco_phase_s;
reg [`WF_PHASE-1:0] nco_phase_s_rnd;
reg signed [`WF_PHASE-1:0] diff_phase;
reg signed [`WF_PHASE-1:0] diff_phase_shift_ki;
reg [`WF_PHASE-1:0] dphase_c; // dphase for offset calibration
// reg [`WF_PHASE-1:0] rand24;

always @* begin
	nco_phase_s = nco_phase << (`WF_PHASE-`WF-os_main_aux);
	// rand24 = $random>>>(8+3);
	// nco_phase_s_rnd = nco_phase_s + rand24;
	dphase_c = diff_phase_shift_ki;
	diff_phase = nco_phase_s - (dphase_m + dphase_c);
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		diff_phase_shift_ki <= 0;
	end else begin 
		// phase sync convergence rate
		// shift 12, 20us, error<1e-3; shift 16, 500us, error<1e-5
		// dphase_c has a pattern with 1200ns period, maybe lead to a spur
		diff_phase_shift_ki <= (diff_phase >>> 12) + diff_phase_shift_ki; 
	end
end

// ouput normalized phase error
assign PHE_NORM = diff_phase[`WF_PHASE-`WF-1]? (diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit

// test
integer fp1;
real r_dphase_c, r_rand24;

always @* begin
	r_dphase_c = $signed(dphase_c) * (2.0**-`WF_PHASE);
	// r_rand24 = $signed(rand24) * (2.0**-`WF_PHASE);
end

initial begin
	fp1 = $fopen("diff_phase.txt");
end

always @(posedge CLK) begin
	$fstrobe(fp1, "%d", $signed(diff_phase));
end

endmodule

// // ------------------------------------------------------------
// // Module Name: CALI_DTCINL
// // Function: 0th/1st/2nd-order calibrate DTC INL
// // Authot: Yumeng Yang Date: 2023-11-17
// // Version: v1p0
// // ------------------------------------------------------------
// module CALI_DTCINL (
// // input
// NRST,
// CLK,
// EN,
// phe_remain,
// PHE,
// // output
// dtc_dcw
// );

// // io
// input NRST;
// input CLK;
// input EN;
// input real phe_remain; // [`WF-2:0] 0<x<0.5
// input [3:0] PHE;

// output real dtc_dcw;

// // internal signals
// // DSM residual error
// integer phe_msb;
// real phe_lsb;
// // LUTs
// real kdtcB_cali, kdtcC_cali;
// real LUTB [1:0];
// real LUTC [1:0];
// // RLS parameters
// parameter real lambda = 2.0**-8;
// parameter real KDTC = 1/8e9/160e-15;
// real Rn, Rn_d1;
// real corrxx;
// real deltabn [1:0];
// real deltabn0 [1:0];
// real en;

// // split segments
// always @* begin
// 	// 2 segments
// 	phe_msb = (phe_remain*2>=0.5)? 1: 0;
// 	phe_lsb = phe_remain - phe_msb*0.25;
// end

// // select coefficients from LUTs
// assign kdtcB_cali = LUTB[phe_msb]; assign kdtcC_cali = LUTC[phe_msb];

// initial begin
// 	LUTB[0] = KDTC;
// 	LUTB[1] = KDTC;
// 	LUTC[0] = 0;
// 	LUTC[1] = KDTC/2;
// end

// assign Rn = Rn_d1 * lambda + corrxx;
// assign corrxx = phe_msb * phe_msb + phe_lsb * phe_lsb;
// assign deltabn[0] = en * phe_lsb;
// assign deltabn[1] = en * phe_msb;

// always @ (posedge CLK or negedge NRST) begin
// 	if (!NRST) begin

// 	end else begin
// 		Rn_d1 <= Rn;
// 	end
// end


// endmodule
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

parameter real KDTC = 1/8e9/160e-15 * 1;

// io
input NARST;
input CLK;
input DSM_EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] PHE;

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

assign {FCW_FOD_I, FCW_FOD_F} = FCW_FOD;

// translate fcw into mmd/dtc ctrl word
DSM_MASH1 U1_FOD_CTRL_DSM_MASH1 ( .CLK (CLK), .NRST (NRST), .EN (DSM_EN), .IN (FCW_FOD_F), .OUT (DSM_CAR), .PHE (DSM_PHE) );

// 0.5 quantization
assign phe_quant = DSM_PHE[`WF-1];
assign phe_remain = DSM_PHE[`WF-2:0];

// calibration
CALI_PHASESYNC U1_FOD_CTRL_CALI_PHASESYNC (
.NRST(NRST),
.CLK(CLK),
.EN(1'b1),
.FCW_FOD(FCW_FOD),
.FCW_PLL_MAIN_S(3'd5),
.FCW_PLL_AUX_S(3'd4),
.PHE_MEASURE(PHE),
.PHE_NORM()
);

// dtc dcw calc
assign dtc_dcw = (phe_remain * (2.0**-`WF)) * KDTC ;

// test
real fcw_real;
real dsmphe_real;

always @* begin
	fcw_real = FCW_FOD * (2.0**-`WF);
	dsmphe_real = DSM_PHE * (2.0**-`WF);
end

endmodule