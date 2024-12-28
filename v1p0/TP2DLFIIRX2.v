`define WI 6
`define WF 16
`define WI_DLF 7
`define WF_DLF 26
`define OTWC_L 6
`define OTWF_L 7

// -------------------------------------------------------
// Module Name: TP2DLFIIRX2
// Function: type-II digital loop filter with iir filter
// Author: Yang Yumeng Date: 1/29 2022
// Version: v2p1, fixed point, insert register adjust temporal logic
//			add register at iir filter i/o
// -------------------------------------------------------
module TP2DLFIIRX2 (
NRST,
CKVD,
PDE,
DLFEN,
KPS,
KIS,
KIIR1S,
KIIR2S,
IIR1EN,
IIR2EN,
DSM1STEN,
DCTRL
);

input NRST;
input CKVD;
input PDE;
input DLFEN;
input [5:0] KPS; // shift -32~31
input [5:0] KIS;
input [5:0] KIIR1S;
input [5:0] KIIR2S;
input IIR1EN;
input IIR2EN;
input DSM1STEN;
output reg [`OTWF_L-1:0] DCTRL;

// internal signal
wire [`WI_DLF+`WF_DLF-1:0] KP;
wire [`WI_DLF+`WF_DLF-1:0] KI;
reg [`WI_DLF+`WF_DLF:0] prop_sum; // an additional bit for sign
reg [`WI_DLF+`WF_DLF:0] inte_sum;
wire [`WI_DLF+`WF_DLF:0] dlf_sum;
wire [`WI_DLF+`WF_DLF-1:0] usdlf_sum;
reg [`WI_DLF+`WF_DLF-1:0] iir_reg1;
reg [`WI_DLF+`WF_DLF-1:0] iir_reg2;
wire [`WI_DLF+`WF_DLF-1:0] iir_nxt1;
wire [`WI_DLF+`WF_DLF-1:0] iir_nxt2;
wire [`WI_DLF+`WF_DLF-1:0] iir_out1;
wire [`WI_DLF+`WF_DLF-1:0] iir_out2;
wire signed [`WI_DLF+`WF_DLF:0] subiir1;
wire signed [`WI_DLF+`WF_DLF:0] subiir2;
wire [`WI_DLF+`WF_DLF:0] subiir1_ext;
wire [`WI_DLF+`WF_DLF:0] subiir2_ext;
reg dsm_car;
reg [`WF_DLF-1:0] dsm_sum;
wire [`WI_DLF-1:0] DLF_TRUNC;
// register
reg [`WI_DLF+`WF_DLF-1:0] usdlf_sum_reg;
reg [`WI_DLF+`WF_DLF-1:0] iir_out1_reg;
reg [`WI_DLF+`WF_DLF-1:0] iir_out2_reg;

// generate dlf calculate coefficient
assign KP = KPS[5]? ({1'b1,{`WF_DLF{1'b0}}}>>(~KPS+1'b1)): ({1'b1, {`WF_DLF{1'b0}}}<<KPS);
assign KI = KIS[5]? ({1'b1,{`WF_DLF{1'b0}}}>>(~KIS+1'b1)): ({1'b1,{`WF_DLF{1'b0}}}<<KIS);

// dlf proportional & integral path
reg [`WI_DLF+`WF_DLF-1:0] dlf_rand;

initial dlf_rand = 0;
always @(posedge CKVD) begin
	dlf_rand = $random >>> 5;
end

assign dlf_sum = prop_sum + inte_sum;
assign usdlf_sum = dlf_sum[`WI_DLF+`WF_DLF-1:0];

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		prop_sum <= 0;
		inte_sum <= (1'b1<<(`WI_DLF+`WF_DLF-1));
	end else if (DLFEN) begin
		prop_sum <= PDE? KP: (~KP+1'b1);
		inte_sum <= inte_sum + (PDE? KI: (~KI+1'b1));
	end
end

// iir filter
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		iir_reg1 <= 0;
		iir_reg2 <= 0;
	end else begin
		iir_reg1 <= IIR1EN? iir_nxt1: 0;
		iir_reg2 <= IIR2EN? iir_nxt2: 0;
	end
end

assign subiir1 = IIR1EN? (usdlf_sum_reg - iir_reg1): 0;
assign subiir2 = IIR2EN? (iir_out1_reg - iir_reg2): 0;
assign subiir1_ext = KIIR1S[5]? (subiir1>>>(~KIIR1S+1'b1)): (subiir1<<<KIIR1S);
assign subiir2_ext = KIIR2S[5]? (subiir2>>>(~KIIR2S+1'b1)): (subiir2<<<KIIR2S);
assign iir_nxt1 = subiir1_ext[`WI_DLF+`WF_DLF-1:0] + iir_reg1;
assign iir_out1 = IIR1EN? iir_nxt1: usdlf_sum_reg;
assign iir_nxt2 = subiir2_ext[`WI_DLF+`WF_DLF-1:0] + iir_reg2;
assign iir_out2 = IIR2EN? iir_nxt2: iir_out1_reg;

// register for iir 1/o
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		usdlf_sum_reg <= 0;
		iir_out1_reg <= 0;
		iir_out2_reg <= 0;
	end else begin
		usdlf_sum_reg <= usdlf_sum;
		iir_out1_reg <= iir_out1;
		iir_out2_reg <= iir_out2;
	end
end

// 1-st order DSM
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		{dsm_car, dsm_sum} <= 0;
	end else if (DSM1STEN) begin
		{dsm_car, dsm_sum} <= dsm_sum + iir_out2_reg[`WF_DLF-1:0];
	end
end

assign DLF_TRUNC = iir_out2_reg[`WF_DLF-1]? (iir_out2_reg[`WI_DLF+`WF_DLF-1:`WF_DLF]+1'b1): iir_out2_reg[`WI_DLF+`WF_DLF-1:`WF_DLF];

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		DCTRL <= (1'b1<<(`WI_DLF-1));
	end else begin
		DCTRL <= DSM1STEN? (iir_out2_reg[`WI_DLF+`WF_DLF-1:`WF_DLF] + dsm_car): DLF_TRUNC;
	end
end

endmodule
