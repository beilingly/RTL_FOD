`define WI 6
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN

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
FREQ_C_EN,
FREQ_C_MODE,
FREQ_C_KS,
PHASE_CTRL,
PCALI_FREQDOWN,
PCALI_KS,
// output
PHE_NORM,
FREQ_C
);

// delay information
// PHE_MEASURE -> PHE_NORM delay 1 cycle

input NRST;
input CLK;
input EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] FCW_PLL_MAIN_S; // default to 32(2^5)
input [2:0] FCW_PLL_AUX_S; // defualt to 16(2^4)
input [`MP_SEG_BIN-1:0] PHE_MEASURE; // 0~31
input FREQ_C_EN;
input FREQ_C_MODE; // 0:linear mode; 1: 1step mode
input [4:0] FREQ_C_KS; // step shift 0 ~ 15
input [9:0] PHASE_CTRL; // manual phase adjustment
input [2:0] PCALI_FREQDOWN; // down scale phase cali freq, div1 ~ div128
input [4:0] PCALI_KS; // kdtc cali set to 8/12; phase cali set to 12/16

output [`WF-1:0] PHE_NORM; // 0<=x<1
output [`WI+`WF-1:0] FREQ_C;

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

// real phase_ana_norm;
// assign phase_ana_norm = simpleFOD2_TB.phase_ana_norm;
// always @(posedge CLK or negedge NRST) begin
// 	if (!NRST) dphase_m <= 0;
// 	else begin
// 		dphase_m <= $rtoi(phase_ana_norm * (2**`WF_PHASE));
// 	end
// end

// AUXPLL multi-phase cali
// wire [`MP_SEG*`WF_PHASE-1:0] DPHASE_SEG_ARR;
// CALI_FMP_PHASEOFST U2_PHASESYNC_FMP_PHASEOFST ( .NRST(NRST), .CLK(CLK), .EN(1'b1), .PHE_MEASURE(PHE_MEASURE), .DPHASE_SEG_ARR(DPHASE_SEG_ARR) );

// integer i;

// always @(posedge CLK or negedge NRST) begin
// 	if (!NRST) dphase_m <= 0;
// 	else begin
// 		dphase_m <= DPHASE_SEG_ARR[(PHE_MEASURE+1)*`WF_PHASE-1-:`WF_PHASE];
// 	end
// end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) dphase_m <= 0;
	else begin
		dphase_m <= PHE_MEASURE << (`WF_PHASE-`MP_SEG_BIN);
	end
end



// calibrete phase offset
reg [`WF_PHASE-1:0] nco_phase_s; // 0<x<1
reg [`WF_PHASE-1:0] dphase_m_c;
reg signed [`WF_PHASE-1:0] diff_phase; // -1<x<1
reg signed [`WF_PHASE-1:0] dphase_c, dphase_c_step; // dphase for offset calibration
reg [7:0] p_fdn_win_th;
reg [7:0] p_fdn_win_cnt;
reg p_fdn_win;


// down scale phase cali freq
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		p_fdn_win_th <= 128;
	end else begin
		p_fdn_win_th <= 1 << PCALI_FREQDOWN;
	end
end
// if pcali_freqdown == 0, p_fdn_win will always set to 1
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		p_fdn_win_cnt <= 0;
		p_fdn_win <= 0;
	end else begin
		if (p_fdn_win_cnt < p_fdn_win_th - 1) begin
			p_fdn_win_cnt <= p_fdn_win_cnt + 1;
			p_fdn_win <= 0;
		end else begin
			p_fdn_win_cnt <= p_fdn_win_cnt + 1 - p_fdn_win_th;
			p_fdn_win <= 1;
		end
	end
end

always @* begin
	nco_phase_s = nco_phase << (`WF_PHASE-`WF-os_main_aux);
	dphase_m_c = dphase_m + dphase_c;
	diff_phase = nco_phase_s - dphase_m_c;
	// phase sync convergence rate
	// shift 12, 20us, error<1e-3; shift 16, 500us, error<1e-5
	// dphase_c_step = EN? (diff_phase[`WF_PHASE-1]? (-`WF_PHASE'd256): (`WF_PHASE'd256)): 0;
	dphase_c_step = (EN & p_fdn_win)? diff_phase >>> PCALI_KS: 0;
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		dphase_c <= 0;
	end else if (EN) begin 
		// dphase_c has a pattern with 1200ns period, maybe lead to a spur, but that can be suppressed with a digital random dither
		dphase_c <= dphase_c_step + dphase_c;
	end
