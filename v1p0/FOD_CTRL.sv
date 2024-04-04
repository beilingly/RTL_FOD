`timescale 1s/1fs

`define WI 7
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN
// -------------------------------------------------------
// Module Name: FCW_LFSR9_RST1
// Function: 9 bit LFSR used in FCW for dither, set initial state to 1
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0, according to FOD v1p0
// -------------------------------------------------------
module FCW_LFSR10_RST1 (
CLK,
NRST,
EN,
URN10B
);

input CLK;
input NRST;
input EN;
output reg [9:0] URN10B;

wire lfsr_fb;
reg [16:1] lfsr;
reg [9:0] lfsr_10b;
integer i;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		URN10B <= 0;
	end else begin
		URN10B <= EN? lfsr_10b: 0;
	end
end

always @* begin
    lfsr_10b = lfsr[10:1];
end

// create feedback polynomials
assign lfsr_fb = lfsr[16] ^~ lfsr[15] ^~ lfsr[13] ^~ lfsr[4];

always @(posedge CLK or negedge NRST) begin
	if(!NRST)
		lfsr <= 1;
	else if (EN) begin
		lfsr <= {lfsr[15:1], lfsr_fb};
	end else begin
		lfsr <= 1;
	end
end

endmodule

// -------------------------------------------------------
// Module Name: SYSPSYNCRST
// Function: system phase synchronization rst signal generator
// Author: Yang Yumeng Date: 2024-3-20
// Version: v1p0, based on 3109v3
// -------------------------------------------------------
module SYSPSYNCRST (
NRST,
CLK,
SYS_REF,
SYS_EN,
SYNC_NRST
);

input NRST;
input CLK;
input SYS_REF;
input SYS_EN;
output SYNC_NRST;


reg sys_ref_d1;
reg sys_ref_d2;
reg sys_ref_d3;
reg sys_ref_d4;
wire sys_comb;
wire sys_ctrl;
reg sys_pcali_en; // use it to reset NCO and DSM, is independent with LO_PHASECAL_EN
reg [2:0] sys_cnt; // counter for posedge of sys ref
reg sys_mask;


