`timescale 1s/1fs

`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN
// ------------------------------------------------------------
// Module Name: DCWRT
// Function:    1. retime dcw from 500M DIG_CLK domain to 2G FOD_CLK domain
// Authot: Yumeng Yang Date: 2024-3-18
// Version: v1p0
// ------------------------------------------------------------
module DCWRT(
NARST,
DIG_CLK,
FDTC,
MMD_DCW_X4,
DTC_DCW_X4,
RT_DCW_X4,
MMD_DCW,
DTC_DCW,
RT_DCW,
psamp,
PHE_X4
);

input NARST;
input [3:0] DIG_CLK;
input FDTC;
input [4*7-1:0] MMD_DCW_X4;
input [4*10-1:0] DTC_DCW_X4;
input [3:0] RT_DCW_X4;
output reg [7-1:0] MMD_DCW;
output reg [10-1:0] DTC_DCW;
output reg RT_DCW; // select whether use pos or neg as retimer clock 

input [`MP_SEG-1:0] psamp;
output reg [4*`MP_SEG_BIN-1:0] PHE_X4;


// DTC DCW retimer
// dcw2-3 @ clk2 pos
reg [10-1:0] DTC_DCW_0_clk0pos;
reg [10-1:0] DTC_DCW_1_clk0pos;
reg [10-1:0] DTC_DCW_2_clk2pos;
reg [10-1:0] DTC_DCW_3_clk2pos;
reg [10-1:0] dcw_comb, dcw_comb_d1;

initial begin
    DTC_DCW_0_clk0pos = 0;
    DTC_DCW_1_clk0pos = 0;
    DTC_DCW_2_clk2pos = 0;
    DTC_DCW_3_clk2pos = 0;
end

always @* begin
    DTC_DCW_0_clk0pos = DTC_DCW_X4[1*10-1-:10];
    DTC_DCW_1_clk0pos = DTC_DCW_X4[2*10-1-:10];
end

always @ (posedge DIG_CLK[2]) begin
    DTC_DCW_2_clk2pos <= DTC_DCW_X4[3*10-1-:10];
    DTC_DCW_3_clk2pos <= DTC_DCW_X4[4*10-1-:10];
end

always @* begin
    // case (DIG_CLK)
    //     4'b0110: dcw_comb = DTC_DCW_0_clk0pos;
    //     4'b1100: dcw_comb = DTC_DCW_1_clk0pos;
    //     4'b1001: dcw_comb = DTC_DCW_2_clk2pos;
    //     4'b0011: dcw_comb = DTC_DCW_3_clk2pos;
    //     default: dcw_comb = DTC_DCW_0_clk0pos;
    // endcase
    case (DIG_CLK)
        4'b0011: dcw_comb = DTC_DCW_0_clk0pos;
        4'b0110: dcw_comb = DTC_DCW_1_clk0pos;
        4'b1100: dcw_comb = DTC_DCW_2_clk2pos;
        4'b1001: dcw_comb = DTC_DCW_3_clk2pos;
        default: dcw_comb = DTC_DCW_0_clk0pos;
    endcase
end

always @ (posedge FDTC or negedge NARST) begin
    if (!NARST) begin
        dcw_comb_d1 <= 0;
        DTC_DCW <= 0;
    end else begin
        dcw_comb_d1 <= dcw_comb;
        DTC_DCW <= dcw_comb_d1;
    end
end

// MMD DCW retimer
// dcw2-3 @ clk2 pos
reg [7-1:0] MMD_DCW_0_clk0pos;
reg [7-1:0] MMD_DCW_1_clk0pos;
reg [7-1:0] MMD_DCW_2_clk2pos;
reg [7-1:0] MMD_DCW_3_clk2pos;
reg [4*7-1:0] MMD_DCW_X4_d1;
reg [7-1:0] mmd_dcw_comb;

