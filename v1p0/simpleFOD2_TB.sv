`timescale 1s/1fs

`define WI 6
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN

// -------------------------------------------------------
// Module Name: simpleFOD2_TB
// Function: A simple simulation for parallel FODs
// Author: Yang Yumeng Date: 11/13 2023
// Version: v1p0
// -------------------------------------------------------
module simpleFOD2_TB;
parameter real fin = 250e6;
parameter real fcw_pll_main = 32;
parameter real fcw_pll_aux = 4;

reg NARST;
reg REF250M;
reg FPLL8G;
reg [`MP_SEG-1:0] FMP;
reg [`MP_SEG-1:0] FMP_RND;
wire FDIV;
wire FDIVRT;
wire FDTC;
wire [4*6-1:0] MMD_DCW_X4;
wire [3:0] RT_DCW_X4; // select whether use pos or neg as retimer clock 
wire [4*10-1:0] DTC_DCW_X4;
wire [6-1:0] MMD_DCW;
wire  RT_DCW; // select whether use pos or neg as retimer clock 
wire [10-1:0] DTC_DCW;

// REF 250M
initial begin
    REF250M = 0;
    forever begin
        #(1/fin/2);
        REF250M = ~REF250M;
    end
end

// pll aux
real fpllaux, fpllmain;
assign fpllaux = fin * fcw_pll_aux;
assign fpllmain = fin * fcw_pll_main;

// high performance PLL outputs 8G clock
real freq_pll_main;

initial begin
    FPLL8G = 0;
    freq_pll_main = fin * fcw_pll_main;
    forever begin
        #(1/freq_pll_main/2 * 1);
        FPLL8G = ~FPLL8G;
        #(1/freq_pll_main/2 * 1);
        FPLL8G = ~FPLL8G;
    end
end

// auxiliary PLL outputs 4G clock in 8 interleave phases
wire AUXPLL_PD;
wire [6:0] DCTRL_F;

// AUXPLL U0_AUXPLL ( .fin(fin), .fcw_pll_aux(fcw_pll_aux), .FMP(FMP) );
// DLL_PN U0_DLL ( .DCTRL_C(6'd32), .DCTRL_F(DCTRL_F), .MPH(FMP) );
MPDIV8 U0_MPDIV8 ( .NARST(NARST), .CLK(FPLL8G), .FMP(FMP), .FMP_RND(FMP_RND) );

// // aux pll phase detect
// auxpll_pd U0_auxpll_pd ( .REF250M(REF250M), .CK4G(FMP[0]), .PD(AUXPLL_PD) );
// TP2DLFIIRX2 U0_TP2DLFIIRX2 ( .NRST(NARST), .CKVD(REF250M), .PDE(AUXPLL_PD), .DLFEN(1'b1), .KPS(-6'sd2), .KIS(-6'sd10), .KIIR1S(-6'sd2), .KIIR2S(-6'sd2), .IIR1EN(1'b0), .IIR2EN(1'b0), .DSM1STEN(1'b1), .DCTRL(DCTRL_F) );

// FOD analog module
mmd_5stage U0_mmd_5stage ( .CKV (FPLL8G), .DIVNUM (MMD_DCW), .CKVD (FDIV) );
retimer_pos_neg U0_retimer_pos_neg ( .D (FDIV), .CK (FPLL8G), .POLARITY (RT_DCW), .OUT (FDIVRT) );

// wire [9:0] dtc_dcw;
// assign dtc_dcw = U0_FOD_CTRL.U1_FOD_CTRL_CALI_DTCINL.dtc_dcw_reg3;

dtc U0_dtc ( .CKIN (FDIVRT), .CKOUT (FDTC), .DCW (DTC_DCW) );

// 500M interleaved clks
wire [3:0] DIG_CLK;
MPDIV4 U0_MPDIV4 ( .NARST(NARST), .CLK(FDTC), .FMP(DIG_CLK) );
// dig-ana interface


