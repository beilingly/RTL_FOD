`timescale 1s/1fs

`define WI 6
`define WF 16

module fod2_tb;

parameter real fin = 250e6;
parameter real fcw_pll_main = 32;
parameter real fcw_pll_aux = 16;

reg FPLL8G;
reg FPLLAUX4G;
wire FDIV;
wire FDTC;
wire [5:0] MMD_DCW;
wire RT_DCW; // select whether use pos or neg as retimer clock 
wire [9:0] DTC_DCW;

// high performance PLL outputs 8G clock
real freq_pll_main;

initial begin
    FPLL8G = 0;
    freq_pll_main = fin * fcw_pll_main;
    forever begin
        #(1/freq_pll_main/2);
        FPLL8G = ~FPLL8G;
    end
end

// auxiliary PLL outputs 4G clock in 8 interleave phases
initial FPLLAUX4G = 0;
always @(posedge FPLL8G) begin
    FPLLAUX4G <= ~FPLLAUX4G;
end

// FOD analog module
mmd_5stage U0_mmd_5stage ( .CKV (FPLL8G), .DIVNUM (MMD_DCW), .CKVD (FDIV) );
dtc U0_dtc ( .CKIN (FDIV), .CKOUT (FDTC), .DCW (DTC_DCW) );

// Phase Detect Samplers
real t_pos_fdtc, t_pos_fpllaux4g_nxt;
real phase_ana_norm;

always @ (posedge FPLLAUX4G) begin
    t_pos_fpllaux4g_nxt = $realtime;
end

always @ (posedge FDTC) begin // freq 2G
    t_pos_fdtc = $realtime;
    phase_ana_norm = (t_pos_fdtc - t_pos_fpllaux4g_nxt)*4e9;
end

//***************************************************************************************
// FOD Digital Controller
reg NARST;
reg [`WI+`WF-1:0] FCW_FOD;
real fcw_fod;

FOD_CTRL U0_FOD_CTRL ( .NARST (NARST), .CLK (FDTC), .DSM_EN (1'b1), .FCW_FOD(FCW_FOD), .MMD_DCW (MMD_DCW), .DTC_DCW (DTC_DCW), .* );

//***************************************************************************************

initial begin
    NARST = 0;
    fcw_fod = 4.23;
    FCW_FOD = fcw_fod * (2**`WF);
    #1e-9;
    NARST = 1;
end

// test
real p0, t0, f0;
integer fp1;

initial begin
    fp1 = $fopen("output_x_fod.txt");
end

always @ (posedge FDTC) begin
    p0 = $realtime - t0;
    f0 = 1/p0/(8e9/fcw_fod);
    t0 = $realtime;

    $fstrobe(fp1, "%3.15e", $realtime);
end

endmodule