end

reg [1:0] freq_c_state; // 0: initial; 1: operate; 2,3: idle;
reg [`WI+`WF-1:0] freq_c_cnt_th, freq_c_cnt;
reg [`WF-1:0] freq_c_step; // 1 ~ 2^16-1
reg [`WI+`WF-1:0] freq_c;
reg freq_c_dir; // cali direction depend on sign of dphase_c
reg [`WF_PHASE-1:0] phase_manual;
reg [`WF_PHASE-1:0] dphase_c_man;

assign FREQ_C = freq_c;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		phase_manual <= 0;
	end else begin
		phase_manual <= PHASE_CTRL << (`WF_PHASE - 10);
	end
end

always @* begin
	dphase_c_man = dphase_c + phase_manual;
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		freq_c_state <= 0;
		freq_c_cnt_th <= 0;
		freq_c_cnt <= 0;
		freq_c <= 0;
		freq_c_dir <= 0;
		freq_c_step <= 0;
		phase_manual <= 0;
	end else begin
		if (FREQ_C_EN) begin
			if (FREQ_C_MODE) begin // sync phase in 1 step
				case (freq_c_state)
					2'b00: begin
						freq_c_state <= 2'b01;
						freq_c_dir <= dphase_c_man[`WF_PHASE-1]; // dphase_c[`WF_PHASE-1]? -1: 1
						freq_c_step <= dphase_c_man >> (`WF_PHASE - `WF - 1);
					end
					2'b01: begin
						freq_c_state <= 2'b10;
						freq_c <= freq_c_dir? -freq_c_step: freq_c_step;
					end
					2'b10: begin
						freq_c_state <= 2'b10;
						freq_c <= 0;
					end
					default: begin
						freq_c_state <= 2'b10;
						freq_c <= 0;
					end
				endcase
			end else begin // sync phase in multi period
				case (freq_c_state)
					2'b00: begin // initial
						freq_c_state <= 2'b01;
						// freq_c_cnt_th <= $unsigned(dphase_c) * (2.0**-24) * 2 * (2**16);
						freq_c_cnt_th <= dphase_c_man >> (`WF_PHASE - `WF + FREQ_C_KS - 1);
						freq_c_dir <= dphase_c_man[`WF_PHASE-1]; // dphase_c[`WF_PHASE-1]? -1: 1
						freq_c_step <= 1 << FREQ_C_KS;
					end
					2'b01: begin // operate
						if (freq_c_cnt < freq_c_cnt_th) begin
							freq_c_state <= 2'b01;
							freq_c_cnt <= freq_c_cnt + 1;
							freq_c <= freq_c_dir? -freq_c_step: freq_c_step;
						end else begin
							freq_c_state <= 2'b10;
							freq_c_cnt <= 0;
							freq_c <= 0;
						end
					end
					2'b10: begin // idle
						freq_c_state <= 2'b10;
						freq_c <= 0;
					end
					default: begin
						freq_c_state <= 2'b10;
						freq_c <= 0;
					end
				endcase
			end
		end else begin
			freq_c_state <= 0;
			freq_c_cnt_th <= 0;
			freq_c_cnt <= 0;
			freq_c <= 0;
			freq_c_dir <= 0;
			freq_c_step <= 0;
		end
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
	r_dphase_c = $unsigned(dphase_c) * (2.0**-`WF_PHASE) * 360 + 180;
	r_dphase_c = (r_dphase_c/360 - $floor(r_dphase_c/360))*360;
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
// Function: 0th/1st calibrate DTC INL；
// 			calibration method: piecewise + LMS + 0th/1st-order
//			time sequence:
//			DSM_PHE -> DTCDCW --- 3 cycels
// Authot: Yumeng Yang Date: 2024-3-14
// Version: v1p0
// ------------------------------------------------------------
module CALI_DTCINL (
// input
NRST,
CLK,
DTC_EN,
GAC_EN,
OFSTC_EN,
RT_EN,
DSM_PHE,
PHE_NORM,
PSEG,
CALIORDER,
KB,
KC,
KD,
KDTCB_INIT,
KDTCC_INIT,
KDTCD_INIT,
// output
DTCDCW,
);

// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NRST;
input CLK;
input DTC_EN;
input GAC_EN; // calibration en
input OFSTC_EN; // claibrate dff ofst
input RT_EN; // use MMD pos-neg retimer
input [`WF-1:0] DSM_PHE; // DSM output
input [`WF-1:0] PHE_NORM; // normalized phe
input [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
input [1:0] CALIORDER;
input [4:0] KB; // -16 ~ 15
input [4:0] KC; // -16 ~ 15
input [4:0] KD; // -16 ~ 15
input [9:0] KDTCB_INIT;
input [9:0] KDTCC_INIT;
input [9:0] KDTCD_INIT;

output reg [9:0] DTCDCW;

// internal signal
reg dsm_phe_qt;
reg [`WF-1:0] dsm_phe_remain;
reg [`WF-1:0] dsm_phe_remain_sl; // shift left 1bit
reg [`WF-1:0] err;

