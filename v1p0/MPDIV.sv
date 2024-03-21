`timescale 1s/1fs

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
real delay_linear [7:0], delay_nonlinear [7:0], delay_tot [7:0];

genvar geni;

generate
    for (geni=0; geni<8; geni=geni+1) begin
        always @(posedge mpck[geni]) begin
            rand6bit[geni] = {$random} %64;
            delay_linear[geni] = $unsigned(rand6bit[geni]) * t_res;
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