
// -------------------------------------------------------
// Module Name: DTCDCDER
// Function: decode DTC DCW binary 2 temp
// Author: Yang Yumeng Date: 1/13 2024
// Version: v1p1
// -------------------------------------------------------
module DTCDCDER (
IN,
NARST,
CLK,
DTC_DCWMSBO,
DTC_DCWLSBO,
DTC_DCWTEST
);

input [11:0] IN;
input NARST;
input CLK; // DTC output clk, posedge is delayed by dtc
output reg [63:0] DTC_DCWMSBO; // temp code
output reg [5:0] DTC_DCWLSBO; // binary code
output reg [11:0] DTC_DCWTEST;

wire [63:0] temp;
wire NRST;

assign temp = {64{1'b1}}>>IN[11:6];

SYNCRSTGEN_N U0_SYNCRST_N ( .CLK (CLK), .NARST (NARST), .NRST (NRST));

always @ (negedge CLK or negedge NRST) begin
    if (!NRST) begin
        DTC_DCWLSBO <= 0;
        DTC_DCWMSBO <= 0;
        DTC_DCWTEST <= 0;
    end else begin
        DTC_DCWLSBO <= IN[5:0];
        DTC_DCWMSBO <= ~temp;
        DTC_DCWTEST <= IN;
    end
end

endmodule