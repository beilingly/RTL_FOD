`timescale 1s/1fs

`define WI 7
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN

// -------------------------------------------------------
// Module Name: FOD_2lane_TB
// Function: the top testbench for 2lane fos
// Author: Yang Yumeng Date: 2024-3-20
// Version: v1p0
// -------------------------------------------------------
module FOD_2lane_TB;

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
wire [4*7-1:0] MMD_DCW_X4;
wire [3:0] RT_DCW_X4; // select whether use pos or neg as retimer clock 
wire [4*10-1:0] DTC_DCW_X4;
wire [7-1:0] MMD_DCW;
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

// multi-phases divider outputs 1G clock in 8 interleave phases
MPDIV8 U0_MPDIV8 ( .NARST(NARST), .CLK(FPLL8G), .FMP(FMP), .FMP_RND(FMP_RND) );

// FOD analog module
mmd_6stage U0_mmd_6stage ( .CKV (FPLL8G), .DIVNUM (MMD_DCW), .CKVD (FDIV) );
retimer_pos_neg U0_retimer_pos_neg ( .D (FDIV), .CK (FPLL8G), .POLARITY (RT_DCW), .OUT (FDIVRT) );
dtc U0_dtc ( .CKIN (FDIVRT), .CKOUT (FDTC), .DCW (DTC_DCW) );

// 500M interleaved clks
wire [3:0] DIG_CLK;
MPDIV4 U0_MPDIV4 ( .NARST(NARST), .CLK(FDTC), .FMP(DIG_CLK) );

// Phase Detect Samplers Array
// reg [`MP_SEG-1:0] PSAMP;
reg [4*`MP_SEG_BIN-1:0] PHE_X4;

// sample FMD_RND with time-interleaved clk(500M)
reg [`MP_SEG-1:0] psamp;

always @ (posedge FDTC) begin // freq 2G
    psamp <= FMP_RND;
    // psamp <= FMP;
end

DCWRT U0_DCWRT ( .* );


// Phase Detect Samplers
real t_res;
real t_pos_fdtc, t_pos_fpllaux4g_nxt, t_quant;
real phase_ana_norm, phase_ana_norm_d1, phase_dig_norm, phase_diff;
real phase_ana_norm_0, phase_ana_norm_1, phase_ana_norm_2, phase_ana_norm_3;
real phase_ana_norm_0_clk1, phase_ana_norm_1_clk2, phase_ana_norm_2_clk3, phase_ana_norm_3_clk0;
real phase_ana_norm_bus [3:0];

initial t_res = 10e-12;

always @ (posedge FMP[0]) begin
    t_pos_fpllaux4g_nxt = $realtime;
end

always @ (posedge DIG_CLK[0]) begin // freq 500M
    t_pos_fdtc = $realtime;
    phase_ana_norm_d1 = phase_ana_norm;
    t_quant = t_pos_fdtc - t_pos_fpllaux4g_nxt;
    // t_quant = $floor(t_quant/10e-12) * 10e-12;
    phase_ana_norm = t_quant*fpllaux;
end

always @ (posedge DIG_CLK[0]) begin // freq 500M
    t_pos_fdtc = $realtime;
    t_quant = t_pos_fdtc - t_pos_fpllaux4g_nxt;
    // t_quant = $floor(t_quant/t_res) * t_res;
    phase_ana_norm_0 = t_quant*fpllaux;
end

always @ (posedge DIG_CLK[1]) begin // freq 500M
    t_pos_fdtc = $realtime;
    t_quant = t_pos_fdtc - t_pos_fpllaux4g_nxt;
    // t_quant = $floor(t_quant/t_res) * t_res;
    phase_ana_norm_1 = t_quant*fpllaux;
end

always @ (posedge DIG_CLK[2]) begin // freq 500M
    t_pos_fdtc = $realtime;
    t_quant = t_pos_fdtc - t_pos_fpllaux4g_nxt;
    // t_quant = $floor(t_quant/t_res) * t_res;
    phase_ana_norm_2 = t_quant*fpllaux;
end

