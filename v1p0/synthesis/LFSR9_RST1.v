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
