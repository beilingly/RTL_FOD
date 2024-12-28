`timescale 1s/1fs

`define WI 7
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**3

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
DTC_EN,
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
KDTCD_INIT0,
KDTCD_INIT1,
FCW_DN_EN,
FCW_DN_WEIGHT,
// output
MMD_DCW_X4,
RT_DCW_X4,
DTC_DCW_X4,
DPH_C_CUT,
SECSEL_TEST,
REGSEL_TEST,
LUT_INT
);
// delay information
// DSM output -> DCW delay 1 cycle
// PHE_MEASURE -> PHE_NORM delay 1 cycle

// io
input NARST;
input CLK;
input DSM_EN;
input [7+16-1:0] FCW_FOD;
input [4*3-1:0] PHE_X4;
// phase cali
input PCALI_EN;
input FREQ_C_EN;
input FREQ_C_MODE;
input [4:0] FREQ_C_KS;
input [9:0] PHASE_CTRL;
input [2:0] PCALI_FREQDOWN;
input [4:0] PCALI_KS; // 0~16

// INL cali
input DTC_EN;
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
input [9:0] KDTCD_INIT0;
input [9:0] KDTCD_INIT1;
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

// to spi
output [9:0] DPH_C_CUT;

input [1:0] SECSEL_TEST; // 0 -- kdtcB/ 2 -- kdtcC/ 3 -- kdtcD
input [2:0] REGSEL_TEST; // reg0~7
output [10:0] LUT_INT;


// code begin
wire NRST;
wire [7+16-1:0] FCW_FOD;
wire [4*7-1:0] FCW_FOD_I_X4;
wire [4*16-1:0] FCW_FOD_F_X4;
wire [3:0] DSM_CAR_X4;
wire [4*16-1:0] DSM_PHE_X4; // ufix, 0<x<1

wire [4*16-1:0] PHE_NORM_X4;
wire [4*(7+16)-1:0] FREQ_C_X4;

// synchronize NARST with CLK
SYNCRSTGEN U1_FOD_CTRL_SYNCRSTGEN ( .CLK(CLK), .NARST(NARST), .NRST(NRST) );

// phase sync nrst
wire SYNC_NRST;
SYSPSYNCRST U1_FOD_CTRL_SYSPSYNCRST ( .NRST(NRST), .CLK(CLK), .SYS_REF(SYS_REF), .SYS_EN(SYS_EN), .SYNC_NRST(SYNC_NRST) );


// prestore fcw in spi and use freq_hop signal to trigger it
reg [7+16-1:0] FCW_FOD_hop;

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
reg [7+16-1:0] fcw_dither, fcw_dither_d1, phase_dither;

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
assign {FCW_FOD_I_X4[1*7-1-:7], FCW_FOD_F_X4[1*16-1-:16]} = FCW_FOD_hop + FREQ_C_X4[1*(7+16)-1-:(7+16)] + phase_dither; // clk0
assign {FCW_FOD_I_X4[2*7-1-:7], FCW_FOD_F_X4[2*16-1-:16]} = FCW_FOD_hop + FREQ_C_X4[2*(7+16)-1-:(7+16)] + phase_dither; // clk1
assign {FCW_FOD_I_X4[3*7-1-:7], FCW_FOD_F_X4[3*16-1-:16]} = FCW_FOD_hop + FREQ_C_X4[3*(7+16)-1-:(7+16)] + phase_dither; // clk2
assign {FCW_FOD_I_X4[4*7-1-:7], FCW_FOD_F_X4[4*16-1-:16]} = FCW_FOD_hop + FREQ_C_X4[4*(7+16)-1-:(7+16)] + phase_dither; // clk3

// 0.5 quantization
reg [3:0] phe_quant_x4;

always @* begin
	if (RT_EN) begin
		phe_quant_x4 = {DSM_PHE_X4[4*16-1], DSM_PHE_X4[3*16-1], DSM_PHE_X4[2*16-1], DSM_PHE_X4[1*16-1]};
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
		mmd_dcw_x4_d1[1*7-1-:7] <= FCW_FOD_I_X4[1*7-1-:7] + DSM_CAR_X4[0];
		mmd_dcw_x4_d1[2*7-1-:7] <= FCW_FOD_I_X4[2*7-1-:7] + DSM_CAR_X4[1];
		mmd_dcw_x4_d1[3*7-1-:7] <= FCW_FOD_I_X4[3*7-1-:7] + DSM_CAR_X4[2];
		mmd_dcw_x4_d1[4*7-1-:7] <= FCW_FOD_I_X4[4*7-1-:7] + DSM_CAR_X4[3];
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
.SYNC_NRST(SYNC_NRST),
.DPH_C_CUT(DPH_C_CUT)
);

// DSM_PHE -> DTC_DCW: 3p
CALI_DTCINL U1_FOD_CTRL_CALI_DTCINL (
.NRST(NRST),
.CLK(CLK),
.DTC_EN(DTC_EN),
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
.KDTCD_INIT0(KDTCD_INIT0),
.KDTCD_INIT1(KDTCD_INIT1),
.SECSEL_TEST(SECSEL_TEST),
.REGSEL_TEST(REGSEL_TEST),
.DTCDCW_X4(DTC_DCW_X4),
.LUT_INT(LUT_INT)
);

// // test
// real fcw_real;
// real dsmphe_real;

// always @* begin
// 	fcw_real = FCW_FOD * (2.0**-16);
// 	dsmphe_real = DSM_PHE * (2.0**-16);
// end

endmodule