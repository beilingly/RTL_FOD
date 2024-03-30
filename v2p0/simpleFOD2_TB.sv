`timescale 1s/1fs

`define WI 6
`define WF 16
`define WF_PHASE 24

// -------------------------------------------------------
// Module Name: simpleFOD2_TB
// Function: A simple simulation for parallel FODs
// Author: Yang Yumeng Date: 11/13 2023
// Version: v1p0
// -------------------------------------------------------
module simpleFOD2_TB;
parameter real fin = 250e6;
parameter real fcw_pll_main = 32;
parameter real fcw_pll_aux = 16;

reg NARST;
reg REF250M;
reg FPLL8G;
wire FDIV;
wire FDIVRT;
wire FDTC, FDTC_SYNC;
wire [5:0] MMD_DCW;
wire RT_DCW; // select whether use pos or neg as retimer clock 
wire [9:0] DTC_DCW;

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

// pll8g div2
reg FAUX4G;

initial FAUX4G = 0;
always @ (posedge FPLL8G) begin
	FAUX4G <= #(10e-12) ~FAUX4G;
end

// FOD analog module
mmd_5stage U0_mmd_5stage ( .CKV (FPLL8G), .DIVNUM (MMD_DCW), .CKVD (FDIV) );
retimer_pos_neg U0_retimer_pos_neg ( .D (FDIV), .CK (FPLL8G), .POLARITY (RT_DCW), .OUT (FDIVRT) );

// wire [9:0] dtc_dcw;
// assign dtc_dcw = U0_FOD_CTRL.U1_FOD_CTRL_CALI_DTCINL.dtc_dcw_reg3;

dtc U0_dtc ( .CKIN (FDIVRT), .CKOUT (FDTC), .DCW (DTC_DCW) );
DCDL U0_DCDL ( .CKIN(FDTC), .CKOUT(FDTC_SYNC), .DCW(U0_FOD_CTRL.U1_FOD_CTRL_CALI_PHASESYNC.phase_c) );

// Phase Detect Samplers Array
reg PHE;
wire FDTCRND;
// reg [3:0] PHE;

// dtcrand U0_dtcrand ( .CKIN(FDTC), .CKOUT(FDTCRND) );
always @ (posedge FDTC_SYNC) begin // freq 2G
    PHE <= FAUX4G;
end

// Phase Detect Samplers
real t_pos_fdtc, t_pos_fpllaux4g_nxt;
real phase_ana_norm, phase_ana_norm_d1, phase_dig_norm, phase_diff;
real t_diff, t_diff_res, t_diff_quant;
integer phe_msb, phe_lsb;

always @ (negedge FAUX4G) begin
    t_pos_fpllaux4g_nxt = $realtime;
end

always @ (posedge FDTC_SYNC) begin // freq 2G
    t_pos_fdtc = $realtime;
    // phase_ana_norm_d1 = phase_ana_norm;
    phase_ana_norm = (t_pos_fdtc - t_pos_fpllaux4g_nxt)*fpllaux;
end

always @ (posedge FDTC) begin // freq 2G
    phase_ana_norm_d1 = phase_ana_norm;
end

always @* begin
    phase_dig_norm = $unsigned(U0_FOD_CTRL.U1_FOD_CTRL_CALI_PHASESYNC.nco_phase_s) * (2.0**-`WF_PHASE);
    phase_diff =  - phase_ana_norm_d1 + phase_dig_norm - 0.5;
    phase_diff = ((phase_diff) - $floor(phase_diff))*360;
end

// FOD Digital Controller
reg [`WI+`WF-1:0] FCW_FOD;
real rfcw;

initial begin
    NARST = 0;
    rfcw = 4;
    FCW_FOD = rfcw * (2**`WF);
    #1e-9;
    NARST = 1;
	#20e-6;
    rfcw = 4.23;
    FCW_FOD = rfcw * (2**`WF);
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
	RT_EN = 1;
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

	KB = -5'd3;
	KC = -5'd3;
	KD = -5'd5;

	KDTCB_INIT = 10'd390 * 1;
	KDTCC_INIT = 10'd195;
	KDTCD_INIT = 10'd0;

	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
	#20e-6;
	PCALI_EN = 1;
	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
end

FOD_CTRL U0_FOD_CTRL ( .NARST (NARST), .CLK (FDTC), .DSM_EN (1'b1), .FCW_FOD(FCW_FOD), .MMD_DCW (MMD_DCW), .RT_DCW (RT_DCW), .DTC_DCW (DTC_DCW), .* );

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