always @* begin
	if (RT_EN) begin
		dsm_phe_qt = DSM_PHE[`WF-1];
		dsm_phe_remain = DSM_PHE[`WF-2:0]; // 0<=x<0.5
		dsm_phe_remain_sl = dsm_phe_remain << 1; // 0<=2*x<1.0
	end else begin
		dsm_phe_qt = 0;
		dsm_phe_remain = DSM_PHE; // 0<=x<1
		dsm_phe_remain_sl = dsm_phe_remain; 
	end
	// phase error between fod and pllaux
	// err = 1.0 * $signed(PHE_NORM) * (2.0**-`WF);
	err = PHE_NORM;
end

// internal signals
// split DTC delay range into 4 segments
reg [10+`WF:0] LUTB [7:0];
reg [10+`WF:0] LUTC [7:0];
reg [10+`WF:0] LUTD [1:0];
wire [10+`WF:0] kdtcB_cali;
wire [10+`WF:0] kdtcC_cali;
wire [10+`WF:0] kdtcD_cali;
reg [2:0] phe_msb;
reg [`WF-1:0] phe_lsb;
reg phe_quant;
wire [11+`WF:0] pro_kdtcB_phel;
wire [10+`WF:0] product1, product0, product2, product;
reg [10+`WF:0] kdtcC_cali_reg1, kdtcC_cali_reg2;
reg [10+`WF:0] kdtcD_cali_reg1, kdtcD_cali_reg2;
wire [9:0] dtc_temp;

always @* begin
	phe_msb = dsm_phe_remain_sl[`WF-1:`WF-3] >> PSEG;
	phe_lsb = (dsm_phe_remain_sl<<(3-PSEG))>>(3-PSEG);
	phe_quant = dsm_phe_qt;
end

assign kdtcB_cali = LUTB[phe_msb]; assign kdtcC_cali = LUTC[phe_msb]; assign kdtcD_cali = LUTD[phe_quant];
// 1st cali
SWIWFPRO #(11, 2, `WF) U2_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CLK), .PROS(pro_kdtcB_phel), .MULTIAS(kdtcB_cali), .MULTIBS({2'b00, phe_lsb}) );
assign product1 = pro_kdtcB_phel;
// 0th cali
assign product0 = kdtcC_cali_reg2;
// dc ofst
assign product2 = kdtcD_cali_reg2;
// combine dcofst + 0th cali + 1st cali
assign product = product2 + product1 + product0;
assign dtc_temp = product[`WF-1]? (product[9+`WF:`WF]+1'b1): product[9+`WF:`WF];

// register
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		kdtcC_cali_reg1 <= 0;
		kdtcC_cali_reg2 <= 0;

		kdtcD_cali_reg1 <= 0;
		kdtcD_cali_reg2 <= 0;
	end else begin
		kdtcC_cali_reg1 <= kdtcC_cali;
		kdtcC_cali_reg2 <= kdtcC_cali_reg1;

		kdtcD_cali_reg1 <= kdtcD_cali;
		kdtcD_cali_reg2 <= kdtcD_cali_reg1;
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		DTCDCW <= 0;
	end else begin
		DTCDCW <= DTC_EN? dtc_temp: 0;
	end
end

// DTC NONLINEAR CALI
reg [`WF-1:0] phel_reg1, phel_reg2, phel_reg3, phel_reg4, phel_sync;
reg pheq_reg1, pheq_reg2, pheq_reg3, pheq_reg4, pheq_sync;
reg [2:0] phem_reg1, phem_reg2, phem_reg3, phem_reg4, phem_sync, phem_sync_reg, phem_sync_reg_d1, phem_sync_reg_d2;

// generate synchronouse phe and phe_sig
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		phel_reg1 <= 0; phel_reg2 <= 0; phel_reg3 <= 0; phel_reg4 <= 0; phel_sync <= 0; 
		phem_reg1 <= 0; phem_reg2 <= 0; phem_reg3 <= 0; phem_reg4 <= 0; phem_sync <= 0; 
		pheq_reg1 <= 0; pheq_reg2 <= 0; pheq_reg3 <= 0; pheq_reg4 <= 0; pheq_sync <= 0;
	end else if (GAC_EN) begin
		phel_reg1 <= phe_lsb; phel_reg2 <= phel_reg1; phel_reg3 <= phel_reg2; phel_reg4 <= phel_reg3; phel_sync <= phel_reg4; 
		phem_reg1 <= phe_msb; phem_reg2 <= phem_reg1; phem_reg3 <= phem_reg2; phem_reg4 <= phem_reg3; phem_sync <= phem_reg4; 
		pheq_reg1 <= phe_quant; pheq_reg2 <= pheq_reg1; pheq_reg3 <= pheq_reg2; pheq_reg4 <= pheq_reg3; pheq_sync <= pheq_reg4;
	end
end

// LUT calibration
wire signed [10+`WF:0] lms_errB, lms_errB_ext;
wire signed [10+`WF:0] lms_errC, lms_errC_ext;
wire signed [10+`WF:0] lms_errD, lms_errD_ext;
reg [10+`WF:0] lms_errB_ext_reg;
reg [10+`WF:0] lms_errC_ext_reg;
reg [10+`WF:0] lms_errD_ext_reg;

// INL cali
integer i;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		// LUT initial
		for (i = 7; i >= 0; i = i-1) begin
			LUTB[i] <= KDTCB_INIT<<`WF;
		end
		for (i = 7; i >= 0; i = i-1) begin
			LUTC[i] <= (KDTCC_INIT*i)<<`WF;		
		end
	end else if (GAC_EN) begin
		LUTB[phem_sync_reg_d2] <= LUTB[phem_sync_reg_d2] + lms_errB_ext_reg;
		LUTC[phem_sync_reg] <= (|phem_sync_reg)? (LUTC[phem_sync_reg] + lms_errC_ext_reg): 0;
	end
end

// DFF ofst cali
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		// LUT initial
		for (i = 1; i >= 0; i = i-1) begin
			LUTD[i] <= KDTCD_INIT<<`WF;		
		end
	end else if (OFSTC_EN) begin
		LUTD[1] <= LUTD[1] + lms_errD_ext_reg;
	end
end



// piecewise start point cali
wire signed [`WF-1:0] err_signed;

assign err_signed = err;

assign lms_errC = err_signed; // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errC_ext = CALIORDER[0]? (KC[4]? (lms_errC>>>(~KC+1'b1)): (lms_errC<<<KC)): 0;

// 1-st nonlinear
wire [2+`WF-1:0] a_err;
wire [2+`WF-1:0] b_phel_sync;
wire signed [3+`WF-1:0] pro_err_phel;

assign a_err = err_signed;
assign b_phel_sync = {2'b00, phel_sync};
assign lms_errB = pro_err_phel; // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
SWIWFPRO #(2, 2, `WF) U3_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CLK), .PROS(pro_err_phel), .MULTIAS(a_err), .MULTIBS(b_phel_sync) );
assign lms_errB_ext = CALIORDER[1]? (KB[4]? (lms_errB>>>(~KB+1'b1)): (lms_errB<<<KB)): 0;

// ofst
// assign lms_errD = pheq_sync? ( err_signed[`WF-1]? (~err_signed + 1): err_signed): 0; // only check duty-cycle when quant == 1
assign lms_errD = pheq_sync? err_signed: 0;
assign lms_errD_ext = OFSTC_EN? (KD[4]? (lms_errD>>>(~KD+1'b1)): (lms_errD<<<KD)): 0;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		phem_sync_reg <= 0;
		phem_sync_reg_d1 <= 0;
		phem_sync_reg_d2 <= 0;

		lms_errB_ext_reg <= 0;
		lms_errC_ext_reg <= 0;
	end else if (GAC_EN) begin
		phem_sync_reg <= phem_sync;
		phem_sync_reg_d1 <= phem_sync_reg;
		phem_sync_reg_d2 <= phem_sync_reg_d1;

		lms_errB_ext_reg <= lms_errB_ext;
		lms_errC_ext_reg <= lms_errC_ext;
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		lms_errD_ext_reg <= 0;
	end else if (OFSTC_EN) begin
		lms_errD_ext_reg <= lms_errD_ext;
	end
end

// // LMS kdtc cali
// real kdtc, rerr;
// real x, x_d1, x_d2, x_d3, x_d4, x_d5, x_d6;
// real dsm_phe_remain_real;
// integer dtc_dcw;
// reg [9:0] dtc_dcw_reg1, dtc_dcw_reg2, dtc_dcw_reg3;

// assign rerr = $signed(err) * (2.0**-`WF);
// assign dsm_phe_remain_real = $unsigned(dsm_phe_remain_sl) * (2.0**-`WF);
// assign x = dsm_phe_remain_real;
// assign dtc_dcw = $rtoi(x * kdtc);

// always @ (posedge CLK or negedge NRST) begin
// 	if (!NRST) begin
// 		kdtc <= 780;

// 		x_d1 <= 0;
// 		x_d2 <= 0;
// 		x_d3 <= 0;
// 		x_d4 <= 0;
// 		x_d5 <= 0;
// 		x_d6 <= 0;
// 	end else if (GAC_EN) begin
// 		x_d1 <= x;
// 		x_d2 <= x_d1;
// 		x_d3 <= x_d2;
// 		x_d4 <= x_d3;
// 		x_d5 <= x_d4;
// 		x_d6 <= x_d4;

// 		kdtc <= kdtc + rerr * x_d5 * 0.1;
// 	end
// end

// always @ (posedge CLK or negedge NRST) begin
// 	if (!NRST) begin
// 		dtc_dcw_reg1 <= 0;
// 		dtc_dcw_reg2 <= 0;
// 		dtc_dcw_reg3 <= 0;
// 	end else begin
// 		dtc_dcw_reg1 <= dtc_dcw;
// 		dtc_dcw_reg2 <= dtc_dcw_reg1;
// 		dtc_dcw_reg3 <= dtc_dcw_reg2;
// 	end
// end

// test
real lutb0, lutb1, lutb2, lutb3, lutc0, lutc1, lutc2, lutc3, lutd0, lutd1;

always @* begin
	lutb0 = $signed(LUTB[0]) * (2.0**(-`WF));
	lutb1 = $signed(LUTB[1]) * (2.0**(-`WF));
	lutb2 = $signed(LUTB[2]) * (2.0**(-`WF));
	lutb3 = $signed(LUTB[3]) * (2.0**(-`WF));
	lutc0 = $signed(LUTC[0]) * (2.0**(-`WF));
	lutc1 = $signed(LUTC[1]) * (2.0**(-`WF));
	lutc2 = $signed(LUTC[2]) * (2.0**(-`WF));
	lutc3 = $signed(LUTC[3]) * (2.0**(-`WF));
	lutd0 = $signed(LUTD[0]) * (2.0**(-`WF));
	lutd1 = $signed(LUTD[1]) * (2.0**(-`WF));
end

endmodule
// ------------------------------------------------------------
// Module Name: FOD_CTRL
// Function: generate DTC/RT/MMD ctrl word
// Authot: Yumeng Yang Date: 2024-3-14
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
// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NARST;
input CLK;
input DSM_EN;
input [`WI+`WF-1:0] FCW_FOD;
input [`MP_SEG_BIN-1:0] PHE;
// input [3:0] PHE;

output reg [5:0] MMD_DCW; // MMD div range 4~63
output reg RT_DCW; // 0: posedge retimer; 1: negedge retimer(delay for 0.5 FPLL8G cycle)
output [9:0] DTC_DCW;


// code begin
wire NRST;
wire [`WI+`WF-1:0] FCW_FOD;
wire [`WI-1:0] FCW_FOD_I;
wire [`WF-1:0] FCW_FOD_F;
wire DSM_CAR;
wire [`WF-1:0] DSM_PHE; // ufix, 0<x<1


// phase cali
reg RT_EN;
reg PCALI_EN;
reg FREQ_C_EN;
reg FREQ_C_MODE;
reg [4:0] FREQ_C_KS;
reg [9:0] PHASE_CTRL;
reg [2:0] PCALI_FREQDOWN;
reg [4:0] PCALI_KS; // 0~16
wire [`WF-1:0] PHE_NORM;
wire [`WI+`WF-1:0] FREQ_C;

initial begin
	RT_EN = 1;
	PCALI_EN = 1;
	FREQ_C_EN = 0;
	FREQ_C_MODE = 0;
	FREQ_C_KS = 0;
	PHASE_CTRL = 0;
	PCALI_FREQDOWN = 0;
	PCALI_KS = 8;
end

// INL cali
reg DTCCALI_EN;
reg OFSTCALI_EN;
reg [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
reg [1:0] CALIORDER;
reg [4:0] KB; // -16 ~ 15
reg [4:0] KC; // -16 ~ 15
reg [4:0] KD; // -16 ~
reg [9:0] KDTCB_INIT;
reg [9:0] KDTCC_INIT;
reg [9:0] KDTCD_INIT;

initial begin
	PSEG = 3;

	CALIORDER = 2'b11;

	KB = -5'd3;
	KC = -5'd3;
	KD = -5'd5;

	KDTCB_INIT = 10'd390 * 1;
	KDTCC_INIT = 10'd195;
	KDTCD_INIT = 10'd0;

	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
	#100e-6;
	DTCCALI_EN = 1;
	OFSTCALI_EN = 0;
end

assign NRST = NARST;

// FOD phase adjust according PCALI 
assign {FCW_FOD_I, FCW_FOD_F} = FCW_FOD + FREQ_C;

// 0.5 quantization
reg phe_quant;
reg [`WF-1:0] phe_remain; // 0<x<0.5

always @* begin
	if (RT_EN) begin
		phe_quant = DSM_PHE[`WF-1];
		phe_remain = DSM_PHE[`WF-2:0];
	end else begin
		phe_quant = 0;
		phe_remain = DSM_PHE;
	end
end

// DCW output
// sync MMD, RT, DTC DCW
reg [5:0] mmd_dcw_d1;
reg rt_dcw_d1, rt_dcw_d2;
always @ (posedge CLK or negedge NRST) begin
	
	if (!NRST) begin
		mmd_dcw_d1 <= 4;
		MMD_DCW <= 4;

		rt_dcw_d1 <= 0;
		rt_dcw_d2 <= 0;
		RT_DCW <= 0;
	end else begin
		mmd_dcw_d1 <= FCW_FOD_I + DSM_CAR;
		MMD_DCW <= mmd_dcw_d1;

		rt_dcw_d1 <= phe_quant;
		rt_dcw_d2 <= rt_dcw_d1;
		RT_DCW <= rt_dcw_d2;
	end
end

// translate fcw into mmd/dtc ctrl word
DSM_MASH1 U1_FOD_CTRL_DSM_MASH1 ( .CLK (CLK), .NRST (NRST), .EN (DSM_EN), .IN (FCW_FOD_F), .OUT (DSM_CAR), .PHE (DSM_PHE) );

// calibration
// phase sync
CALI_PHASESYNC U1_FOD_CTRL_CALI_PHASESYNC (
.NRST(NRST),
.CLK(CLK),
.EN(PCALI_EN),
.FCW_FOD(FCW_FOD),
.FCW_PLL_MAIN_S(3'd5),
.FCW_PLL_AUX_S(3'd2),
.PHE_MEASURE(PHE),
.FREQ_C_EN(FREQ_C_EN),
.FREQ_C_MODE(FREQ_C_MODE),
.FREQ_C_KS(FREQ_C_KS),
.PHASE_CTRL(PHASE_CTRL),
.PCALI_FREQDOWN(PCALI_FREQDOWN),
.PCALI_KS(PCALI_KS),
.PHE_NORM(PHE_NORM),
.FREQ_C(FREQ_C)
);

CALI_DTCINL U1_FOD_CTRL_CALI_DTCINL (
.NRST(NRST),
.CLK(CLK),
.DTC_EN(1'b1),
.GAC_EN(DTCCALI_EN),
.OFSTC_EN(OFSTCALI_EN),
.RT_EN(RT_EN),
.DSM_PHE(DSM_PHE),
.PHE_NORM(PHE_NORM),
.PSEG(PSEG),
.CALIORDER(CALIORDER),
.KB(KB),
.KC(KC),
.KD(KD),
.KDTCB_INIT(KDTCB_INIT),
.KDTCC_INIT(KDTCC_INIT),
.KDTCD_INIT(KDTCD_INIT),
.DTCDCW(DTC_DCW)
);


// test
real fcw_real;
real dsmphe_real;

always @* begin
	fcw_real = FCW_FOD * (2.0**-`WF);
	dsmphe_real = DSM_PHE * (2.0**-`WF);
end

endmodule