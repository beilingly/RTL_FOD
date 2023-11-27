`timescale 1s/1fs

`define WI 6
`define WF 16

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

reg FPLL8G;
reg [7:0] FMP;
wire FDIV;
wire FDIVRT;
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
AUXPLL U0_AUXPLL ( .fin (fin), .fcw_pll_aux(fcw_pll_aux), .FMP(FMP) );

// FOD analog module
mmd_5stage U0_mmd_5stage ( .CKV (FPLL8G), .DIVNUM (MMD_DCW), .CKVD (FDIV) );
retimer_pos_neg U0_retimer_pos_neg ( .D (FDIV), .CK (FPLL8G), .POLARITY (RT_DCW), .OUT (FDIVRT) );
dtc U0_dtc ( .CKIN (FDIVRT), .CKOUT (FDTC), .DCW (DTC_DCW) );

// Phase Detect Samplers Array
reg [7:0] PSAMP;
reg [2:0] PHE;

always @ (posedge FDTC) begin // freq 2G
    PSAMP <= FMP;
end

// calculate phase error in 2G analog domain
always @* begin
    casex(PSAMP)
        8'bxxxx_xx01: PHE = 3'd0;
        8'bxxxx_x01x: PHE = 3'd1;
        8'bxxxx_01xx: PHE = 3'd2;
        8'bxxx0_1xxx: PHE = 3'd3;
        8'bxx01_xxxx: PHE = 3'd4;
        8'bx01x_xxxx: PHE = 3'd5;
        8'b01xx_xxxx: PHE = 3'd6;
        8'b1xxx_xxx0: PHE = 3'd7;
    endcase
end

// FOD Digital Controller
reg NARST;
reg [`WI+`WF-1:0] FCW_FOD;

initial begin
    NARST = 0;
    FCW_FOD = 4.27 * (2**`WF);
    #1e-9;
    NARST = 1;
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
    f0 = 1/p0/(8e9/4.27);
    t0 = $realtime;

    $fstrobe(fp1, "%3.15e", $realtime);
end

endmodule