// Phase Detect Samplers Array
// reg [`MP_SEG-1:0] PSAMP;
reg [4*`MP_SEG_BIN-1:0] PHE_X4;
// wire FDTCRND;
// reg [3:0] PHE;

// // dtcrand U0_dtcrand ( .CKIN(FDTC), .CKOUT(FDTCRND) );
// always @ (posedge FDTC) begin // freq 2G
//     PSAMP <= FMP_RND;
// end

// sample FMD_RND with time-interleaved clk(500M)
reg [`MP_SEG-1:0] psamp;

always @ (posedge FDTC) begin // freq 2G
    psamp <= FMP_RND;
end

DCWRT U0_DCWRT ( .* );


// Phase Detect Samplers
real t_pos_fdtc, t_pos_fpllaux4g_nxt;
real phase_ana_norm, phase_ana_norm_d1, phase_dig_norm, phase_diff;

always @ (posedge FMP[0]) begin
    t_pos_fpllaux4g_nxt = $realtime;
end

always @ (posedge DIG_CLK[0]) begin // freq 500M
    t_pos_fdtc = $realtime;
    phase_ana_norm_d1 = phase_ana_norm;
    phase_ana_norm = (t_pos_fdtc - t_pos_fpllaux4g_nxt)*fpllaux;
end

always @* begin
    phase_dig_norm = $unsigned(U0_FOD_CTRL.U1_FOD_CTRL_CALI_PHASESYNC.U2_CLK0_PHEGEN_NCO.nco_phase_s) * (2.0**-`WF_PHASE);
    // phase_diff =  - phase_ana_norm + phase_dig_norm - 0.5;
    phase_diff =  - phase_ana_norm_d1 + phase_dig_norm - 0.5;
    phase_diff = ((phase_diff) - $floor(phase_diff))*360;
end

// FOD Digital Controller
reg [`WI+`WF-1:0] FCW_FOD;
real rfcw;

initial begin
    NARST = 0;
    rfcw = 4.72;
    FCW_FOD = rfcw * (2**`WF);
    #1e-9;
    NARST = 1;
end

// FOD SPI CTRL signal
// phase cali
reg PCALI_EN;
reg FREQ_C_EN;
reg FREQ_C_MODE;
reg [4:0] FREQ_C_KS;
reg [9:0] PHASE_CTRL;
reg [2:0] PCALI_FREQDOWN;
reg [4:0] PCALI_KS; // 0~16

// INL cali
reg RT_EN;
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
	RT_EN = 0;
	PCALI_EN = 1;
	FREQ_C_EN = 0;
	FREQ_C_MODE = 0;
	FREQ_C_KS = 0;
	PHASE_CTRL = 0;
	PCALI_FREQDOWN = 0;
	PCALI_KS = 8;
end

initial begin
	PSEG = 3;

	CALIORDER = 2'b11;

	KB = -5'd2;
	KC = -5'd3;
	KD = -5'd5;

	KDTCB_INIT = 10'd390 * 2;
	KDTCC_INIT = 10'd195;
	KDTCD_INIT = 10'd0;

	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
	#100e-6;
	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
end

FOD_CTRL U0_FOD_CTRL ( .NARST (NARST), .CLK (DIG_CLK[0]), .DSM_EN (1'b1), .FCW_FOD(FCW_FOD), .MMD_DCW_X4 (MMD_DCW_X4), .RT_DCW_X4 (RT_DCW_X4), .DTC_DCW_X4 (DTC_DCW_X4), .PHE_X4(PHE_X4), .* );

// test
real p0, t0, f0;
integer fp1;

initial begin
    fp1 = $fopen("output_x_fod.txt");
end

always @ (posedge FDTC) begin
    p0 = $realtime - t0;
    f0 = 1/p0/(fpllmain/rfcw);
    t0 = $realtime;

    $fstrobe(fp1, "%3.15e", $realtime);
end

endmodule