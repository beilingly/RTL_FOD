`timescale 1s/1fs

`define WI 6
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN

// -------------------------------------------------------
// Module Name: FOD_SPI
// Function: give spi contrl signal to fod
// Author: Yang Yumeng Date: 2024-3-20
// Version: v1p0
// -------------------------------------------------------
module FOD_SPI (
NARST,
FCW_FOD,
PCALI_EN,
FREQ_C_EN,
FREQ_C_MODE,
FREQ_C_KS,
PHASE_CTRL,
PCALI_FREQDOWN,
PCALI_KS,
RT_EN,
DTCCALI_EN,
OFSTCALI_EN,
PSEG,
CALIORDER,
KB,
KC,
KD,
KDTCB_INIT,
KDTCC_INIT,
KDTCD_INIT,
SYS_EN,
DSM_SYNC_NRST_EN,
NCO_SYNC_NRST_EN,
FREQ_HOP
);

output NARST;
output [`WI+`WF-1:0] FCW_FOD;
output PCALI_EN;
output FREQ_C_EN;
output FREQ_C_MODE;
output [4:0] FREQ_C_KS;
output [9:0] PHASE_CTRL;
output [2:0] PCALI_FREQDOWN;
output [4:0] PCALI_KS;
output RT_EN;
output DTCCALI_EN;
output OFSTCALI_EN;
output [1:0] PSEG;
output [1:0] CALIORDER;
output [4:0] KB;
output [4:0] KC;
output [4:0] KD;
output [9:0] KDTCB_INIT;
output [9:0] KDTCC_INIT;
output [9:0] KDTCD_INIT;
output SYS_EN;
output DSM_SYNC_NRST_EN;
output NCO_SYNC_NRST_EN;
output FREQ_HOP;

// FOD Digital Controller
reg NARST;
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

	KB = -5'd0;
	KC = -5'd3;
	KD = -5'd5;

	KDTCB_INIT = 10'd390 * 1;
	KDTCC_INIT = 10'd195;
	KDTCD_INIT = 10'd0;

	DTCCALI_EN = 0;
	OFSTCALI_EN = 0;
	#20e-6;
	DTCCALI_EN = 1;
	OFSTCALI_EN = 0;
end

reg SYS_EN;
reg DSM_SYNC_NRST_EN;
reg NCO_SYNC_NRST_EN;
reg FREQ_HOP;

initial begin
    DSM_SYNC_NRST_EN = 1;
    NCO_SYNC_NRST_EN = 1;
    FREQ_HOP = 0;
end

initial begin
    SYS_EN = 0;
    # 20e-6;
    SYS_EN = 0;
end


endmodule