// reset signal generation
// counter for system reference
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		sys_cnt <= 0;
	end else begin
		if (sys_comb && (sys_cnt<7)) begin
			sys_cnt <= sys_cnt + 1;
		end else if (SYS_EN==1'b0) begin
			sys_cnt <= 0;
		end
	end
end

always @* begin
	sys_mask = (sys_cnt==3'd0);
end

// sys phase
always @ (posedge CLK) begin
	sys_ref_d1 <= SYS_REF;
	sys_ref_d2 <= sys_ref_d1;
	sys_ref_d3 <= sys_ref_d2;
	sys_ref_d4 <= sys_ref_d3;
end

assign sys_comb = sys_ref_d3 & (~sys_ref_d4);
assign sys_ctrl = SYS_EN & sys_comb & sys_mask;
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin 
		sys_pcali_en <= 1'b0;
	end else begin
		if ((sys_pcali_en==1'b0)&&(sys_ctrl==1'b1)) begin
			sys_pcali_en <= 1'b1;
		end else if (SYS_EN==1'b0) begin
			sys_pcali_en <= 1'b0;
		end
	end
end

assign SYNC_NRST = ~sys_ctrl;

endmodule
// -------------------------------------------------------
// Module Name: SYNCRSTGEN
// Function: generate synchronous reset
// Author: Yang Yumeng Date: 4/2 2022
// Version: v1p0, cp from BBPLL202108
// -------------------------------------------------------
module SYNCRSTGEN (
CLK,
NARST,
NRST
);

input CLK;
input NARST;
output NRST;

reg [2:0] rgt;

assign NRST = rgt[2];

always @ (posedge CLK or negedge NARST) begin
	if (!NARST) begin
		rgt <= 3'b000;
	end else begin
		rgt <= {rgt[1:0], 1'b1};
	end
end

endmodule
// -------------------------------------------------------
// Module Name: DSM_MASH1_X4
// Function: MASH1
//			1. output 4 ca and phe in clk0~3 domain simultaneously
//			2. accumulate step is set to 4*fcw_f
// Author: Yang Yumeng Date: 2024-3-17
// Version: v1p0
// -------------------------------------------------------
module DSM_MASH1_X4(
CLK,
NRST,
EN,
SYNC_NRST,
DSM_SYNC_NRST_EN,
IN_X4,
OUT_X4,
PHE_X4
);

// io
input CLK;
input NRST;
input EN;
input SYNC_NRST;
input DSM_SYNC_NRST_EN;
input [4*`WF-1:0] IN_X4;
output reg [3:0] OUT_X4; // ufix, 0 to 1
output reg [4*`WF-1:0] PHE_X4; // ufix, 0<x<1

// internal signal
wire [`WF:0] sum0_temp, sum1_temp, sum2_temp, sum3_temp;
wire [`WF-1:0] sum0, sum1, sum2, sum3;
reg [`WF-1:0] sum3_reg;
wire ca0, ca1, ca2, ca3;

wire sync_nrst;

assign sync_nrst = DSM_SYNC_NRST_EN? SYNC_NRST: 1;

// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT_X4 <= 0;
		PHE_X4 <= 0;
	end else if (EN) begin
		if (!sync_nrst) begin
			OUT_X4 <= 0;
			PHE_X4 <= 0;	
		end else begin
			OUT_X4 <= {ca3, ca2, ca1, ca0};
			PHE_X4 <= {sum3, sum2, sum1, sum0};
		end
	end
end

// adder and quantization
// stage 1
assign sum0_temp = sum3_reg + IN_X4[1*`WF-1-:`WF];
assign sum0 = sum0_temp[`WF-1:0];
assign ca0 = sum0_temp[`WF];
// stage 2
assign sum1_temp = sum0 + IN_X4[2*`WF-1-:`WF];
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = sum1_temp[`WF];
// stage 3
assign sum2_temp = sum1 + IN_X4[3*`WF-1-:`WF];
assign sum2 = sum2_temp[`WF-1:0];
assign ca2 = sum2_temp[`WF];
// stage 4
assign sum3_temp = sum2 + IN_X4[4*`WF-1-:`WF];
assign sum3 = sum3_temp[`WF-1:0];
assign ca3 = sum3_temp[`WF];

reg [`WF-1:0] sum0_init, sum1_init, sum2_init, sum3_init;

always @* begin
	sum0_init = 0;
	sum1_init = sum0_init + IN_X4[2*`WF-1-:`WF];
	sum2_init = sum1_init + IN_X4[3*`WF-1-:`WF];
	sum3_init = sum2_init + IN_X4[4*`WF-1-:`WF];
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum3_reg <= sum3_init;
	else if (EN) begin 
		if (!sync_nrst) sum3_reg <= 0;
		else sum3_reg <= sum3;
	end
end

real r_phe_x4_0, r_phe_x4_1, r_phe_x4_2, r_phe_x4_3;
real r_out_x4_0, r_out_x4_1, r_out_x4_2, r_out_x4_3;

always @* begin
	r_phe_x4_0 = PHE_X4[1*`WF-1-:`WF] * (2.0**-`WF);
	r_phe_x4_1 = PHE_X4[2*`WF-1-:`WF] * (2.0**-`WF);
	r_phe_x4_2 = PHE_X4[3*`WF-1-:`WF] * (2.0**-`WF);
	r_phe_x4_3 = PHE_X4[4*`WF-1-:`WF] * (2.0**-`WF);

	r_out_x4_0 = OUT_X4[0];
	r_out_x4_1 = OUT_X4[1];
	r_out_x4_2 = OUT_X4[2];
	r_out_x4_3 = OUT_X4[3];
end

endmodule
// ------------------------------------------------------------
// Module Name: PHEGEN_NCO
// Function:    1. a nco can reset to a specific phase state correspond to clk0-3
//              2. calculate normalized phe according to phe_measure
// 				PHE_MEASURE -> PHE_NORM: 1p
// Authot: Yumeng Yang Date: 2024-3-16
// Version: v1p0
// ------------------------------------------------------------
module PHEGEN_NCO (
NRST,
CLK,
EN,
FCW_FOD,
FCW_PLL_MAIN_S,
FCW_PLL_AUX_S,
PHE_MEASURE,
PCALI_KS,
dphase_c,
dphase_c_step,
PHE_NORM,
SYNC_NRST,
NCO_SYNC_NRST_EN
);

parameter integer k = 0;

input NRST;
input CLK;
input EN;
input SYNC_NRST;
input NCO_SYNC_NRST_EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] FCW_PLL_MAIN_S; // default to 32(2^5)
input [2:0] FCW_PLL_AUX_S; // defualt to 16(2^4)
input [`MP_SEG_BIN-1:0] PHE_MEASURE; // 0~31
input [4:0] PCALI_KS; // kdtc cali set to 8/12; phase cali set to 12/16
input [`WF_PHASE-1:0] dphase_c;
output reg [`WF_PHASE-1:0] dphase_c_step; // dphase for offset calibration
output [`WF-1:0] PHE_NORM; // normalized phe

// Numeric Controled Oscillator
reg [2:0] os_main_aux; // 0~5
reg [`WI+`WF-1:0] fcw_os_aux;
reg [`WI+`WF-1:0] fcw_os_aux_residual;
reg [`WI+`WF-1:0] fcw_os_aux_residual_x4;
reg [`WI+`WF-1:0] module_threshold;
reg [`WI+`WF-1:0] nco_phase;
reg [`WI+`WF-1:0] nco_phase_init [3:0];
reg [`WI+`WF-1:0] nco_phase_d1;
reg nco_phase_c; // sub-integer mode

// calculate oversampling rate fmod/fpll_aux
always @* begin
	os_main_aux = FCW_PLL_MAIN_S - FCW_PLL_AUX_S;
	fcw_os_aux = FCW_FOD; // shift right by os_main_aux
	fcw_os_aux_residual = (fcw_os_aux<<(`WI-os_main_aux)) >> (`WI-os_main_aux); // fracional part
	fcw_os_aux_residual_x4 = (fcw_os_aux<<(`WI-os_main_aux+2)) >> (`WI-os_main_aux);
	module_threshold = 1'b1<<(`WF+os_main_aux);
	// nco phase accumulate
	nco_phase = nco_phase_d1 + fcw_os_aux_residual_x4;
	if (nco_phase >= module_threshold) begin
		nco_phase = nco_phase - module_threshold;
		nco_phase_c = ~|nco_phase;
	end else begin
		nco_phase = nco_phase;
		nco_phase_c = 0;
	end

    // nco initial phase calc
    // clk0
    nco_phase_init[0] = 0;
    // clk1
    nco_phase_init[1] = nco_phase_init[0] + fcw_os_aux_residual;
	if (nco_phase_init[1] >= module_threshold) begin
		nco_phase_init[1] = nco_phase_init[1] - module_threshold;
	end else begin
		nco_phase_init[1] = nco_phase_init[1];
	end
    // clk2
    nco_phase_init[2] = nco_phase_init[1] + fcw_os_aux_residual;
	if (nco_phase_init[2] >= module_threshold) begin
		nco_phase_init[2] = nco_phase_init[2] - module_threshold;
	end else begin
		nco_phase_init[2] = nco_phase_init[2];
	end
    // clk3
    nco_phase_init[3] = nco_phase_init[2] + fcw_os_aux_residual;
	if (nco_phase_init[3] >= module_threshold) begin
		nco_phase_init[3] = nco_phase_init[3] - module_threshold;
	end else begin
		nco_phase_init[3] = nco_phase_init[3];
	end
end


// phase sync rst nco
wire sync_nrst;
assign sync_nrst = NCO_SYNC_NRST_EN? SYNC_NRST: 1;

reg [5:0] NRST_dly; // delay 1~6
reg [5:0] sync_nrst_dly;

always @(posedge CLK) begin
	if (!NRST) begin
		NRST_dly <= 0;
		sync_nrst_dly <= 6'h3f;
	end else begin
		NRST_dly <= {NRST_dly[4:0], NRST};
		sync_nrst_dly <= {sync_nrst_dly[4:0], sync_nrst};
	end
end

always @(posedge CLK or negedge NRST) begin
	if (!NRST_dly[5]) begin
		nco_phase_d1 <= nco_phase_init[k];
	end else if (EN) begin
		if (!sync_nrst_dly[5]) nco_phase_d1 <= nco_phase_init[k];
		else nco_phase_d1 <= nco_phase;
	end
end

// map analog phase to digital
reg [`WF_PHASE-1:0] dphase_m;

// real phase_ana_norm, phase_ana_norm_0, phase_ana_norm_1, phase_ana_norm_2, phase_ana_norm_3;

// assign phase_ana_norm_0 = FOD_2lane_TB.phase_ana_norm_bus[0];
// assign phase_ana_norm_1 = FOD_2lane_TB.phase_ana_norm_bus[1];
// assign phase_ana_norm_2 = FOD_2lane_TB.phase_ana_norm_bus[2];
// assign phase_ana_norm_3 = FOD_2lane_TB.phase_ana_norm_bus[3];

// always @* begin
// 	if (k==0) phase_ana_norm = phase_ana_norm_0;
// 	else if (k==1) phase_ana_norm = phase_ana_norm_1;
// 	else if (k==2) phase_ana_norm = phase_ana_norm_2;
// 	else phase_ana_norm = phase_ana_norm_3;
// end

// always @(posedge CLK or negedge NRST) begin
// 	if (!NRST) dphase_m <= 0;
// 	else if (EN) begin
// 		dphase_m <= $rtoi(phase_ana_norm * (2**`WF_PHASE));
// 	end else begin
// 		dphase_m <= 0;
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
	if (!NRST) begin
		dphase_m <= 0;
	end else if (EN) begin
		dphase_m <= PHE_MEASURE << (`WF_PHASE-`MP_SEG_BIN);
	end else begin
		dphase_m <= 0;
	end
end

// calculate phase offset
reg [`WF_PHASE-1:0] nco_phase_s; // 0<x<1
reg [`WF_PHASE-1:0] dphase_m_c;
reg signed [`WF_PHASE-1:0] diff_phase; // -1<x<1

always @* begin
	nco_phase_s = nco_phase << (`WF_PHASE-`WF-os_main_aux);
	dphase_m_c = dphase_m + dphase_c;
	diff_phase = nco_phase_s - dphase_m_c;
	// phase sync convergence rate
	// shift 12, 20us, error<1e-3; shift 16, 500us, error<1e-5
	// dphase_c_step = EN? (diff_phase[`WF_PHASE-1]? (-`WF_PHASE'd256): (`WF_PHASE'd256)): 0;
	dphase_c_step = EN? diff_phase >>> PCALI_KS: 0;
end

// ouput normalized phase error
// diffphase of dig and analog
// assign PHE_NORM = diff_phase[`WF_PHASE-`WF-1]? (diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit
// diffphase of dig and analog with digital random dither
assign PHE_NORM = diff_phase[`WF_PHASE-`WF-1]? (diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]+1'b1): diff_phase[`WF_PHASE-1:`WF_PHASE-`WF]; // round to `WF bit

// test
integer fp1;
real r_dphase_c, r_diff_phase, r_nco_phase;

always @* begin
	r_dphase_c = $unsigned(dphase_c) * (2.0**-`WF_PHASE) * 360 + 180;
	r_dphase_c = (r_dphase_c/360 - $floor(r_dphase_c/360))*360;
	r_diff_phase = $signed(diff_phase) * (2.0**-`WF_PHASE);
	r_nco_phase = $unsigned(nco_phase_s) * (2.0**-`WF_PHASE);
end

endmodule

// ------------------------------------------------------------
// Module Name: FREQCGEN
// Function:    1. calc fcw_cali word correspond to clk0-3
// Authot: Yumeng Yang Date: 2024-3-17
// Version: v1p0
// ------------------------------------------------------------
module FREQCGEN (
NRST,
CLK,
FREQ_C_EN,
FREQ_C_MODE,
FREQ_C_KS,
PHASE_CTRL,
dphase_c,
FREQ_C
);

parameter integer k = 0;

input NRST;
input CLK;
input FREQ_C_EN;
input FREQ_C_MODE; // 0:linear mode; 1: 1step mode
input [4:0] FREQ_C_KS; // step shift 0 ~ 15
input [9:0] PHASE_CTRL; // manual phase adjustment
input [`WF_PHASE-1:0] dphase_c;
output reg [`WI+`WF-1:0] FREQ_C;

reg [1:0] freq_c_state; // 0: initial; 1: operate; 2,3: idle;
reg [`WI+`WF-1:0] freq_c_cnt_th, freq_c_cnt;
reg [`WI+`WF-1:0] freq_c_step; // 1 ~ 2^16-1
reg [`WI+`WF-1:0] freq_c;
// reg freq_c_dir; // cali direction depend on sign of dphase_c
reg [`WF_PHASE-1:0] phase_manual;
reg [`WF_PHASE-1:0] dphase_c_man;
reg [`WF_PHASE-1:0] dphase_c_man_abs;

always @* begin
	FREQ_C = freq_c;
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		phase_manual <= 0;
	end else begin
		phase_manual <= PHASE_CTRL << (`WF_PHASE - 10);
	end
end

always @* begin
	dphase_c_man = dphase_c + phase_manual;
	dphase_c_man_abs = dphase_c_man[`WF_PHASE-1]? (~dphase_c_man + 1'b1): dphase_c_man;
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		freq_c_state <= 0;
		freq_c_cnt_th <= 0;
		freq_c_cnt <= k;
		freq_c <= 0;
		// freq_c_dir <= 0;
		freq_c_step <= 0;
		phase_manual <= 0;
	end else begin
		if (FREQ_C_EN) begin
			if (FREQ_C_MODE) begin // sync phase in 1 step
                if (k == 0) begin // clk0, in other clk domain freq_c is 0
                    case (freq_c_state)
                        2'b00: begin
                            freq_c_state <= 2'b01;
                            // freq_c_dir <= dphase_c_man[`WF_PHASE-1]; // dphase_c[`WF_PHASE-1]? -1: 1
                            freq_c_step <= dphase_c_man >> (`WF_PHASE - `WF - 3);
                        end
                        2'b01: begin
                            freq_c_state <= 2'b10;
                            // freq_c <= freq_c_dir? -freq_c_step: freq_c_step;
							freq_c <= freq_c_step;
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
                end
			end else begin // sync phase in multi period
				case (freq_c_state)
					2'b00: begin // initial
						freq_c_state <= 2'b01;
						// freq_c_cnt_th <= $unsigned(dphase_c) * (2.0**-24) * 8 * (2**16);
						freq_c_cnt_th <= dphase_c_man >> (`WF_PHASE - `WF + FREQ_C_KS - 3);
						// freq_c_dir <= dphase_c_man[`WF_PHASE-1]; // dphase_c[`WF_PHASE-1]? -1: 1
						freq_c_step <= 1 << FREQ_C_KS;
					end
					2'b01: begin // operate
						if (freq_c_cnt < freq_c_cnt_th) begin
							freq_c_state <= 2'b01;
							freq_c_cnt <= freq_c_cnt + 4;
							// freq_c <= freq_c_dir? -freq_c_step: freq_c_step;
							freq_c <= freq_c_step;
						end else begin
							freq_c_state <= 2'b10;
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
			freq_c_cnt <= k;
			freq_c <= 0;
			// freq_c_dir <= 0;
			freq_c_step <= 0;
		end
	end
end

endmodule
// ------------------------------------------------------------
// Module Name: FREQCGEN
// Function:    1. calc fcw_cali word correspond to clk0-3
		// DSM_PHE 	-> phel_sync/ phem_sync/ pheq_sync: 6p
		//			-> phem_sync_reg_d2: 8p
// Authot: Yumeng Yang Date: 2024-3-17
// Version: v1p0
// ------------------------------------------------------------
module DTCLMSGEN (
CLK,
NRST,
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
kdtcB_cali,
kdtcC_cali,
kdtcD_cali,
phe_msb,
phe_lsb,
phe_quant,
lms_errB_ext_reg,
lms_errC_ext_reg,
lms_errD_ext_reg,
phem_sync_reg,
phem_sync_reg_d2,
dtc_temp
);

input CLK;
input NRST;
input GAC_EN; // calibration en
input OFSTC_EN; // claibrate dff ofst
input RT_EN;
input [`WF-1:0] DSM_PHE;
input [`WF-1:0] PHE_NORM;
input [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
input [1:0] CALIORDER;
input [4:0] KB; // -16 ~ 15
input [4:0] KC; // -16 ~ 15
input [4:0] KD; // -16 ~ 15
input [10+`WF:0] kdtcB_cali;
input [10+`WF:0] kdtcC_cali;
input [10+`WF:0] kdtcD_cali;

output reg [2:0] phe_msb;
output reg [`WF-1:0] phe_lsb;
output reg phe_quant;
output [10+`WF:0] lms_errB_ext_reg;
output [10+`WF:0] lms_errC_ext_reg;
output [10+`WF:0] lms_errD_ext_reg;
output [2:0] phem_sync_reg, phem_sync_reg_d2;
output [9:0] dtc_temp;


// internal signal
// split DTC delay range into 4 segments
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

always @* begin
	phe_msb = dsm_phe_remain_sl[`WF-1:`WF-3] >> PSEG;
	phe_lsb = (dsm_phe_remain_sl<<(3-PSEG))>>(3-PSEG);
	phe_quant = dsm_phe_qt;
end

wire [12+`WF-1:0] pro_kdtcB_phel;
wire [10+`WF:0] product1, product0, product2, product;
reg [10+`WF:0] kdtcC_cali_reg1, kdtcC_cali_reg2;
reg [10+`WF:0] kdtcD_cali_reg1, kdtcD_cali_reg2;
wire [9:0] dtc_temp;

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

// DTC NONLINEAR CALI
reg [`WF-1:0] phel_reg1, phel_reg2, phel_reg3, phel_reg4, phel_reg5, phel_sync;
reg pheq_reg1, pheq_reg2, pheq_reg3, pheq_reg4, pheq_reg5, pheq_sync;
reg [2:0] phem_reg1, phem_reg2, phem_reg3, phem_reg4, phem_reg5, phem_sync, phem_sync_reg, phem_sync_reg_d1, phem_sync_reg_d2;

// generate synchronouse phe and phe_sig
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		phel_reg1 <= 0; phel_reg2 <= 0; phel_reg3 <= 0; phel_reg4 <= 0; phel_reg5 <= 0; phel_sync <= 0; 
		phem_reg1 <= 0; phem_reg2 <= 0; phem_reg3 <= 0; phem_reg4 <= 0; phem_reg5 <= 0; phem_sync <= 0; 
		pheq_reg1 <= 0; pheq_reg2 <= 0; pheq_reg3 <= 0; pheq_reg4 <= 0; pheq_reg5 <= 0; pheq_sync <= 0;
	end else if (GAC_EN) begin
		phel_reg1 <= phe_lsb; phel_reg2 <= phel_reg1; phel_reg3 <= phel_reg2; phel_reg4 <= phel_reg3; phel_reg5 <= phel_reg4; phel_sync <= phel_reg5; 
		phem_reg1 <= phe_msb; phem_reg2 <= phem_reg1; phem_reg3 <= phem_reg2; phem_reg4 <= phem_reg3; phem_reg5 <= phem_reg4; phem_sync <= phem_reg5; 
		pheq_reg1 <= phe_quant; pheq_reg2 <= pheq_reg1; pheq_reg3 <= pheq_reg2; pheq_reg4 <= pheq_reg3; pheq_reg5 <= pheq_reg4; pheq_sync <= pheq_reg5;
	end
end

// LUT calibration
wire signed [10+`WF:0] lms_errB, lms_errB_ext;
wire signed [10+`WF:0] lms_errC, lms_errC_ext;
wire signed [10+`WF:0] lms_errD, lms_errD_ext;
reg [10+`WF:0] lms_errB_ext_reg;
reg [10+`WF:0] lms_errC_ext_reg;
reg [10+`WF:0] lms_errD_ext_reg;

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
SYNC_NRST,
NCO_SYNC_NRST_EN,
FCW_FOD,
FCW_PLL_MAIN_S,
FCW_PLL_AUX_S,
PHE_MEASURE_X4,
FREQ_C_EN,
FREQ_C_MODE,
FREQ_C_KS,
PHASE_CTRL,
PCALI_FREQDOWN,
PCALI_KS,
// output
PHE_NORM_X4,
FREQ_C_X4
);

// delay information
// PHE_MEASURE -> PHE_NORM delay 1 cycle

input NRST;
input CLK;
input EN;
input [`WI+`WF-1:0] FCW_FOD;
input [2:0] FCW_PLL_MAIN_S; // default to 32(2^5)
input [2:0] FCW_PLL_AUX_S; // defualt to 16(2^4)
input [4*`MP_SEG_BIN-1:0] PHE_MEASURE_X4; // 0~31
input FREQ_C_EN;
input FREQ_C_MODE; // 0:linear mode; 1: 1step mode
input [4:0] FREQ_C_KS; // step shift 0 ~ 15
input [9:0] PHASE_CTRL; // manual phase adjustment
input [2:0] PCALI_FREQDOWN; // down scale phase cali freq, div1 ~ div128
input [4:0] PCALI_KS; // kdtc cali set to 8/12; phase cali set to 12/16
input SYNC_NRST;
input NCO_SYNC_NRST_EN;

output [4*`WF-1:0] PHE_NORM_X4; // 0<=x<1
output [4*(`WI+`WF)-1:0] FREQ_C_X4;

// down scale phase cali freq
reg [7:0] p_fdn_win_th;
reg [7:0] p_fdn_win_cnt;
reg p_fdn_win;

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

reg [`WF_PHASE-1:0] dphase_c;
wire [4*`WF_PHASE-1:0] dphase_c_step_x4; // dphase for offset calibration
wire [`WF_PHASE-1:0] dphase_c_step; 

// combine all dphase cali in 4 clk domain
assign dphase_c_step = dphase_c_step_x4[1*`WF_PHASE-1-:`WF_PHASE] + dphase_c_step_x4[2*`WF_PHASE-1-:`WF_PHASE] + dphase_c_step_x4[3*`WF_PHASE-1-:`WF_PHASE] + dphase_c_step_x4[4*`WF_PHASE-1-:`WF_PHASE];

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		dphase_c <= 0;
	end else if (EN) begin 
		// dphase_c has a pattern with 1200ns period, maybe lead to a spur, but that can be suppressed with a digital random dither
		dphase_c <= dphase_c_step + dphase_c;
	end else begin
		dphase_c <= 0;
	end
end

// PHE_MEASURE -> PHE_NORM: 1p
// calc phe in each clk domain (clk0~3)
PHEGEN_NCO #(0) U2_CLK0_PHEGEN_NCO ( .NRST(NRST), .CLK(CLK), .EN(EN|FREQ_C_EN), .FCW_FOD(FCW_FOD), .FCW_PLL_MAIN_S(FCW_PLL_MAIN_S), .FCW_PLL_AUX_S(FCW_PLL_AUX_S), .PHE_MEASURE(PHE_MEASURE_X4[1*`MP_SEG_BIN-1-:`MP_SEG_BIN]), .PCALI_KS(PCALI_KS), .dphase_c(dphase_c), .dphase_c_step(dphase_c_step_x4[1*`WF_PHASE-1-:`WF_PHASE]), .PHE_NORM(PHE_NORM_X4[1*`WF-1-:`WF]), .SYNC_NRST(SYNC_NRST), .NCO_SYNC_NRST_EN(NCO_SYNC_NRST_EN) );
PHEGEN_NCO #(1) U2_CLK1_PHEGEN_NCO ( .NRST(NRST), .CLK(CLK), .EN(EN|FREQ_C_EN), .FCW_FOD(FCW_FOD), .FCW_PLL_MAIN_S(FCW_PLL_MAIN_S), .FCW_PLL_AUX_S(FCW_PLL_AUX_S), .PHE_MEASURE(PHE_MEASURE_X4[2*`MP_SEG_BIN-1-:`MP_SEG_BIN]), .PCALI_KS(PCALI_KS), .dphase_c(dphase_c), .dphase_c_step(dphase_c_step_x4[2*`WF_PHASE-1-:`WF_PHASE]), .PHE_NORM(PHE_NORM_X4[2*`WF-1-:`WF]), .SYNC_NRST(SYNC_NRST), .NCO_SYNC_NRST_EN(NCO_SYNC_NRST_EN) );
PHEGEN_NCO #(2) U2_CLK2_PHEGEN_NCO ( .NRST(NRST), .CLK(CLK), .EN(EN|FREQ_C_EN), .FCW_FOD(FCW_FOD), .FCW_PLL_MAIN_S(FCW_PLL_MAIN_S), .FCW_PLL_AUX_S(FCW_PLL_AUX_S), .PHE_MEASURE(PHE_MEASURE_X4[3*`MP_SEG_BIN-1-:`MP_SEG_BIN]), .PCALI_KS(PCALI_KS), .dphase_c(dphase_c), .dphase_c_step(dphase_c_step_x4[3*`WF_PHASE-1-:`WF_PHASE]), .PHE_NORM(PHE_NORM_X4[3*`WF-1-:`WF]), .SYNC_NRST(SYNC_NRST), .NCO_SYNC_NRST_EN(NCO_SYNC_NRST_EN) );
PHEGEN_NCO #(3) U2_CLK3_PHEGEN_NCO ( .NRST(NRST), .CLK(CLK), .EN(EN|FREQ_C_EN), .FCW_FOD(FCW_FOD), .FCW_PLL_MAIN_S(FCW_PLL_MAIN_S), .FCW_PLL_AUX_S(FCW_PLL_AUX_S), .PHE_MEASURE(PHE_MEASURE_X4[4*`MP_SEG_BIN-1-:`MP_SEG_BIN]), .PCALI_KS(PCALI_KS), .dphase_c(dphase_c), .dphase_c_step(dphase_c_step_x4[4*`WF_PHASE-1-:`WF_PHASE]), .PHE_NORM(PHE_NORM_X4[4*`WF-1-:`WF]), .SYNC_NRST(SYNC_NRST), .NCO_SYNC_NRST_EN(NCO_SYNC_NRST_EN) );

// calc fcw cali in each clk domain (clk0~3)
FREQCGEN #(0) U2_CLK0_FREQCGEN ( .NRST(NRST), .CLK(CLK), .FREQ_C_EN(FREQ_C_EN), .FREQ_C_MODE(FREQ_C_MODE), .FREQ_C_KS(FREQ_C_KS), .PHASE_CTRL(PHASE_CTRL), .dphase_c(dphase_c), .FREQ_C(FREQ_C_X4[1*(`WI+`WF)-1-:(`WI+`WF)]) );
FREQCGEN #(1) U2_CLK1_FREQCGEN ( .NRST(NRST), .CLK(CLK), .FREQ_C_EN(FREQ_C_EN), .FREQ_C_MODE(FREQ_C_MODE), .FREQ_C_KS(FREQ_C_KS), .PHASE_CTRL(PHASE_CTRL), .dphase_c(dphase_c), .FREQ_C(FREQ_C_X4[2*(`WI+`WF)-1-:(`WI+`WF)]) );
FREQCGEN #(2) U2_CLK2_FREQCGEN ( .NRST(NRST), .CLK(CLK), .FREQ_C_EN(FREQ_C_EN), .FREQ_C_MODE(FREQ_C_MODE), .FREQ_C_KS(FREQ_C_KS), .PHASE_CTRL(PHASE_CTRL), .dphase_c(dphase_c), .FREQ_C(FREQ_C_X4[3*(`WI+`WF)-1-:(`WI+`WF)]) );
FREQCGEN #(3) U2_CLK_FREQCGEN ( .NRST(NRST), .CLK(CLK), .FREQ_C_EN(FREQ_C_EN), .FREQ_C_MODE(FREQ_C_MODE), .FREQ_C_KS(FREQ_C_KS), .PHASE_CTRL(PHASE_CTRL), .dphase_c(dphase_c), .FREQ_C(FREQ_C_X4[4*(`WI+`WF)-1-:(`WI+`WF)]) );

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
DSM_PHE_X4,
PHE_NORM_X4,
PSEG,
CALIORDER,
KB,
KC,
KD,
KDTCB_INIT,
KDTCC_INIT,
KDTCD_INIT,
// output
DTCDCW_X4,
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
input [4*`WF-1:0] DSM_PHE_X4; // DSM output
input [4*`WF-1:0] PHE_NORM_X4; // normalized phe
input [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
input [1:0] CALIORDER;
input [4:0] KB; // -16 ~ 15
input [4:0] KC; // -16 ~ 15
input [4:0] KD; // -16 ~ 15
input [9:0] KDTCB_INIT;
input [9:0] KDTCC_INIT;
input [9:0] KDTCD_INIT;

output reg [4*10-1:0] DTCDCW_X4;

// internal signals
// split DTC delay range into 4 segments
reg [10+`WF:0] LUTB [7:0];
reg [10+`WF:0] LUTC [7:0];
reg [10+`WF:0] LUTD [1:0];
wire [10+`WF:0] kdtcB_cali_x4m [3:0];
wire [10+`WF:0] kdtcC_cali_x4m [3:0];
wire [10+`WF:0] kdtcD_cali_x4m [3:0];
wire [2:0] phe_msb_x4m [3:0];
wire [`WF-1:0] phe_lsb_x4m [3:0];
wire [3:0] phe_quant_x4m;
wire [9:0] dtc_temp_x4m [3:0];

assign kdtcB_cali_x4m[0] = LUTB[phe_msb_x4m[0]]; assign kdtcC_cali_x4m[0] = LUTC[phe_msb_x4m[0]]; assign kdtcD_cali_x4m[0] = LUTD[phe_quant_x4m[0]]; //clk0
assign kdtcB_cali_x4m[1] = LUTB[phe_msb_x4m[1]]; assign kdtcC_cali_x4m[1] = LUTC[phe_msb_x4m[1]]; assign kdtcD_cali_x4m[1] = LUTD[phe_quant_x4m[1]]; //clk1
assign kdtcB_cali_x4m[2] = LUTB[phe_msb_x4m[2]]; assign kdtcC_cali_x4m[2] = LUTC[phe_msb_x4m[2]]; assign kdtcD_cali_x4m[2] = LUTD[phe_quant_x4m[2]]; //clk2
assign kdtcB_cali_x4m[3] = LUTB[phe_msb_x4m[3]]; assign kdtcC_cali_x4m[3] = LUTC[phe_msb_x4m[3]]; assign kdtcD_cali_x4m[3] = LUTD[phe_quant_x4m[3]]; //clk3

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		DTCDCW_X4 <= 0;
	end else begin
		DTCDCW_X4 <= DTC_EN? {dtc_temp_x4m[3], dtc_temp_x4m[2], dtc_temp_x4m[1], dtc_temp_x4m[0]}: 0;
	end
end

// DTC NONLINEAR CALI
wire [2:0] phem_sync_x4m [3:0], phem_sync_x4m_reg [3:0], phem_sync_x4m_reg_d2 [3:0];

// LUT calibration
wire [10+`WF:0] lms_errB_ext_x4m_reg [3:0];
wire [10+`WF:0] lms_errC_ext_x4m_reg [3:0];
wire [10+`WF:0] lms_errD_ext_x4m_reg [3:0];

// INL cali
integer i;
reg [10+`WF:0] LUTB_add [7:0], LUTB_nxt [7:0];
reg [10+`WF:0] LUTC_add [7:0], LUTC_nxt [7:0];

always @* begin
	for (i=7; i>=0; i=i-1) begin
		LUTB_add[i] = 0;
		LUTC_add[i] = 0;
	end
	for (i=3; i>=0; i=i-1) begin // clk3~0
		LUTB_add[phem_sync_x4m_reg_d2[i]] = LUTB_add[phem_sync_x4m_reg_d2[i]] + lms_errB_ext_x4m_reg[i];
		LUTC_add[phem_sync_x4m_reg[i]] = LUTC_add[phem_sync_x4m_reg[i]] + ((|phem_sync_x4m_reg[i])? (lms_errC_ext_x4m_reg[i]): 0);
	end
	for (i=7; i>=0; i=i-1) begin
		LUTB_nxt[i] = LUTB[i] + LUTB_add[i];
		LUTC_nxt[i] = LUTC[i] + LUTC_add[i];
	end
end

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
		for (i=7; i>=0; i=i-1) begin
			LUTB[i] <= LUTB_nxt[i];
			LUTC[i] <= LUTC_nxt[i];
		end
	end
end

// DFF ofst cali
wire [10+`WF:0] lms_errD_ext_reg;

assign lms_errD_ext_reg = lms_errD_ext_x4m_reg[0] + lms_errD_ext_x4m_reg[1] + lms_errD_ext_x4m_reg[2] + lms_errD_ext_x4m_reg[3];
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

// PHE_MEASURE -> PHE_NORM: 1p
// DSM_PHE 	-> phel_sync/ phem_sync/ pheq_sync: 6p
//			-> phem_sync_reg_d2: 8p
DTCLMSGEN U2_CLK0_DTCLMSGEN ( .CLK(CLK), .NRST(NRST), .GAC_EN(GAC_EN), .OFSTC_EN(OFSTC_EN), .RT_EN(RT_EN), .DSM_PHE(DSM_PHE_X4[1*`WF-1-:`WF]), .PHE_NORM(PHE_NORM_X4[1*`WF-1-:`WF]), .PSEG(PSEG), .CALIORDER(CALIORDER), .KB(KB), .KC(KC), .KD(KD), .kdtcB_cali(kdtcB_cali_x4m[0]), .kdtcC_cali(kdtcC_cali_x4m[0]), .kdtcD_cali(kdtcD_cali_x4m[0]), .phe_msb(phe_msb_x4m[0]), .phe_lsb(phe_lsb_x4m[0]), .phe_quant(phe_quant_x4m[0]), .lms_errB_ext_reg(lms_errB_ext_x4m_reg[0]), .lms_errC_ext_reg(lms_errC_ext_x4m_reg[0]), .lms_errD_ext_reg(lms_errD_ext_x4m_reg[0]), .phem_sync_reg(phem_sync_x4m_reg[0]), .phem_sync_reg_d2(phem_sync_x4m_reg_d2[0]), .dtc_temp(dtc_temp_x4m[0]) );
DTCLMSGEN U2_CLK1_DTCLMSGEN ( .CLK(CLK), .NRST(NRST), .GAC_EN(GAC_EN), .OFSTC_EN(OFSTC_EN), .RT_EN(RT_EN), .DSM_PHE(DSM_PHE_X4[2*`WF-1-:`WF]), .PHE_NORM(PHE_NORM_X4[2*`WF-1-:`WF]), .PSEG(PSEG), .CALIORDER(CALIORDER), .KB(KB), .KC(KC), .KD(KD), .kdtcB_cali(kdtcB_cali_x4m[1]), .kdtcC_cali(kdtcC_cali_x4m[1]), .kdtcD_cali(kdtcD_cali_x4m[1]), .phe_msb(phe_msb_x4m[1]), .phe_lsb(phe_lsb_x4m[1]), .phe_quant(phe_quant_x4m[1]), .lms_errB_ext_reg(lms_errB_ext_x4m_reg[1]), .lms_errC_ext_reg(lms_errC_ext_x4m_reg[1]), .lms_errD_ext_reg(lms_errD_ext_x4m_reg[1]), .phem_sync_reg(phem_sync_x4m_reg[1]), .phem_sync_reg_d2(phem_sync_x4m_reg_d2[1]), .dtc_temp(dtc_temp_x4m[1]) );
DTCLMSGEN U2_CLK2_DTCLMSGEN ( .CLK(CLK), .NRST(NRST), .GAC_EN(GAC_EN), .OFSTC_EN(OFSTC_EN), .RT_EN(RT_EN), .DSM_PHE(DSM_PHE_X4[3*`WF-1-:`WF]), .PHE_NORM(PHE_NORM_X4[3*`WF-1-:`WF]), .PSEG(PSEG), .CALIORDER(CALIORDER), .KB(KB), .KC(KC), .KD(KD), .kdtcB_cali(kdtcB_cali_x4m[2]), .kdtcC_cali(kdtcC_cali_x4m[2]), .kdtcD_cali(kdtcD_cali_x4m[2]), .phe_msb(phe_msb_x4m[2]), .phe_lsb(phe_lsb_x4m[2]), .phe_quant(phe_quant_x4m[2]), .lms_errB_ext_reg(lms_errB_ext_x4m_reg[2]), .lms_errC_ext_reg(lms_errC_ext_x4m_reg[2]), .lms_errD_ext_reg(lms_errD_ext_x4m_reg[2]), .phem_sync_reg(phem_sync_x4m_reg[2]), .phem_sync_reg_d2(phem_sync_x4m_reg_d2[2]), .dtc_temp(dtc_temp_x4m[2]) );
DTCLMSGEN U2_CLK3_DTCLMSGEN ( .CLK(CLK), .NRST(NRST), .GAC_EN(GAC_EN), .OFSTC_EN(OFSTC_EN), .RT_EN(RT_EN), .DSM_PHE(DSM_PHE_X4[4*`WF-1-:`WF]), .PHE_NORM(PHE_NORM_X4[4*`WF-1-:`WF]), .PSEG(PSEG), .CALIORDER(CALIORDER), .KB(KB), .KC(KC), .KD(KD), .kdtcB_cali(kdtcB_cali_x4m[3]), .kdtcC_cali(kdtcC_cali_x4m[3]), .kdtcD_cali(kdtcD_cali_x4m[3]), .phe_msb(phe_msb_x4m[3]), .phe_lsb(phe_lsb_x4m[3]), .phe_quant(phe_quant_x4m[3]), .lms_errB_ext_reg(lms_errB_ext_x4m_reg[3]), .lms_errC_ext_reg(lms_errC_ext_x4m_reg[3]), .lms_errD_ext_reg(lms_errD_ext_x4m_reg[3]), .phem_sync_reg(phem_sync_x4m_reg[3]), .phem_sync_reg_d2(phem_sync_x4m_reg_d2[3]), .dtc_temp(dtc_temp_x4m[3]) );

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
SYS_REF,
SYS_EN,
DSM_EN,
FCW_FOD,
DSM_SYNC_NRST_EN,
NCO_SYNC_NRST_EN,
FREQ_HOP,
PHE_X4,
PCALI_EN,
FREQ_C_EN,
FREQ_C_MODE,
FREQ_C_KS,
PHASE_CTRL,
PCALI_FREQDOWN,
PCALI_KS, // 0~16
RT_EN,
DTCCALI_EN,
OFSTCALI_EN,
PSEG, // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
CALIORDER,
KB, // -16 ~ 15
KC, // -16 ~ 15
KD, // -16 ~
KDTCB_INIT,
KDTCC_INIT,
KDTCD_INIT,
FCW_DN_EN,
FCW_DN_WEIGHT,
// output
MMD_DCW_X4,
RT_DCW_X4,
DTC_DCW_X4
);
// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NARST;
input CLK;
input DSM_EN;
input [`WI+`WF-1:0] FCW_FOD;
input [4*`MP_SEG_BIN-1:0] PHE_X4;
// phase cali
input PCALI_EN;
input FREQ_C_EN;
input FREQ_C_MODE;
input [4:0] FREQ_C_KS;
input [9:0] PHASE_CTRL;
input [2:0] PCALI_FREQDOWN;
input [4:0] PCALI_KS; // 0~16

// INL cali
input RT_EN;
input DTCCALI_EN;
input OFSTCALI_EN;
input [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
input [1:0] CALIORDER;
input [4:0] KB; // -16 ~ 15
input [4:0] KC; // -16 ~ 15
input [4:0] KD; // -16 ~
input [9:0] KDTCB_INIT;
input [9:0] KDTCC_INIT;
input [9:0] KDTCD_INIT;
input FCW_DN_EN;
input [1:0] FCW_DN_WEIGHT; // dither weight, shift right, maximum set to 2(rand 0~256), greater than 2 will lead to gain cali error

// phase sync
input SYS_REF;
input SYS_EN;
input DSM_SYNC_NRST_EN;
input NCO_SYNC_NRST_EN;

// freq hop
input FREQ_HOP;

output reg [4*7-1:0] MMD_DCW_X4; // MMD div range 4~127
output reg [3:0] RT_DCW_X4; // 0: posedge retimer; 1: negedge retimer(delay for 0.5 FPLL8G cycle)
output [4*10-1:0] DTC_DCW_X4;


// code begin
wire NRST;
wire [`WI+`WF-1:0] FCW_FOD;
wire [4*`WI-1:0] FCW_FOD_I_X4;
wire [4*`WF-1:0] FCW_FOD_F_X4;
wire [3:0] DSM_CAR_X4;
wire [4*`WF-1:0] DSM_PHE_X4; // ufix, 0<x<1

wire [4*`WF-1:0] PHE_NORM_X4;
wire [4*(`WI+`WF)-1:0] FREQ_C_X4;

// synchronize NARST with CLK
SYNCRSTGEN U1_FOD_CTRL_SYNCRSTGEN ( .CLK(CLK), .NARST(NARST), .NRST(NRST) );

// phase sync nrst
wire SYNC_NRST;
SYSPSYNCRST U1_FOD_CTRL_SYSPSYNCRST ( .NRST(NRST), .CLK(CLK), .SYS_REF(SYS_REF), .SYS_EN(SYS_EN), .SYNC_NRST(SYNC_NRST) );


// prestore fcw in spi and use freq_hop signal to trigger it
reg [`WI+`WF-1:0] FCW_FOD_hop;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		FCW_FOD_hop <= FCW_FOD;
	end else begin
		if (FREQ_HOP) begin
			FCW_FOD_hop <= FCW_FOD;
		end
	end
end

wire [9:0] urn10b;
reg [`WI+`WF-1:0] fcw_dither, fcw_dither_d1, phase_dither;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		fcw_dither <= 0;
		fcw_dither_d1 <= 0;
		phase_dither <= 0;
	end else if (FCW_DN_EN) begin
		fcw_dither <= urn10b>>FCW_DN_WEIGHT;
		fcw_dither_d1 <= fcw_dither;
		phase_dither <= fcw_dither - fcw_dither_d1;
	end else begin
		phase_dither <= 0;
	end
end

FCW_LFSR10_RST1 U1_FOD_CTRL_FCW_DITHER ( .CLK(CLK), .NRST(NRST), .EN(FCW_DN_EN), .URN10B(urn10b) );

// FOD phase adjust according PCALI 
assign {FCW_FOD_I_X4[1*`WI-1-:`WI], FCW_FOD_F_X4[1*`WF-1-:`WF]} = FCW_FOD_hop + FREQ_C_X4[1*(`WI+`WF)-1-:(`WI+`WF)] + phase_dither; // clk0
assign {FCW_FOD_I_X4[2*`WI-1-:`WI], FCW_FOD_F_X4[2*`WF-1-:`WF]} = FCW_FOD_hop + FREQ_C_X4[2*(`WI+`WF)-1-:(`WI+`WF)] + phase_dither; // clk1
assign {FCW_FOD_I_X4[3*`WI-1-:`WI], FCW_FOD_F_X4[3*`WF-1-:`WF]} = FCW_FOD_hop + FREQ_C_X4[3*(`WI+`WF)-1-:(`WI+`WF)] + phase_dither; // clk2
assign {FCW_FOD_I_X4[4*`WI-1-:`WI], FCW_FOD_F_X4[4*`WF-1-:`WF]} = FCW_FOD_hop + FREQ_C_X4[4*(`WI+`WF)-1-:(`WI+`WF)] + phase_dither; // clk3

// 0.5 quantization
reg [3:0] phe_quant_x4;

always @* begin
	if (RT_EN) begin
		phe_quant_x4 = {DSM_PHE_X4[4*`WF-1], DSM_PHE_X4[3*`WF-1], DSM_PHE_X4[2*`WF-1], DSM_PHE_X4[1*`WF-1]};
	end else begin
		phe_quant_x4 = 0;
	end
end

// DCW output
// sync MMD, RT, DTC DCW
// DSM_CAR 	-> MMD_DCW_X4: 3p
// DSM_PHE	-> RT_DCW_X4: 3p
// 			-> DTC_DCW_X4: 3p
reg [4*7-1:0] mmd_dcw_x4_d1, mmd_dcw_x4_d2;
reg [3:0] rt_dcw_x4_d1, rt_dcw_x4_d2;
always @ (posedge CLK or negedge NRST) begin
	
	if (!NRST) begin
		mmd_dcw_x4_d1 <= {4{7'd4}};
		mmd_dcw_x4_d2 <= {4{7'd4}};
		MMD_DCW_X4 <= {4{7'd4}};

		rt_dcw_x4_d1 <= 0;
		rt_dcw_x4_d2 <= 0;
		RT_DCW_X4 <= 0;
	end else begin
		mmd_dcw_x4_d1[1*7-1-:7] <= FCW_FOD_I_X4[1*`WI-1-:`WI] + DSM_CAR_X4[0];
		mmd_dcw_x4_d1[2*7-1-:7] <= FCW_FOD_I_X4[2*`WI-1-:`WI] + DSM_CAR_X4[1];
		mmd_dcw_x4_d1[3*7-1-:7] <= FCW_FOD_I_X4[3*`WI-1-:`WI] + DSM_CAR_X4[2];
		mmd_dcw_x4_d1[4*7-1-:7] <= FCW_FOD_I_X4[4*`WI-1-:`WI] + DSM_CAR_X4[3];
		mmd_dcw_x4_d2 <= mmd_dcw_x4_d1;
		MMD_DCW_X4 <= mmd_dcw_x4_d1;

		rt_dcw_x4_d1 <= phe_quant_x4;
		rt_dcw_x4_d2 <= rt_dcw_x4_d1;
		RT_DCW_X4 <= rt_dcw_x4_d2;
	end
end

// translate fcw into mmd/dtc ctrl word
DSM_MASH1_X4 U1_FOD_CTRL_DSM_MASH1 ( .CLK (CLK), .NRST (NRST), .EN (DSM_EN), .IN_X4 (FCW_FOD_F_X4), .OUT_X4 (DSM_CAR_X4), .PHE_X4 (DSM_PHE_X4), .SYNC_NRST(SYNC_NRST), .DSM_SYNC_NRST_EN(DSM_SYNC_NRST_EN) );

// calibration
// phase sync
CALI_PHASESYNC U1_FOD_CTRL_CALI_PHASESYNC (
.NRST(NRST),
.CLK(CLK),
.EN(PCALI_EN),
.FCW_FOD(FCW_FOD_hop),
.FCW_PLL_MAIN_S(3'd5),
.FCW_PLL_AUX_S(3'd2),
.PHE_MEASURE_X4(PHE_X4),
.FREQ_C_EN(FREQ_C_EN),
.FREQ_C_MODE(FREQ_C_MODE),
.FREQ_C_KS(FREQ_C_KS),
.PHASE_CTRL(PHASE_CTRL),
.PCALI_FREQDOWN(PCALI_FREQDOWN),
.PCALI_KS(PCALI_KS),
.PHE_NORM_X4(PHE_NORM_X4),
.FREQ_C_X4(FREQ_C_X4),
.NCO_SYNC_NRST_EN(NCO_SYNC_NRST_EN),
.SYNC_NRST(SYNC_NRST)
);

// DSM_PHE -> DTC_DCW: 3p
CALI_DTCINL U1_FOD_CTRL_CALI_DTCINL (
.NRST(NRST),
.CLK(CLK),
.DTC_EN(1'b1),
.GAC_EN(DTCCALI_EN),
.OFSTC_EN(OFSTCALI_EN),
.RT_EN(RT_EN),
.DSM_PHE_X4(DSM_PHE_X4),
.PHE_NORM_X4(PHE_NORM_X4),
.PSEG(PSEG),
.CALIORDER(CALIORDER),
.KB(KB),
.KC(KC),
.KD(KD),
.KDTCB_INIT(KDTCB_INIT),
.KDTCC_INIT(KDTCC_INIT),
.KDTCD_INIT(KDTCD_INIT),
.DTCDCW_X4(DTC_DCW_X4)
);


// // test
// real fcw_real;
// real dsmphe_real;

// always @* begin
// 	fcw_real = FCW_FOD * (2.0**-`WF);
// 	dsmphe_real = DSM_PHE * (2.0**-`WF);
// end

endmodule