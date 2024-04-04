`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: LFSR32_RST1
// Function: 32 bit LFSR used in DSM for dither, set initial state to 32'd1
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0, according to FOD v1p0
// -------------------------------------------------------
module LFSR9_RST1 (
CLK,
NRST,
EN,
URN6B,
URN64T
);

input CLK;
input NRST;
input EN;
output reg [5:0] URN6B;
output reg [63:0] URN64T;

wire lfsr_fb;
reg [9:1] lfsr;
reg [5:0] lfsr_6b;
reg [63:0] lfsr_64t;
integer i;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		URN6B <= 0;
		URN64T <= 0;
	end else begin
		URN6B <= EN? lfsr_6b: 0;
		URN64T <= EN? lfsr_64t: 0;
	end
end

always @* begin
    lfsr_6b = lfsr[6:1];
    lfsr_64t = 0;
    for (i=0; i<=5; i=i+1) begin
        lfsr_64t = lfsr_64t + (lfsr_6b[i]<<i);
    end
end

// create feedback polynomials
assign lfsr_fb = lfsr[9] ^~ lfsr[5];

always @(posedge CLK or negedge NRST) begin
	if(!NRST)
		lfsr <= 1;
	else if (EN) begin
		lfsr <= {lfsr[8:1], lfsr_fb};
	end else begin
		lfsr <= 1;
	end
end

endmodule

// ------------------------------------------------------------
// Module Name: MPDIV8
// Function: outputs 1G clocks in interleave 8 phases
//              these phases are dithered within a CLK period range
// Authot: Yumeng Yang Date: 2024-3-15
// Version: v1p0
// ------------------------------------------------------------

module MPDIV8 (
NARST,
CLK,
FMP_RND,
FMP
);

input NARST;
input CLK;
output [7:0] FMP_RND;
output [7:0] FMP;


// multi-phases divider
reg [2:0] cnt;
reg [7:0] mpck;

always @ (posedge CLK or negedge NARST) begin
    if (!NARST) begin
        cnt <= 0;
    end else begin
        cnt <= cnt + 1;
    end
end

always @* begin
    mpck[0] = (cnt>=0) && (cnt<=3);
    mpck[1] = (cnt>=1) && (cnt<=4);
    mpck[2] = (cnt>=2) && (cnt<=5);
    mpck[3] = (cnt>=3) && (cnt<=6);
    mpck[4] = (cnt>=4) && (cnt<=7);
    mpck[5] = ((cnt>=5) && (cnt<=7)) || (cnt==0);
    mpck[6] = ((cnt>=6) && (cnt<=7)) || ((cnt>=0) && (cnt<=1));
    mpck[7] = (cnt>=7) || ((cnt>=0) && (cnt<=2));
end

// clk dither
parameter real t_res = 125e-12/64 * 1;
parameter real t_ofst = 0;
real t_delta;
reg [7:0] mpck_dly;

reg [5:0] rand6bit [7:0];
wire [5:0] rand6bit_lfsr;
real delay_linear [7:0], delay_nonlinear [7:0], delay_tot [7:0];

reg RND_EN;
initial begin
    RND_EN = 1;
end

LFSR9_RST1 U0_LFSR9 (
.CLK(mpck[0]),
.NRST(NARST),
.EN(RND_EN),
.URN6B(rand6bit_lfsr),
.URN64T()
);

integer fp1;
initial begin
    fp1 = $fopen("rand.txt");
end

genvar geni;

generate
    for (geni=0; geni<8; geni=geni+1) begin
        always @(posedge mpck[geni]) begin
            rand6bit[geni] = {$random} %64;
            $fstrobe(fp1, "%3.13e %d %d", $realtime, $unsigned(rand6bit[0]), $unsigned(rand6bit_lfsr));
            delay_linear[geni] = $unsigned(rand6bit_lfsr) * t_res;
            delay_nonlinear[geni] = 0 * $sin(1.0*rand6bit[geni]/64 * 3.14) * t_res;
            delay_tot[geni] = t_ofst + delay_linear[geni] + delay_nonlinear[geni];
        end

        always @* begin
            mpck_dly[geni] <= #(delay_tot[geni]) mpck[geni];
        end
    end
endgenerate

assign FMP_RND = mpck_dly & mpck;
assign FMP = mpck;

endmodule

// ------------------------------------------------------------
// Module Name: MPDIV4
// Function: outputs 500M clocks in interleave 4 phases according to FOD output
// Authot: Yumeng Yang Date: 2024-3-16
// Version: v1p0
// ------------------------------------------------------------

module MPDIV4 (
NARST,
CLK,
FMP
);

input NARST;
input CLK;
output reg [3:0] FMP;


// multi-phases divider
reg [1:0] cnt;

initial begin
    cnt = 0;
end

always @ (posedge CLK) begin
    cnt <= cnt + 1;
end

always @ (posedge CLK) begin
    FMP[0] <= (cnt>=0) && (cnt<=1);
    FMP[1] <= (cnt>=1) && (cnt<=2);
    FMP[2] <= (cnt>=2) && (cnt<=3);
    FMP[3] <= (cnt>=3) || (cnt<=0);
end

endmodule