always @ (posedge DIG_CLK[0] or negedge NARST) begin
    if (!NARST) begin
        MMD_DCW_X4_d1 <= {4{7'd4}};
    end else begin
        MMD_DCW_X4_d1 <= MMD_DCW_X4;
    end
end

initial begin
    MMD_DCW_0_clk0pos = 7'd4;
    MMD_DCW_1_clk0pos = 7'd4;
    MMD_DCW_2_clk2pos = 7'd4;
    MMD_DCW_3_clk2pos = 7'd4;
end

always @* begin
    MMD_DCW_0_clk0pos = MMD_DCW_X4_d1[1*7-1-:7];
    MMD_DCW_1_clk0pos = MMD_DCW_X4_d1[2*7-1-:7];
end

always @ (posedge DIG_CLK[2]) begin
    MMD_DCW_2_clk2pos <= MMD_DCW_X4_d1[3*7-1-:7];
    MMD_DCW_3_clk2pos <= MMD_DCW_X4_d1[4*7-1-:7];
end

always @* begin
    // case (DIG_CLK)
    //     4'b0110: MMD_DCW = MMD_DCW_0_clk0pos;
    //     4'b1100: MMD_DCW = MMD_DCW_1_clk0pos;
    //     4'b1001: MMD_DCW = MMD_DCW_2_clk2pos;
    //     4'b0011: MMD_DCW = MMD_DCW_3_clk2pos;
    //     default: MMD_DCW = MMD_DCW_0_clk0pos;
    // endcase
    case (DIG_CLK)
        4'b1001: mmd_dcw_comb = MMD_DCW_0_clk0pos;
        4'b0011: mmd_dcw_comb = MMD_DCW_1_clk0pos;
        4'b0110: mmd_dcw_comb = MMD_DCW_2_clk2pos;
        4'b1100: mmd_dcw_comb = MMD_DCW_3_clk2pos;
        default: mmd_dcw_comb = MMD_DCW_0_clk0pos;
    endcase
end

always @ (posedge FDTC or negedge NARST) begin
    if (!NARST) begin
        MMD_DCW <= 4;
    end else begin
        MMD_DCW <= mmd_dcw_comb;
    end
end

// RT DCW retimer
// dcw2-3 @ clk2 pos
reg RT_DCW_0_clk0pos;
reg RT_DCW_1_clk0pos;
reg RT_DCW_2_clk2pos;
reg RT_DCW_3_clk2pos;
reg rt_dcw_comb;

initial begin
    RT_DCW_0_clk0pos = 0;
    RT_DCW_1_clk0pos = 0;
    RT_DCW_2_clk2pos = 0;
    RT_DCW_3_clk2pos = 0;
    rt_dcw_comb = 0;
end

always @* begin
    RT_DCW_0_clk0pos = RT_DCW_X4[0];
    RT_DCW_1_clk0pos = RT_DCW_X4[1];
end

always @ (posedge DIG_CLK[2]) begin
    RT_DCW_2_clk2pos <= RT_DCW_X4[2];
    RT_DCW_3_clk2pos <= RT_DCW_X4[3];
end

always @* begin
    case (DIG_CLK)
        4'b0110: rt_dcw_comb = RT_DCW_0_clk0pos;
        4'b1100: rt_dcw_comb = RT_DCW_1_clk0pos;
        4'b1001: rt_dcw_comb = RT_DCW_2_clk2pos;
        4'b0011: rt_dcw_comb = RT_DCW_3_clk2pos;
        default: rt_dcw_comb = RT_DCW_0_clk0pos;
    endcase
end

always @ (posedge FDTC or negedge NARST) begin
    if (!NARST) begin
        RT_DCW <= 0;
    end else begin
        RT_DCW <= rt_dcw_comb;
    end
end

// combine psamp into clk0-3 domain
// psamp retimer
reg [`MP_SEG-1:0] psamp_clk_itl [3:0], psamp_clk1 [3:0];
reg [4*`MP_SEG-1:0] PSAMP_X4;
reg [`MP_SEG_BIN-1:0] phe;
reg [`MP_SEG_BIN-1:0] phe0, phe1, phe2, phe3;
reg [`MP_SEG_BIN-1:0] phe_comb_clk1 [3:0];

// calculate phase error in 2G analog domain
integer i;
always @* begin
    for (i=0; i<`MP_SEG; i=i+1) begin
        if (i < `MP_SEG-1) begin
            if ((psamp[i] == 1'b1) & (~psamp[i+1])) begin
                phe = i;
            end
        end else begin
            if ((psamp[`MP_SEG-1] == 1'b1) & (~psamp[0])) begin
                phe = `MP_SEG-1;
            end
        end
    end
end

// should pay attention to the sampler time sequence
// a delay is insert to sampled phe to make sure DIG_CLK can sample the phe in last period correctly
reg [`MP_SEG_BIN-1:0] phe_dly;
always @* begin
    phe_dly <= #(10e-15) phe;
end

always @ (posedge DIG_CLK[1]) phe0 <= phe_dly;
always @ (posedge DIG_CLK[2]) phe1 <= phe_dly;
always @ (posedge DIG_CLK[3]) phe2 <= phe_dly;
always @ (posedge DIG_CLK[0]) phe3 <= phe_dly;

always @ (posedge DIG_CLK[1]) begin
    phe_comb_clk1[0] <= phe0;
    phe_comb_clk1[1] <= phe1;
    phe_comb_clk1[2] <= phe2;
    phe_comb_clk1[3] <= phe3;
end

always @* begin
    PHE_X4[1*`MP_SEG_BIN-1-:`MP_SEG_BIN] = phe_comb_clk1[0];
    PHE_X4[2*`MP_SEG_BIN-1-:`MP_SEG_BIN] = phe_comb_clk1[1];
    PHE_X4[3*`MP_SEG_BIN-1-:`MP_SEG_BIN] = phe_comb_clk1[2];
    PHE_X4[4*`MP_SEG_BIN-1-:`MP_SEG_BIN] = phe_comb_clk1[3];
end

endmodule