always @ (posedge DIG_CLK[3]) begin // freq 500M
    t_pos_fdtc = $realtime;
    t_quant = t_pos_fdtc - t_pos_fpllaux4g_nxt;
    // t_quant = $floor(t_quant/t_res) * t_res;
    phase_ana_norm_3 = t_quant*fpllaux;
end

always @ (posedge DIG_CLK[1]) begin
    phase_ana_norm_0_clk1 <= phase_ana_norm_0;
end

always @ (posedge DIG_CLK[2]) begin
    phase_ana_norm_1_clk2 <= phase_ana_norm_1;
end

always @ (posedge DIG_CLK[3]) begin
    phase_ana_norm_2_clk3 <= phase_ana_norm_2;
end

always @ (posedge DIG_CLK[0]) begin
    phase_ana_norm_3_clk0 <= phase_ana_norm_3;
end

always @ (posedge DIG_CLK[1]) begin
    phase_ana_norm_bus[0] <= phase_ana_norm_0_clk1;
    phase_ana_norm_bus[1] <= phase_ana_norm_1_clk2;
    phase_ana_norm_bus[2] <= phase_ana_norm_2_clk3;
    phase_ana_norm_bus[3] <= phase_ana_norm_3_clk0;
end


always @* begin
    phase_dig_norm = $unsigned(U0_FOD_CTRL.U1_FOD_CTRL_CALI_PHASESYNC.U2_CLK0_PHEGEN_NCO.nco_phase_s) * (2.0**-`WF_PHASE);
    // phase_diff =  - phase_ana_norm + phase_dig_norm - 0.5;
    phase_diff =  - phase_ana_norm_d1 + phase_dig_norm - 0.5;
    phase_diff = ((phase_diff) - $floor(phase_diff))*360;
end

// FOD Digital Controller
wire [`WI+`WF-1:0] FCW_FOD;

// FOD SPI CTRL signal
// phase cali
wire PCALI_EN;
wire FREQ_C_EN;
wire FREQ_C_MODE;
wire [4:0] FREQ_C_KS;
wire [9:0] PHASE_CTRL;
wire [2:0] PCALI_FREQDOWN;
wire [4:0] PCALI_KS; // 0~16

// INL cali
wire RT_EN;
wire DTCCALI_EN;
wire OFSTCALI_EN;
wire [1:0] PSEG; // 3: 1-segs; 2: 2-segs; 1: 4-segs; 0: 8-segs
wire [1:0] CALIORDER;
wire [4:0] KB; // -16 ~ 15
wire [4:0] KC; // -16 ~ 15
wire [4:0] KD; // -16 ~
wire [9:0] KDTCB_INIT;
wire [9:0] KDTCC_INIT;
wire [9:0] KDTCD_INIT;
wire FCW_DN_EN;
wire [1:0] FCW_DN_WEIGHT;

// phase sync & freq hop
reg SYS_REF;
wire SYS_EN;
wire DSM_SYNC_NRST_EN;
wire NCO_SYNC_NRST_EN;
wire FREQ_HOP;

initial begin
    SYS_REF = 0;

    forever #(1/fin*128) begin
        SYS_REF = ~SYS_REF;
    end
end

FOD_CTRL U0_FOD_CTRL ( .NARST (NARST), .CLK (DIG_CLK[0]), .DSM_EN (1'b1), .FCW_FOD(FCW_FOD), .MMD_DCW_X4 (MMD_DCW_X4), .RT_DCW_X4 (RT_DCW_X4), .DTC_DCW_X4 (DTC_DCW_X4), .PHE_X4(PHE_X4), .* );

FOD_SPI U0_FOD_SPI ( .* );

// test
real p0, t0, f0;
integer fp1;

initial begin
    fp1 = $fopen("output_x_fod.txt");
end

always @ (posedge FDTC) begin
    p0 = $realtime - t0;
    f0 = 1/p0/(fpllmain/U0_FOD_SPI.rfcw);
    t0 = $realtime;

    $fstrobe(fp1, "%3.15e", $realtime);
end


endmodule