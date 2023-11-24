`timescale 1s / 1fs

`define WI 6
`define WF 16
// -------------------------------------------------------
// Module Name: LFSR32_RST1
// Function: 32 bit LFSR used in DSM for dither, set initial state to 32'd1
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0, according to FOD v1p0
// -------------------------------------------------------
module LFSR32_RST1 (
CLK,
NRST,
EN,
DO,
URN16
);

input CLK;
input NRST;
input EN;
output reg DO;
output reg [`WF-1:0] URN16;

wire lfsr_fb;
reg [32:1] lfsr;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		DO <= 1'b0;
		URN16 <= 0;
	end else begin
		DO <= EN? lfsr[1]: 1'b0;
		URN16 <= EN? lfsr[`WF:1]: 0;
	end
end

// create feedback polynomials
assign lfsr_fb = lfsr[32] ^~ lfsr[22] ^~ lfsr[2] ^~ lfsr[1];

always @(posedge CLK or negedge NRST) begin
	if(!NRST)
		lfsr <= 32'b1;
	else if (EN) begin
		lfsr <= {lfsr[31:1], lfsr_fb};
	end else begin
		lfsr <= 32'b1;
	end
end

endmodule

// -------------------------------------------------------
// Module Name: LFSR32_RST2
// Function: 32 bit LFSR used in DSM for dither, set initial state to 32'h100010000
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0, according to FOD v1p0
// -------------------------------------------------------
module LFSR32_RST2 (
CLK,
NRST,
EN,
DO,
URN16
);

input CLK;
input NRST;
input EN;
output reg DO;
output reg [`WF-1:0] URN16;

wire lfsr_fb;
reg [32:1] lfsr;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		DO <= 1'b0;
		URN16 <= 0;
	end else begin
		DO <= EN? lfsr[1]: 1'b0;
		URN16 <= EN? lfsr[`WF:1]: 0;
	end
end

// create feedback polynomials
assign lfsr_fb = lfsr[32] ^~ lfsr[22] ^~ lfsr[2] ^~ lfsr[1];

always @(posedge CLK or negedge NRST) begin
	if(!NRST)
		lfsr <= 32'h10001000;
	else if (EN) begin
		lfsr <= {lfsr[31:1], lfsr_fb};
	end else begin
		lfsr <= 32'h10001000;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: DSM_MESH1
// Function: MESH1
// Author: Yang Yumeng Date: 3/15 2023
// Version: v1p0
// -------------------------------------------------------
module DSM_MESH1(
CLK,
NRST,
EN,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input [`WF-1:0] IN;
output reg [3:0] OUT; // ufix, 0 to 1
output reg [`WF+1:0] PHE; // ufix, 0<x<1

// internal signal
wire [`WF:0] sum1_temp;
wire [`WF-1:0] sum1;
reg [`WF-1:0] sum1_reg;
wire ca1;

// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE <= 0;
	end else if (EN) begin
		OUT <= ca1;
		PHE <= sum1;
	end
end

assign sum1_temp = sum1_reg + IN;
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = sum1_temp[`WF];
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum1_reg <= 0;
	else if (EN) begin 
		sum1_reg <= sum1;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: DSM_MESH11_DN
// Function: MESH11+dither
// Author: Yang Yumeng Date: 3/15 2023
// Version: v1p0
// -------------------------------------------------------
module DSM_MESH11_DN(
CLK,
NRST,
EN,
DN_EN,
DN_WEIGHT,
IN,
OUT,
PHE
);
// io
input CLK;
input NRST;
input EN;
input DN_EN;
input [4:0] DN_WEIGHT; // dither weight, left shift, 0-31, default is 2
input [`WF-1:0] IN;
output reg [3:0] OUT; // sfix, 2-order (-1 to 2)
output reg [`WF+1:0] PHE; // ufix, 0<x<2

// internal signal
wire [`WF:0] sum1_temp;
wire [`WF:0] sum2_temp;
wire [`WF-1:0] sum1;
wire [`WF-1:0] sum2;
reg [`WF-1:0] sum1_reg;
reg [`WF-1:0] sum2_reg;
wire [1:0] ca1;
wire [1:0] ca2;
reg [1:0] ca2_reg; // output combine

wire [`WF-1:0] dn;
wire LFSR_DN;

// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) ca2_reg <= 0;
	else if (EN) begin
		ca2_reg <= ca2;
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE <= 0;
	end else if (EN) begin
		OUT <= ca1 + ca2 - ca2_reg;
		PHE <= -(ca2<<`WF) + sum1 + {1'b1, {`WF{1'b0}}};
	end
end

// 2-orser adder
LFSR32_RST1 	DSMMESH11DN_LFSR32 ( .CLK(CLK), .NRST(NRST), .EN(EN&DN_EN), .DO(LFSR_DN), .URN16() );
assign dn = LFSR_DN? ((1'b1) << DN_WEIGHT): 0;

assign sum1_temp = sum1_reg + IN;
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = {1'b0, sum1_temp[`WF]};
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum1_reg <= 0;
	else if (EN) begin 
		sum1_reg <= sum1;
	end
end

assign sum2_temp = sum2_reg + sum1 + dn;
assign sum2 = sum2_temp[`WF-1:0];
assign ca2 = {1'b0, sum2_temp[`WF]};
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum2_reg <= 0;
	else if (EN) begin 
		sum2_reg <= sum2;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: DSM_PMESH1_PDS_DN
// Function: parallel MESH1+PDS dither
// Author: Yang Yumeng Date: 3/15 2023
// Version: v1p0
// -------------------------------------------------------
module DSM_PMESH1_PDS_DN(
CLK,
NRST,
EN,
DN_EN,
DN_WEIGHT,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input DN_EN;
input [4:0] DN_WEIGHT; // dither weight, right shift, 0-31, default is 0
input [`WF-1:0] IN;
output reg [3:0] OUT; // sfix, 2-order (-1 to 2)
output reg [`WF+1:0] PHE; // ufix, 0<x<2

// internal signal
wire [`WF+1:0] in1; // ufix, [0,2)
wire [`WF+1:0] in2;
wire [`WF+1:0] sum1_temp; // ufix, [0,3)
wire [`WF+1:0] sum2_temp;
wire [`WF+1:0] sum1; // ufix, [0,1)
wire [`WF+1:0] sum2;
reg  [`WF+1:0] sum1_reg; // ufix, [0,1)
reg  [`WF+1:0] sum2_reg;
wire [1:0] ca1; // ufix, {0,1,2}
wire [1:0] ca2;

wire [`WF-1:0] URN;

// parallel DSM
assign in1 = 0  + (URN>>DN_WEIGHT);
assign in2 = IN - (URN>>DN_WEIGHT) + (1'b1<<`WF);

assign sum1_temp = in1 + sum1_reg;
assign sum2_temp = in2 + sum2_reg;
assign ca1 = sum1_temp[`WF+1:`WF];
assign ca2 = sum2_temp[`WF+1:`WF];
assign sum1 = sum1_temp[`WF-1:0];
assign sum2 = sum2_temp[`WF-1:0];

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		sum1_reg <= 0;
		sum2_reg <= 0;
	end else if (EN) begin
		sum1_reg <= sum1;
		sum2_reg <= sum2;
	end
end

// output merge
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE <= 0;
	end else if (EN) begin
		OUT <= ca1 + ca2 - 1'd1;
		PHE <= sum1 + sum2;
	end
end

// URN generate
LFSR32_RST1 	DSMPMESH1PDSDN_LFSR32 ( .CLK(CLK), .NRST(NRST), .EN(EN&DN_EN), .DO(), .URN16(URN) );

endmodule

// -------------------------------------------------------
// Module Name: DSM_MESH11_PDS_DN
// Function: MESH11+PDS dither
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0
// -------------------------------------------------------
module DSM_MESH11_PDS_DN (
CLK,
NRST,
EN,
DN_EN,
DN_WEIGHT,
DN_MODE,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input DN_EN;
input [4:0] DN_WEIGHT; // dither weight, right shift, 0-31, default is 0
input [1:0] DN_MODE; // 0: MESH11 w/o URN; 1: 1 URN + MESH1; 2: 1 URN + MESH11; 3: 2 URN + MESH11
input [`WF-1:0] IN;
output reg [3:0] OUT; // (sfix) mode 0: -1 to 2; mode 1: -1 to 2; mode 2: -2 to 3; mode 3: -3 to 4
output reg [`WF+1:0] PHE; // (ufix) mode 0: -1<=x<1; mode 1: -1<=x<1; mode 2: -2<=x<1; mode 3: -2<x<2; [0,4)

// internal signal
wire [`WF+2:0] sum1_temp; // (sfix) [0,2)
wire [`WF+2:0] sum2_temp; // (sfix) [-1,3)
wire [`WF-1:0] sum1; // (ufix) [0,1)
wire [`WF-1:0] sum2; // (ufix) [0,1)
reg [`WF-1:0] sum1_reg;
reg [`WF-1:0] sum2_reg;
wire [2:0] ca1; // (sfix) 0,1
wire [2:0] ca2; // (sfix) -1,0,1,2
reg [2:0] ca2_reg; 

wire [1:0] phe_comp; // compensation, mode 0/1 with 1, mode 2/3 with 2
wire [`WF-1:0] URN1; // (ufix) [0,1)
wire [`WF-1:0] URN2; // (ufix) [0,1)
reg [`WF+2:0] DN; // (sfix) [-1,2)

// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) ca2_reg <= 0;
	else if (EN) begin
		ca2_reg <= ca2;
	end
end

assign phe_comp = DN_MODE[1]? 2'b10: 2'b01;
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE <= 0;
	end else if (EN) begin
		OUT <= {ca1[2], ca1} + {ca2[2], ca2} - {ca2_reg[2], ca2_reg};
		PHE <= -(ca2<<`WF) + sum1 + {phe_comp, {`WF{1'b0}}};
	end
end

// dither generate
always @* begin
	case (DN_MODE)
		2'b00: begin // MESH11 w/o URN
			DN = sum2_reg;
		end
		2'b01: begin // 1 URN + MESH1
			DN = URN1;
		end
		2'b10: begin // 1 URN + MESH11
			DN = sum2_reg + (URN1>>DN_WEIGHT);
		end
		2'b11: begin // 2 URN + MESH11
			DN = sum2_reg + (URN1>>DN_WEIGHT) - (URN2>>DN_WEIGHT);
		end
	endcase
end

assign sum1_temp = sum1_reg + IN;
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = sum1_temp[`WF+2:`WF];
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum1_reg <= 0;
	else if (EN) begin 
		sum1_reg <= sum1;
	end
end

assign sum2_temp = sum1 + DN;
assign sum2 = sum2_temp[`WF-1:0];
assign ca2 = sum2_temp[`WF+2:`WF];
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum2_reg <= 0;
	else if (EN) begin 
		sum2_reg <= sum2;
	end
end

// URN generate
LFSR32_RST1 	DSMMESH11PDSDN_LFSR32_URN1 ( .CLK(CLK), .NRST(NRST), .EN(EN&DN_EN), .DO(), .URN16(URN1) );
LFSR32_RST2 	DSMMESH11PDSDN_LFSR32_URN2 ( .CLK(CLK), .NRST(NRST), .EN(EN&DN_EN), .DO(), .URN16(URN2) );

endmodule
// -------------------------------------------------------
// Module Name: DSM_DN
// Function: MESH1/ MESH11+DITHER/ PARALLEL MESH1+PDS DITHER/ MESH11+PDS DITHER
// Author: Yang Yumeng Date: 3/16 2023
// Version: v1p0, according to FOD
// -------------------------------------------------------
module DSM_DN (
CLK,
NRST,
EN,
DN_EN,
DN_WEIGHT,
DSM_MODE,
DN_MODE,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input DN_EN;
input [4:0] DN_WEIGHT; // dither weight, shift, 0-31
input [1:0] DSM_MODE; // 0: MESH1, 1: MESH11+DITHER, 2: PARALLEL MESH1+PDS DITHER, 3: MESH11+PDS DITHER
input [1:0] DN_MODE; // use in DSM_MODE 3; 0: MESH11 w/o URN; 1: 1 URN + MESH1; 2: 1 URN + MESH11; 3: 2 URN + MESH11
input [`WF-1:0] IN;
output reg [3:0] OUT; // sfix, [-3,4]
output reg [`WF+1:0] PHE; // ufix, 0<x<4

// internal signal
reg [3:0] en_sel;
wire [3:0] out0, out1, out2, out3;
wire [`WF+1:0] phe0, phe1, phe2, phe3;

// DSM selector
always @* begin
	case (DSM_MODE)
		2'b00: begin // MESH1
			en_sel = EN? 4'b0001: 0;
			OUT = out0;
			PHE = phe0;
		end
		2'b01: begin // MESH11+DITHER
			en_sel = EN? 4'b0010: 0;
			OUT = out1;
			PHE = phe1;
		end
		2'b10: begin // PARALLEL MESH1+PDS DITHER
			en_sel = EN? 4'b0100: 0;
			OUT = out2;
			PHE = phe2;
		end
		2'b11: begin // MESH11+PDS DITHER
			en_sel = EN? 4'b1000: 0;
			OUT = out3;
			PHE = phe3;
		end
	endcase
end

DSM_MESH1 U0 ( .CLK(CLK), .NRST(NRST), .EN(en_sel[0]), .IN(IN), .OUT(out0), .PHE(phe0) );
DSM_MESH11_DN U1 ( .CLK(CLK), .NRST(NRST), .EN(en_sel[1]), .DN_EN(DN_EN), .DN_WEIGHT(DN_WEIGHT), .IN(IN), .OUT(out1), .PHE(phe1) );
DSM_PMESH1_PDS_DN U2 ( .CLK(CLK), .NRST(NRST), .EN(en_sel[2]), .DN_EN(DN_EN), .DN_WEIGHT(DN_WEIGHT), .IN(IN), .OUT(out2), .PHE(phe2) );
DSM_MESH11_PDS_DN U3 ( .CLK(CLK), .NRST(NRST), .EN(en_sel[3]), .DN_EN(DN_EN), .DN_WEIGHT(DN_WEIGHT), .DN_MODE(DN_MODE), .IN(IN), .OUT(out3), .PHE(phe3) );

// test signal
integer fp1;
integer fp2;
real rphe;

// initial fp1 = $fopen("./sdmout.txt");
// initial fp2 = $fopen("./phe.txt");

// always @ (posedge CLK) begin
	// $fstrobe(fp1, "%3.15e %d", $realtime, $signed(OUT));
	// $fstrobe(fp2, "%3.15e %.4f", $realtime, $unsigned(PHE)*(2.0**(-`WF)));
// end

always @* begin
	rphe = $unsigned(PHE)*(2.0**(-`WF));
end

endmodule
// -------------------------------------------------------
// Module Name: DTCMMDCTRL
// Function: MMD & DTC control logic + DTC NONLINEAR CALIBRATION, dtc calibration 2nd nonlinear with piecewise method
//			build the calibration moduel with real type
// 			segments for piecewise linear fitting could be adjusted
//			add an optional mode for kdtc calibration
//			implement the DPD algorithm by fixed point
// Author: Yang Yumeng Date: 1/20 2022
// Version: v4p1, insert register to adjust temporal logic
//			add register from lsm_errX_ext to LUTX
// -------------------------------------------------------
module DTCMMDCTRL (
NRST,
DSM_EN,
DN_EN,
DN_WEIGHT,
DSM_MODE,
DN_MODE,
MMD_EN,
DTC_EN,
GAC_EN,
CALIORDER,
PSEC,
SECSEL_TEST,
REGSEL_TEST,
FCW,
CKVD,
KDTCA_INIT,
KDTCB_INIT,
KDTCC_INIT,
KA,
KB,
KC,
PHE_SIG,
MMDDCW_P,
MMDDCW_S,
DTCDCW,
KDTC_TEST
);

input NRST;
input DSM_EN;
input DN_EN;
input [4:0] DN_WEIGHT; // default `WF-DN_WEIGHT=12
input [1:0] DSM_MODE;
input [1:0] DN_MODE;
input MMD_EN;
input DTC_EN;
input GAC_EN;
input [2:0] CALIORDER;
input [2:0] PSEC; // piecewise segments control, 1 seg -- 4/ 2 seg -- 3/ 4 seg -- 2/ 8 seg -- 1/ 16 seg -- 0/
input [1:0] SECSEL_TEST; // 0or1 -- kdtcA/ 2 -- kdtcB/ 3 -- kdtcC
input [3:0] REGSEL_TEST; // reg0~15
input [`WI+`WF-1:0] FCW;
input CKVD;
// kdtc should cover 4096 for fin=1G, dtc_res=200fs, and there is another 1 bit for sign. kdtc 13 bit for WI is enough
input [13-1:0] KDTCA_INIT;
input [13-1:0] KDTCB_INIT;
input [13-1:0] KDTCC_INIT; // piecewise initial point, 1 seg -- 0/ 2 seg -- kdtc/ 4 seg -- kdtc/2/ 8 seg -- kdtc/4/ 16 seg -- kdtc/8/
input [4:0] KA; // range -16 to 15, kdtc cali step
input [4:0] KB;
input [4:0] KC;
input PHE_SIG;
output reg [6:0] MMDDCW_P;
output reg MMDDCW_S;
output reg [11:0] DTCDCW;
output reg [13-1:0] KDTC_TEST;

// internal signal
wire [`WI-1:0] FCW_I;
wire [`WF-1:0] FCW_F;
wire iDSM_EN;
wire iDTC_EN;
wire int_flag;
wire [3:0] dsm_car; // [-3,4]
wire [`WF+1:0] dsm_phe; // 0<x<4
wire [4+`WF-1:0] dsm_phel_2nd;
wire [16+`WF:0] product;
wire [16+`WF:0] product0;
wire [14+`WF:0] product1;
wire [16+`WF:0] product2;
wire [11:0] dtc_temp;
wire [6:0] mmd_temp;
reg [11:0] dtc_reg;

reg sig_sync;
reg [`WF+1:0] phel_reg1;
reg [`WF+1:0] phel_reg2;
reg [`WF+1:0] phel_sync;
reg [4+`WF-1:0] phel_reg1_2nd;
reg [4+`WF-1:0] phel_reg2_2nd;
reg [4+`WF-1:0] phel_sync_2nd; // 0<x^2<4
wire [13+`WF-1:0] kdtcA_cali;
wire [13+`WF-1:0] kdtcB_cali;
wire [13+`WF-1:0] kdtcC_cali;
wire signed [5+`WF-1:0] lms_errA; // integral range
wire signed [5+`WF-1:0] lms_errB;
wire signed [5+`WF-1:0] lms_errC;
wire [13+`WF-1:0] lms_errA_ext; 
wire [13+`WF-1:0] lms_errB_ext; 
wire [13+`WF-1:0] lms_errC_ext; 

// cali coefficient LUT
integer i;
reg [3:0] phe_msb;
reg [`WF+1:0] phe_lsb;
reg [3:0] phem_reg1;
reg [3:0] phem_reg2;
reg [3:0] phem_sync;
reg [13+`WF-1:0] LUTA [15:0];
reg [13+`WF-1:0] LUTB [15:0];
reg [13+`WF-1:0] LUTC [15:0];
reg [13+`WF-1:0] lut_test;

// reg
reg [6:0] mmd_temp_p_reg1;
reg [6:0] mmd_temp_p_reg2;
reg [6:0] mmd_temp_p_reg3;
reg [6:0] mmd_temp_p_reg4;
reg mmd_temp_s_reg1;
reg mmd_temp_s_reg2;
reg mmd_temp_s_reg3;
reg mmd_temp_s_reg4;
reg [13+`WF-1:0] kdtcA_cali_reg1;
reg [13+`WF-1:0] kdtcA_cali_reg2;
reg [13+`WF-1:0] kdtcB_cali_reg1;
reg [13+`WF-1:0] kdtcB_cali_reg2;
reg [13+`WF-1:0] kdtcC_cali_reg1;
reg [13+`WF-1:0] kdtcC_cali_reg2;
reg [`WF+1:0] phe_lsb_reg1;
reg [`WF+1:0] phe_lsb_reg2;
reg [`WF+1:0] phe_lsb_reg3;
reg [`WF+1:0] phe_lsb_reg4;
reg [16+`WF:0] product0_reg1;
reg [16+`WF:0] product0_reg2;
reg [3:0] phe_msb_reg1;
reg [3:0] phe_msb_reg2;
reg [3:0] phe_msb_reg3;
reg [3:0] phe_msb_reg4;
reg [4+`WF-1:0] dsm_phel_2nd_reg1;
reg [4+`WF-1:0] dsm_phel_2nd_reg2;

reg [3:0] phem_sync_reg;
reg [13+`WF-1:0] lms_errA_ext_reg; 
reg [13+`WF-1:0] lms_errB_ext_reg; 
reg [13+`WF-1:0] lms_errC_ext_reg; 

assign {FCW_I, FCW_F} = FCW;
assign int_flag = |FCW_F;
assign iDSM_EN = int_flag & DSM_EN; // disable DSM if fcw is integer
assign iDTC_EN = int_flag & DTC_EN;

// MMD CTRL
assign mmd_temp = FCW_I + {{3{dsm_car[3]}}, dsm_car};

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_p_reg1 <= 7'd50;
		mmd_temp_p_reg2 <= 7'd50;
		mmd_temp_p_reg3 <= 7'd50;
		mmd_temp_p_reg4 <= 7'd50;
		MMDDCW_P <= 7'd50;
	end else if (MMD_EN) begin
		mmd_temp_p_reg1 <= mmd_temp;
		mmd_temp_p_reg2 <= mmd_temp_p_reg1;
		mmd_temp_p_reg3 <= mmd_temp_p_reg2;
		mmd_temp_p_reg4 <= mmd_temp_p_reg3;
		MMDDCW_P <= mmd_temp_p_reg4;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_s_reg1 <= 1'b0;
		mmd_temp_s_reg2 <= 1'b0;
		mmd_temp_s_reg3 <= 1'b0;
		mmd_temp_s_reg4 <= 1'b0;
		MMDDCW_S <= 1'b0;
	end else if (MMD_EN) begin
		mmd_temp_s_reg1 <= (FCW_I>64)? 1'b1: 1'b0;
		mmd_temp_s_reg2 <= mmd_temp_s_reg1;
		mmd_temp_s_reg3 <= mmd_temp_s_reg2;
		mmd_temp_s_reg4 <= mmd_temp_s_reg3;
		MMDDCW_S <= mmd_temp_s_reg4;
	end
end

// DTC CTRL
// assign phe_msb = dsm_phe[`WF:`WF-3]>>PSEC; // 15 segments
// assign phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 

always @* begin
	case({DSM_MODE, DN_MODE})
		4'b00_00: begin // MESH1
					phe_msb = dsm_phe[`WF-1:`WF-4]>>PSEC;	
					phe_lsb = ((dsm_phe<<(6-PSEC))>>(6-PSEC)); 
				end
		4'b01_00: begin // MESH11 + DITHER
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b10_00: begin // PARALLEL MESH1+PDS DITHER
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_00: begin // MESH11+PDS DITHER; MESH11 w/o URN
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_01: begin // MESH11+PDS DITHER; 1 URN + MESH1
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_10: begin // MESH11+PDS DITHER; 1 URN + MESH11
					phe_msb = dsm_phe[`WF+1:`WF-2]>>PSEC;	
					phe_lsb = ((dsm_phe<<(4-PSEC))>>(4-PSEC)); 
				end
		4'b11_11: begin // MESH11+PDS DITHER; 2 URN + MESH11
					phe_msb = dsm_phe[`WF+1:`WF-2]>>PSEC;	
					phe_lsb = ((dsm_phe<<(4-PSEC))>>(4-PSEC)); 
				end
		default: begin // MESH1
					phe_msb = dsm_phe[`WF-1:`WF-4]>>PSEC;
					phe_lsb = ((dsm_phe<<(6-PSEC))>>(6-PSEC)); 					
				end
	endcase
end

assign kdtcA_cali = LUTA[phe_msb]; assign kdtcB_cali = LUTB[phe_msb]; assign kdtcC_cali = LUTC[phe_msb];

USWI1WF16PRO #(2, `WF) U0_DTCMMDCTRL_USWI1WF16PRO( .NRST(NRST), .CLK(CKVD), .PRO(dsm_phel_2nd), .MULTIA(phe_lsb), .MULTIB(phe_lsb) );

SWIWFPRO #(13, 5, `WF) U1_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product2), .MULTIAS(kdtcA_cali_reg2), .MULTIBS({1'b0, dsm_phel_2nd}) );
SWIWFPRO #(13, 3, `WF) U2_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product1), .MULTIAS(kdtcB_cali_reg2), .MULTIBS({1'b0, phe_lsb_reg2}) );

assign product0 = {{4{kdtcC_cali_reg2[12+`WF]}}, kdtcC_cali_reg2};
assign product = product2 + {{2{product1[14+`WF]}}, product1} + product0_reg2;
assign dtc_temp = product[`WF-1]? (product[11+`WF:`WF]+1'b1): product[11+`WF:`WF];

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		dtc_reg <= 0;
		DTCDCW <= 0;
	end else begin
		dtc_reg <= iDTC_EN? dtc_temp: 0;
		DTCDCW <= iDTC_EN? dtc_reg: 0;
	end
end

// DTC NONLINEAR CALI
// generate synchronouse phe and phe_sig
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		sig_sync <= 0;
	
		phel_reg1 <= 0;
		phel_reg2 <= 0;
		phel_sync <= 0;

		phel_reg1_2nd <= 0;
		phel_reg2_2nd <= 0;
		phel_sync_2nd <= 0;
		
		phem_reg1 <= 0;
		phem_reg2 <= 0;
		phem_sync <= 0;
	end else if (GAC_EN) begin
		sig_sync <= PHE_SIG;
		
		phel_reg1 <= phe_lsb_reg4;
		phel_reg2 <= phel_reg1;
		phel_sync <= phel_reg2;
		
		phel_reg1_2nd <= dsm_phel_2nd_reg2;
		phel_reg2_2nd <= phel_reg1_2nd;
		phel_sync_2nd <= phel_reg2_2nd;
		
		phem_reg1 <= phe_msb_reg4;
		phem_reg2 <= phem_reg1;
		phem_sync <= phem_reg2;
	end
end

// LUT calibration
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// LUT initial
		for (i = 15; i >= 0; i = i-1) begin
			LUTA[i] <= KDTCA_INIT<<`WF;
			LUTB[i] <= KDTCB_INIT<<`WF;
		end
		for (i = 15; i >= 0; i = i-1) begin
			LUTC[i] <= (KDTCC_INIT*i)<<`WF;		
		end
	end else if (GAC_EN) begin
		LUTA[phem_sync_reg] <= LUTA[phem_sync_reg] + lms_errA_ext_reg;
		LUTB[phem_sync_reg] <= LUTB[phem_sync_reg] + lms_errB_ext_reg;
		LUTC[phem_sync_reg] <= (|phem_sync_reg)? (LUTC[phem_sync_reg] + lms_errC_ext_reg): 0;
	end
end

// piecewise start point cali
assign lms_errC = sig_sync? {5'b00001, {`WF{1'b0}}}: {5'b11111, {`WF{1'b0}}}; // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errC_ext = CALIORDER[0]? (KC[4]? (lms_errC>>>(~KC+1'b1)): (lms_errC<<<KC)): 0;

// 1-st nonlinear
assign lms_errB = sig_sync? {3'b000, phel_sync}: (~{3'b000, phel_sync}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errB_ext = CALIORDER[1]? (KB[4]? (lms_errB>>>(~KB+1'b1)): (lms_errB<<<KB)): 0;

// 2-nd nonlinear
assign lms_errA = sig_sync? {1'b0, phel_sync_2nd}: (~{1'b0, phel_sync_2nd}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errA_ext = CALIORDER[2]? (KA[4]? (lms_errA>>>(~KA+1'b1)): (lms_errA<<<KA)): 0;

// DSM
DSM_DN DTCMMDCTRL_DSM ( .CLK (CKVD), .NRST (NRST), .EN (iDSM_EN), .DN_EN (DN_EN), .IN (FCW_F), 
								.OUT (dsm_car), .PHE (dsm_phe), .DN_WEIGHT(DN_WEIGHT), .DSM_MODE(DSM_MODE), .DN_MODE(DN_MODE) );

// register
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		kdtcA_cali_reg1 <= 0;
		kdtcA_cali_reg2 <= 0;
		kdtcB_cali_reg1 <= 0;
		kdtcB_cali_reg2 <= 0;
		kdtcC_cali_reg1 <= 0;
		kdtcC_cali_reg2 <= 0;
	end else begin
		kdtcA_cali_reg1 <= kdtcA_cali;
		kdtcA_cali_reg2 <= kdtcA_cali_reg1;
		kdtcB_cali_reg1 <= kdtcB_cali;
		kdtcB_cali_reg2 <= kdtcB_cali_reg1;
		kdtcC_cali_reg1 <= kdtcC_cali;
		kdtcC_cali_reg2 <= kdtcC_cali_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_lsb_reg1 <= 0;
		phe_lsb_reg2 <= 0;
		phe_lsb_reg3 <= 0;
		phe_lsb_reg4 <= 0;
	end else begin
		phe_lsb_reg1 <= phe_lsb;
		phe_lsb_reg2 <= phe_lsb_reg1;
		phe_lsb_reg3 <= phe_lsb_reg2;
		phe_lsb_reg4 <= phe_lsb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_msb_reg1 <= 0;
		phe_msb_reg2 <= 0;
		phe_msb_reg3 <= 0;
		phe_msb_reg4 <= 0;
	end else begin
		phe_msb_reg1 <= phe_msb;
		phe_msb_reg2 <= phe_msb_reg1;
		phe_msb_reg3 <= phe_msb_reg2;
		phe_msb_reg4 <= phe_msb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		product0_reg1 <= 0;
		product0_reg2 <= 0;
	end else begin
		product0_reg1 <= product0;
		product0_reg2 <= product0_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		dsm_phel_2nd_reg1 <= 0;
		dsm_phel_2nd_reg2 <= 0;
	end else begin
		dsm_phel_2nd_reg1 <= dsm_phel_2nd;
		dsm_phel_2nd_reg2 <= dsm_phel_2nd_reg1;
	end
end

always @ (posedge CKVD) begin
	phem_sync_reg <= phem_sync;
	lms_errA_ext_reg <= lms_errA_ext;
	lms_errB_ext_reg <= lms_errB_ext;
	lms_errC_ext_reg <= lms_errC_ext;
end

// kdtc test output signal
always @* begin
	case (SECSEL_TEST)
		2'b11: lut_test = LUTC[REGSEL_TEST]; // kdtcC
		2'b10: lut_test = LUTB[REGSEL_TEST]; // kdtcB
		default: lut_test = LUTA[REGSEL_TEST]; //kdtcA
	endcase
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		KDTC_TEST <= 0;
	end else begin
		KDTC_TEST <= lut_test[13+`WF-1:`WF];
	end
end

// test
real rphe, rphel, rphel_2;
real luta0, luta1, luta2, luta3, lutb0, lutb1, lutb2, lutb3, lutc0, lutc1, lutc2, lutc3;
real rp1, rp2, rp;
integer fp_w1, fp_w2, fp_w3, fp_w4;
integer j;

always @* begin
	rphe = dsm_phe * (2.0**(-`WF));
	rphel = phe_lsb * (2.0**(-`WF));
	rphel_2 = dsm_phel_2nd * (2.0**(-`WF));
	rp1 = $signed(product1) * (2.0**(-`WF));
	rp2 = $signed(product2) * (2.0**(-`WF));
	rp = $signed(product) * (2.0**(-`WF));
	luta0 = $signed(LUTA[0]) * (2.0**(-`WF));
	luta1 = $signed(LUTA[1]) * (2.0**(-`WF));
	luta2 = $signed(LUTA[2]) * (2.0**(-`WF));
	luta3 = $signed(LUTA[3]) * (2.0**(-`WF));
	lutb0 = $signed(LUTB[0]) * (2.0**(-`WF));
	lutb1 = $signed(LUTB[1]) * (2.0**(-`WF));
	lutb2 = $signed(LUTB[2]) * (2.0**(-`WF));
	lutb3 = $signed(LUTB[3]) * (2.0**(-`WF));
	lutc0 = $signed(LUTC[0]) * (2.0**(-`WF));
	lutc1 = $signed(LUTC[1]) * (2.0**(-`WF));
	lutc2 = $signed(LUTC[2]) * (2.0**(-`WF));
	lutc3 = $signed(LUTC[3]) * (2.0**(-`WF));
end

integer fp1;
integer fp2;

initial fp1 = $fopen("./main_sdmout.txt");
initial fp2 = $fopen("./main_phe.txt");

always @ (posedge CKVD) begin
	$fstrobe(fp1, "%3.15e %d", $realtime, $signed(dsm_car));
	$fstrobe(fp2, "%3.15e %.8f", $realtime, rphe);
end

// initial begin
	// fp_w1 = $fopen("dtc_dcw.txt");
	// fp_w2 = $fopen("dtc_luta.txt");
	// fp_w3 = $fopen("dtc_lutb.txt");
	// fp_w4 = $fopen("dtc_lutc.txt");
// end
// always @ (posedge CKVD) begin
	// $fstrobe(fp_w1, "%3.13e %d %d", $realtime, $unsigned(dsm_phe)*(2.0**(-`WF)), $unsigned(dtc_temp));
	// // LUTA
	// $fwrite(fp_w2, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w2, " %f", $signed(LUTA[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w2, "\n");
	// // LUTB
	// $fwrite(fp_w3, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w3, " %f", $signed(LUTB[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w3, "\n");
	// // LUTC
	// $fwrite(fp_w4, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w4, " %f", $signed(LUTC[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w4, "\n");
// end

endmodule

// -------------------------------------------------------
// Module Name: AUXDTCMMDCTRL
// Function: extract spur information with BBPD array
// Author: Yang Yumeng Date: 4/7 2023
// Version: v1p0
// -------------------------------------------------------
module AUXDTCMMDCTRL (
NRST,
DSM_EN,
DN_EN,
DN_WEIGHT,
DSM_MODE,
DN_MODE,
MMD_EN,
DTC_EN,
GAC_EN,
PHASEC_EN,
PHASE_DN_EN,
CALIORDER,
PSEC,
SECSEL_TEST,
REGSEL_TEST,
FCW,
FCW_REF,
CKVD,
KDTCA_INIT,
KDTCB_INIT,
KDTCC_INIT,
KA,
KB,
KC,
KPHASE,
PHE_SIG,
MMDDCW_P,
MMDDCW_S,
DTCDCW,
KDTC_TEST
);

input NRST;
input DSM_EN;
input DN_EN;
input [4:0] DN_WEIGHT; // default `WF-DN_WEIGHT=12
input [1:0] DSM_MODE;
input [1:0] DN_MODE;
input MMD_EN;
input DTC_EN;
input GAC_EN;
input PHASEC_EN;
input PHASE_DN_EN;
input [2:0] CALIORDER;
input [2:0] PSEC; // piecewise segments control, 1 seg -- 4/ 2 seg -- 3/ 4 seg -- 2/ 8 seg -- 1/ 16 seg -- 0/
input [1:0] SECSEL_TEST; // 0or1 -- kdtcA/ 2 -- kdtcB/ 3 -- kdtcC
input [3:0] REGSEL_TEST; // reg0~15
input [`WI+`WF-1:0] FCW;
input [`WI+`WF-1:0] FCW_REF;
input CKVD;
// kdtc should cover 4096 for fin=1G, dtc_res=200fs, and there is another 1 bit for sign. kdtc 13 bit for WI is enough
input [13-1:0] KDTCA_INIT;
input [13-1:0] KDTCB_INIT;
input [13-1:0] KDTCC_INIT; // piecewise initial point, 1 seg -- 0/ 2 seg -- kdtc/ 4 seg -- kdtc/2/ 8 seg -- kdtc/4/ 16 seg -- kdtc/8/
input [4:0] KA; // range -16 to 15, kdtc cali step
input [4:0] KB;
input [4:0] KC;
input [4:0] KPHASE;
input [31:0] PHE_SIG;
output reg [6:0] MMDDCW_P;
output reg MMDDCW_S;
output reg [11:0] DTCDCW;
output reg [13-1:0] KDTC_TEST;

// internal signal
wire [`WI-1:0] FCW_I;
wire [`WF-1:0] FCW_F;
wire iDSM_EN;
wire iDTC_EN;
wire int_flag;
wire [3:0] dsm_car; // [-3,4]
wire [`WF+1:0] dsm_phe; // 0<x<4
wire [4+`WF-1:0] dsm_phel_2nd;
wire [16+`WF:0] product;
wire [16+`WF:0] product0;
wire [14+`WF:0] product1;
wire [16+`WF:0] product2;
wire [11:0] dtc_temp;
wire [6:0] mmd_temp;
reg [11:0] dtc_reg;

// reg sig_sync;
reg [`WF+1:0] phel_reg1;
reg [`WF+1:0] phel_reg2;
reg [`WF+1:0] phel_reg3;
reg [`WF+1:0] phel_sync;
reg [4+`WF-1:0] phel_reg1_2nd;
reg [4+`WF-1:0] phel_reg2_2nd;
reg [4+`WF-1:0] phel_reg3_2nd;
reg [4+`WF-1:0] phel_sync_2nd; // 0<x^2<4
wire [13+`WF-1:0] kdtcA_cali;
wire [13+`WF-1:0] kdtcB_cali;
wire [13+`WF-1:0] kdtcC_cali;
wire signed [5+`WF-1:0] lms_errA; // integral range
wire signed [5+`WF-1:0] lms_errB;
wire signed [5+`WF-1:0] lms_errC;
wire [13+`WF-1:0] lms_errA_ext; 
wire [13+`WF-1:0] lms_errB_ext; 
wire [13+`WF-1:0] lms_errC_ext; 

// cali coefficient LUT
integer i;
reg [3:0] phe_msb;
reg [`WF+1:0] phe_lsb; // 1bit for sign
reg [3:0] phem_reg1;
reg [3:0] phem_reg2;
reg [3:0] phem_reg3;
reg [3:0] phem_sync;
reg [13+`WF-1:0] LUTA [15:0];
reg [13+`WF-1:0] LUTB [15:0];
reg [13+`WF-1:0] LUTC [15:0];
reg [13+`WF-1:0] lut_test;

// reg
reg [6:0] mmd_temp_p_reg1;
reg [6:0] mmd_temp_p_reg2;
reg [6:0] mmd_temp_p_reg3;
reg [6:0] mmd_temp_p_reg4;
reg mmd_temp_s_reg1;
reg mmd_temp_s_reg2;
reg mmd_temp_s_reg3;
reg mmd_temp_s_reg4;
reg [13+`WF-1:0] kdtcA_cali_reg1;
reg [13+`WF-1:0] kdtcA_cali_reg2;
reg [13+`WF-1:0] kdtcB_cali_reg1;
reg [13+`WF-1:0] kdtcB_cali_reg2;
reg [13+`WF-1:0] kdtcC_cali_reg1;
reg [13+`WF-1:0] kdtcC_cali_reg2;
reg [`WF+1:0] phe_lsb_reg1;
reg [`WF+1:0] phe_lsb_reg2;
reg [`WF+1:0] phe_lsb_reg3;
reg [`WF+1:0] phe_lsb_reg4;
reg [16+`WF:0] product0_reg1;
reg [16+`WF:0] product0_reg2;
reg [3:0] phe_msb_reg1;
reg [3:0] phe_msb_reg2;
reg [3:0] phe_msb_reg3;
reg [3:0] phe_msb_reg4;
reg [4+`WF-1:0] dsm_phel_2nd_reg1;
reg [4+`WF-1:0] dsm_phel_2nd_reg2;

reg [3:0] phem_sync_reg;
reg [13+`WF-1:0] lms_errA_ext_reg; 
reg [13+`WF-1:0] lms_errB_ext_reg; 
reg [13+`WF-1:0] lms_errC_ext_reg; 

assign {FCW_I, FCW_F} = FCW;
assign int_flag = |FCW_F;
assign iDSM_EN = int_flag & DSM_EN; // disable DSM if fcw is integer
assign iDTC_EN = int_flag & DTC_EN;

// MMD CTRL
assign mmd_temp = FCW_I + {{3{dsm_car[3]}}, dsm_car};

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_p_reg1 <= 7'd50;
		mmd_temp_p_reg2 <= 7'd50;
		mmd_temp_p_reg3 <= 7'd50;
		mmd_temp_p_reg4 <= 7'd50;
		MMDDCW_P <= 7'd50;
	end else if (MMD_EN) begin
		mmd_temp_p_reg1 <= mmd_temp;
		mmd_temp_p_reg2 <= mmd_temp_p_reg1;
		mmd_temp_p_reg3 <= mmd_temp_p_reg2;
		mmd_temp_p_reg4 <= mmd_temp_p_reg3;
		MMDDCW_P <= mmd_temp_p_reg4;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_s_reg1 <= 1'b0;
		mmd_temp_s_reg2 <= 1'b0;
		mmd_temp_s_reg3 <= 1'b0;
		mmd_temp_s_reg4 <= 1'b0;
		MMDDCW_S <= 1'b0;
	end else if (MMD_EN) begin
		mmd_temp_s_reg1 <= (FCW_I>64)? 1'b1: 1'b0;
		mmd_temp_s_reg2 <= mmd_temp_s_reg1;
		mmd_temp_s_reg3 <= mmd_temp_s_reg2;
		mmd_temp_s_reg4 <= mmd_temp_s_reg3;
		MMDDCW_S <= mmd_temp_s_reg4;
	end
end

// DTC CTRL
// assign phe_msb = dsm_phe[`WF:`WF-3]>>PSEC; // 15 segments
// assign phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 

always @* begin
	case({DSM_MODE, DN_MODE})
		4'b00_00: begin // MESH1
					phe_msb = dsm_phe[`WF-1:`WF-4]>>PSEC;	
					phe_lsb = ((dsm_phe<<(6-PSEC))>>(6-PSEC)); 
				end
		4'b01_00: begin // MESH11 + DITHER
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b10_00: begin // PARALLEL MESH1+PDS DITHER
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_00: begin // MESH11+PDS DITHER; MESH11 w/o URN
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_01: begin // MESH11+PDS DITHER; 1 URN + MESH1
					phe_msb = dsm_phe[`WF:`WF-3]>>PSEC;	
					phe_lsb = ((dsm_phe<<(5-PSEC))>>(5-PSEC)); 
				end
		4'b11_10: begin // MESH11+PDS DITHER; 1 URN + MESH11
					phe_msb = dsm_phe[`WF+1:`WF-2]>>PSEC;	
					phe_lsb = ((dsm_phe<<(4-PSEC))>>(4-PSEC)); 
				end
		4'b11_11: begin // MESH11+PDS DITHER; 2 URN + MESH11
					phe_msb = dsm_phe[`WF+1:`WF-2]>>PSEC;	
					phe_lsb = ((dsm_phe<<(4-PSEC))>>(4-PSEC)); 
				end
		default: begin // MESH1
					phe_msb = dsm_phe[`WF-1:`WF-4]>>PSEC;
					phe_lsb = ((dsm_phe<<(6-PSEC))>>(6-PSEC)); 					
				end
	endcase
end

assign kdtcA_cali = LUTA[phe_msb]; assign kdtcB_cali = LUTB[phe_msb]; assign kdtcC_cali = LUTC[phe_msb];

USWI1WF16PRO #(2, `WF) U0_DTCMMDCTRL_USWI1WF16PRO( .NRST(NRST), .CLK(CKVD), .PRO(dsm_phel_2nd), .MULTIA(phe_lsb), .MULTIB(phe_lsb) );

SWIWFPRO #(13, 5, `WF) U1_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product2), .MULTIAS(kdtcA_cali_reg2), .MULTIBS({1'b0, dsm_phel_2nd}) );
SWIWFPRO #(13, 3, `WF) U2_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product1), .MULTIAS(kdtcB_cali_reg2), .MULTIBS({1'b0, phe_lsb_reg2}) );

assign product0 = {{4{kdtcC_cali_reg2[12+`WF]}}, kdtcC_cali_reg2};
assign product = product2 + {{2{product1[14+`WF]}}, product1} + product0_reg2;
assign dtc_temp = product[`WF-1]? (product[11+`WF:`WF]+1'b1): product[11+`WF:`WF];

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		dtc_reg <= 0;
		DTCDCW <= 0;
	end else begin
		dtc_reg <= iDTC_EN? dtc_temp: 0;
		DTCDCW <= iDTC_EN? dtc_reg: 0;
	end
end

// DTC NONLINEAR CALI
// compare measured refmod phase with digital phase

reg [1+`WI+`WF-1:0] fcw_accum_flag0, fcw_accum_flag1, fcw_accum_flag2, fcw_accum_flag3, fcw_accum_flag4, fcw_accum_flag5, fcw_accum_flag6, fcw_accum_flag7, fcw_accum_flag8;
reg [1+`WI+`WF-1:0] fcw_accum; // accumulate fcw
reg [`WI+`WF-1:0] fcw_accum_reg; // accumulate fcw and quantify with fcw_ref
wire [5+`WI+`WF-1:0] phase_d_norm; 
reg [5-1:0] phase_m;
wire [5+`WF-1:0] phase_m_ext;
wire [5+`WF-1:0] phase_m_dn;
wire [5+`WF-1:0] phase_m_dn_comp;
wire [5+`WI+`WF-1:0] phase_m_norm;
wire [`WF-1:0] phase_dither;
wire [`WF-1:0] URN16;
reg [5+`WF-1:0] phase_d_comp; // digital phase comp
wire signed [6+`WI+`WF-1:0] phase_err_norm_flag; // 1bit for sign
wire signed [5+`WI+`WF-1:0] phase_err_norm; // 1bit for sign
wire signed [5+`WI+`WF-1:0] phase_err_norm_shift; // 1bit for sign
wire signed [5+`WI+`WF-1:0] phase_err_norm_signed; // 1bit for sign
// wire signed [5+`WF-1:0] phase_err_cut;
wire signed [5+`WF-1:0] phase_err_quant;
wire [5+`WF-1:0] phase_err_ext;
wire sig_sync;

// time sequence adjustment
reg signed [6+`WI+`WF-1:0] phase_err_norm_flag_reg1;

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phase_m <= 5'd0;
	end else if (PHASEC_EN|GAC_EN) begin
		if ((~PHE_SIG[0])&PHE_SIG[1]) phase_m <= 5'd0;
		else if ((~PHE_SIG[1 ])&PHE_SIG[2 ]) phase_m <= 5'd1 ;
		else if ((~PHE_SIG[2 ])&PHE_SIG[3 ]) phase_m <= 5'd2 ;
		else if ((~PHE_SIG[3 ])&PHE_SIG[4 ]) phase_m <= 5'd3 ;
		else if ((~PHE_SIG[4 ])&PHE_SIG[5 ]) phase_m <= 5'd4 ;
		else if ((~PHE_SIG[5 ])&PHE_SIG[6 ]) phase_m <= 5'd5 ;
		else if ((~PHE_SIG[6 ])&PHE_SIG[7 ]) phase_m <= 5'd6 ;
		else if ((~PHE_SIG[7 ])&PHE_SIG[8 ]) phase_m <= 5'd7 ;
		else if ((~PHE_SIG[8 ])&PHE_SIG[9 ]) phase_m <= 5'd8 ;
		else if ((~PHE_SIG[9 ])&PHE_SIG[10]) phase_m <= 5'd9 ;
		else if ((~PHE_SIG[10])&PHE_SIG[11]) phase_m <= 5'd10;
		else if ((~PHE_SIG[11])&PHE_SIG[12]) phase_m <= 5'd11;
		else if ((~PHE_SIG[12])&PHE_SIG[13]) phase_m <= 5'd12;
		else if ((~PHE_SIG[13])&PHE_SIG[14]) phase_m <= 5'd13;
		else if ((~PHE_SIG[14])&PHE_SIG[15]) phase_m <= 5'd14;
		else if ((~PHE_SIG[15])&PHE_SIG[16]) phase_m <= 5'd15;
		else if ((~PHE_SIG[16])&PHE_SIG[17]) phase_m <= 5'd16;
		else if ((~PHE_SIG[17])&PHE_SIG[18]) phase_m <= 5'd17;
		else if ((~PHE_SIG[18])&PHE_SIG[19]) phase_m <= 5'd18;
		else if ((~PHE_SIG[19])&PHE_SIG[20]) phase_m <= 5'd19;
		else if ((~PHE_SIG[20])&PHE_SIG[21]) phase_m <= 5'd20;
		else if ((~PHE_SIG[21])&PHE_SIG[22]) phase_m <= 5'd21;
		else if ((~PHE_SIG[22])&PHE_SIG[23]) phase_m <= 5'd22;
		else if ((~PHE_SIG[23])&PHE_SIG[24]) phase_m <= 5'd23;
		else if ((~PHE_SIG[24])&PHE_SIG[25]) phase_m <= 5'd24;
		else if ((~PHE_SIG[25])&PHE_SIG[26]) phase_m <= 5'd25;
		else if ((~PHE_SIG[26])&PHE_SIG[27]) phase_m <= 5'd26;
		else if ((~PHE_SIG[27])&PHE_SIG[28]) phase_m <= 5'd27;
		else if ((~PHE_SIG[28])&PHE_SIG[29]) phase_m <= 5'd28;
		else if ((~PHE_SIG[29])&PHE_SIG[30]) phase_m <= 5'd29;
		else if ((~PHE_SIG[30])&PHE_SIG[31]) phase_m <= 5'd30;
		else if ((~PHE_SIG[31])&PHE_SIG[0 ]) phase_m <= 5'd31;
		else phase_m <= 5'd0;
	end else begin
		phase_m <= 5'd0;
	end
end

// assign phase_d_sync = phase_d + phase_d_comp;
// always @ (posedge CKVD or negedge NRST) begin
	// if (!NRST) begin
		// phase_d <= 0;
		// URN16_d1 <= 0;
	// end else if (PHASEC_EN) begin
		// phase_d <= phase_d + FCW_NORM + phase_dither;
		// URN16_d1 <= URN16;
	// end
// end

// digital phase generate
always @* begin
	fcw_accum_flag0 = fcw_accum_reg + FCW;
	fcw_accum_flag1 = fcw_accum_flag0 - FCW_REF;
	fcw_accum_flag2 = fcw_accum_flag1 - FCW_REF;
	fcw_accum_flag3 = fcw_accum_flag2 - FCW_REF;
	fcw_accum_flag4 = fcw_accum_flag3 - FCW_REF;
	fcw_accum_flag5 = fcw_accum_flag4 - FCW_REF;
	fcw_accum_flag6 = fcw_accum_flag5 - FCW_REF;
	fcw_accum_flag7 = fcw_accum_flag6 - FCW_REF;
	fcw_accum_flag8 = fcw_accum_flag7 - FCW_REF;
	if (fcw_accum_flag1[`WI+`WF]) fcw_accum = fcw_accum_flag0;
	else if ((~fcw_accum_flag1[`WI+`WF])&fcw_accum_flag2[`WI+`WF]) fcw_accum = fcw_accum_flag1;
	else if ((~fcw_accum_flag2[`WI+`WF])&fcw_accum_flag3[`WI+`WF]) fcw_accum = fcw_accum_flag2;
	else if ((~fcw_accum_flag3[`WI+`WF])&fcw_accum_flag4[`WI+`WF]) fcw_accum = fcw_accum_flag3;
	else if ((~fcw_accum_flag4[`WI+`WF])&fcw_accum_flag5[`WI+`WF]) fcw_accum = fcw_accum_flag4;
	else if ((~fcw_accum_flag5[`WI+`WF])&fcw_accum_flag6[`WI+`WF]) fcw_accum = fcw_accum_flag5;
	else if ((~fcw_accum_flag6[`WI+`WF])&fcw_accum_flag7[`WI+`WF]) fcw_accum = fcw_accum_flag6;
	else if ((~fcw_accum_flag7[`WI+`WF])&fcw_accum_flag8[`WI+`WF]) fcw_accum = fcw_accum_flag7;
	else fcw_accum = fcw_accum_flag8;
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// URN16_d1 <= 0;
		fcw_accum_reg <= 0;
	end else if (PHASEC_EN) begin
		// URN16_d1 <= URN16;
		fcw_accum_reg <= fcw_accum;
	end
end

assign phase_d_norm = fcw_accum_reg<<5;

// analog phase generate
assign phase_dither = PHASE_DN_EN? URN16: 0;
LFSR32_RST1 	AUXDTCMMDCTRL_LFSR32_URN1 ( .CLK(CKVD), .NRST(NRST), .EN(PHASE_DN_EN), .DO(), .URN16(URN16) );

assign phase_m_ext = {phase_m, {`WF{1'b0}}};
assign phase_m_dn = phase_m_ext + phase_dither;
assign phase_m_dn_comp = phase_m_dn - phase_d_comp;
USWI1WF16SHIFT #(5+8, `WI+8) AUXDTCMMDCTRL_USWI1WF16SHIFT ( .PRO(phase_m_norm), .MULTIAI(phase_m_dn_comp[7]? (phase_m_dn_comp[5+`WF-1:8]+1'b1): phase_m_dn_comp[5+`WF-1:8]), .MULTIBF(FCW_REF[7]? (FCW_REF[`WI+`WF-1:8]+1'b1): FCW_REF[`WI+`WF-1:8]) );

// phase error generate
// assign phase_err = {phase_m, {`WF{1'b0}}} - phase_d_sync;
// assign sig_sync = phase_err[5+`WF-1];
assign phase_err_norm_flag = phase_m_norm - phase_d_norm;
// assign phase_err_norm = phase_err_norm_flag[6+`WI+`WF-1]? (phase_err_norm_flag + (FCW_REF<<5)): phase_err_norm_flag;
assign phase_err_norm = phase_err_norm_flag_reg1[6+`WI+`WF-1]? (phase_err_norm_flag_reg1 + (FCW_REF<<5)): phase_err_norm_flag_reg1;
assign phase_err_norm_shift = phase_err_norm - (FCW_REF<<4);
assign phase_err_norm_signed = phase_err_norm_shift[5+`WI+`WF-1]? phase_err_norm: (phase_err_norm - (FCW_REF<<5));
assign phase_err_quant = phase_err_norm_shift[5+`WI+`WF-1]? 21'h008000: (~21'h008000+1'b1);
assign sig_sync = phase_err_norm_signed[5+`WI+`WF-1];

// 
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phase_err_norm_flag_reg1 <= 0;
	end else if (PHASEC_EN|GAC_EN) begin
		phase_err_norm_flag_reg1 <= phase_err_norm_flag;
	end
end

// phase offset compensation
assign phase_err_ext = PHASEC_EN? (KPHASE[4]? (phase_err_quant>>>(~KPHASE+1'b1)): (phase_err_quant<<<KPHASE)): 0;

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phase_d_comp <= 0;
	end else if (PHASEC_EN) begin
		phase_d_comp <= phase_d_comp + phase_err_ext;
	end
end

// generate synchronouse phe and phe_sig
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// sig_sync <= 0;
	
		phel_reg1 <= 0;
		phel_reg2 <= 0;
		phel_reg3 <= 0;
		phel_sync <= 0;

		phel_reg1_2nd <= 0;
		phel_reg2_2nd <= 0;
		phel_reg3_2nd <= 0;
		phel_sync_2nd <= 0;
		
		phem_reg1 <= 0;
		phem_reg2 <= 0;
		phem_reg3 <= 0;
		phem_sync <= 0;
	end else if (GAC_EN) begin
		// sig_sync <= PHE_SIG;
		
		phel_reg1 <= phe_lsb_reg4;
		phel_reg2 <= phel_reg1;
		phel_reg3 <= phel_reg2;
		phel_sync <= phel_reg3;
		
		phel_reg1_2nd <= dsm_phel_2nd_reg2;
		phel_reg2_2nd <= phel_reg1_2nd;
		phel_reg3_2nd <= phel_reg2_2nd;
		phel_sync_2nd <= phel_reg3_2nd;
		
		phem_reg1 <= phe_msb_reg4;
		phem_reg2 <= phem_reg1;
		phem_reg3 <= phem_reg2;
		phem_sync <= phem_reg3;
	end
end

// LUT calibration
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// LUT initial
		for (i = 15; i >= 0; i = i-1) begin
			LUTA[i] <= KDTCA_INIT<<`WF;
			LUTB[i] <= KDTCB_INIT<<`WF;
		end
		for (i = 15; i >= 0; i = i-1) begin
			LUTC[i] <= (KDTCC_INIT*i)<<`WF;		
		end
	end else if (GAC_EN) begin
		LUTA[phem_sync_reg] <= LUTA[phem_sync_reg] + lms_errA_ext_reg;
		LUTB[phem_sync_reg] <= LUTB[phem_sync_reg] + lms_errB_ext_reg;
		LUTC[phem_sync_reg] <= (|phem_sync_reg)? (LUTC[phem_sync_reg] + lms_errC_ext_reg): 0;
	end
end

// cali test
// real lms_errB_test;
// real lms_errA_test;

// piecewise start point cali
assign lms_errC = sig_sync? {5'b00001, {`WF{1'b0}}}: {5'b11111, {`WF{1'b0}}}; // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errC_ext = CALIORDER[0]? (KC[4]? (lms_errC>>>(~KC+1'b1)): (lms_errC<<<KC)): 0;

// 1-st nonlinear
assign lms_errB = sig_sync? {3'b000, phel_sync}: (~{3'b000, phel_sync}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errB_ext = CALIORDER[1]? (KB[4]? (lms_errB>>>(~KB+1'b1)): (lms_errB<<<KB)): 0;

// always @* lms_errB_test = -1*$signed(phase_err_norm_signed)*(2.0**-`WF)*$unsigned(phel_sync)*(2.0**-`WF);
// // always @* lms_errB_test = -1*($signed(phase_err_norm_signed)>0? 1.0: -1.0)*$unsigned(phel_sync)*(2.0**-`WF);
// assign lms_errB = lms_errB_test*(2**`WF)*(2.0**-4);

// 2-nd nonlinear
assign lms_errA = sig_sync? {1'b0, phel_sync_2nd}: (~{1'b0, phel_sync_2nd}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errA_ext = CALIORDER[2]? (KA[4]? (lms_errA>>>(~KA+1'b1)): (lms_errA<<<KA)): 0;

// always @* lms_errA_test = -1*$signed(phase_err_norm_signed)*(2.0**-`WF)*$unsigned(phel_sync_2nd)*(2.0**-`WF);
// // always @* lms_errA_test = -1*($signed(phase_err_norm_signed)>0? 1.0: -1.0)*$unsigned(phel_sync_2nd)*(2.0**-`WF);
// assign lms_errA = lms_errA_test*(2**`WF)*(2.0**-4);

// DSM
DSM_DN DTCMMDCTRL_DSM ( .CLK (CKVD), .NRST (NRST), .EN (iDSM_EN), .DN_EN (DN_EN), .IN (FCW_F), 
								.OUT (dsm_car), .PHE (dsm_phe), .DN_WEIGHT(DN_WEIGHT), .DSM_MODE(DSM_MODE), .DN_MODE(DN_MODE) );

// register
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		kdtcA_cali_reg1 <= 0;
		kdtcA_cali_reg2 <= 0;
		kdtcB_cali_reg1 <= 0;
		kdtcB_cali_reg2 <= 0;
		kdtcC_cali_reg1 <= 0;
		kdtcC_cali_reg2 <= 0;
	end else begin
		kdtcA_cali_reg1 <= kdtcA_cali;
		kdtcA_cali_reg2 <= kdtcA_cali_reg1;
		kdtcB_cali_reg1 <= kdtcB_cali;
		kdtcB_cali_reg2 <= kdtcB_cali_reg1;
		kdtcC_cali_reg1 <= kdtcC_cali;
		kdtcC_cali_reg2 <= kdtcC_cali_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_lsb_reg1 <= 0;
		phe_lsb_reg2 <= 0;
		phe_lsb_reg3 <= 0;
		phe_lsb_reg4 <= 0;
	end else begin
		phe_lsb_reg1 <= phe_lsb;
		phe_lsb_reg2 <= phe_lsb_reg1;
		phe_lsb_reg3 <= phe_lsb_reg2;
		phe_lsb_reg4 <= phe_lsb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_msb_reg1 <= 0;
		phe_msb_reg2 <= 0;
		phe_msb_reg3 <= 0;
		phe_msb_reg4 <= 0;
	end else begin
		phe_msb_reg1 <= phe_msb;
		phe_msb_reg2 <= phe_msb_reg1;
		phe_msb_reg3 <= phe_msb_reg2;
		phe_msb_reg4 <= phe_msb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		product0_reg1 <= 0;
		product0_reg2 <= 0;
	end else begin
		product0_reg1 <= product0;
		product0_reg2 <= product0_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		dsm_phel_2nd_reg1 <= 0;
		dsm_phel_2nd_reg2 <= 0;
	end else begin
		dsm_phel_2nd_reg1 <= dsm_phel_2nd;
		dsm_phel_2nd_reg2 <= dsm_phel_2nd_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phem_sync_reg <= 0;
		lms_errA_ext_reg <= 0;
		lms_errB_ext_reg <= 0;
		lms_errC_ext_reg <= 0;
	end else begin
		phem_sync_reg <= phem_sync;
		lms_errA_ext_reg <= lms_errA_ext;
		lms_errB_ext_reg <= lms_errB_ext;
		lms_errC_ext_reg <= lms_errC_ext;
	end
end

// kdtc test output signal
always @* begin
	case (SECSEL_TEST)
		2'b11: lut_test = LUTC[REGSEL_TEST]; // kdtcC
		2'b10: lut_test = LUTB[REGSEL_TEST]; // kdtcB
		default: lut_test = LUTA[REGSEL_TEST]; //kdtcA
	endcase
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		KDTC_TEST <= 0;
	end else begin
		KDTC_TEST <= lut_test[13+`WF-1:`WF];
	end
end

// test
real rphe, rphel, rphel_2;
real luta0, luta1, luta2, luta3, lutb0, lutb1, lutb2, lutb3, lutc0, lutc1, lutc2, lutc3;
real rp1, rp2, rp;
// real rphase_d_comp, rphase_d;
real rphase_d_norm, rphase_m_dn, rphase_m_norm, rphase_d_comp, rphase_err_norm, rphase_err_ext, rphase_err_norm_signed;
integer fp_w1, fp_w2, fp_w3, fp_w4;
integer j;

always @* begin
	rphase_d_comp = $unsigned(phase_d_comp) * (2.0**(-`WF));
	// rphase_d = phase_d * (2.0**(-`WF));
	rphase_d_norm = phase_d_norm * (2.0**(-`WF)) / 32;
	rphase_m_dn = phase_m_dn * (2.0**(-`WF));
	rphase_m_norm = phase_m_norm * (2.0**(-`WF)) / 32;
	rphase_err_norm = $unsigned(phase_err_norm) * (2.0**(-`WF));
	rphase_err_norm_signed = $signed(phase_err_norm_signed) * (2.0**(-`WF));
	rphase_err_ext = $signed(phase_err_ext) * (2.0**(-`WF));
	
	rphe = dsm_phe * (2.0**(-`WF));
	rphel = phe_lsb * (2.0**(-`WF));
	rphel_2 = dsm_phel_2nd * (2.0**(-`WF));
	rp1 = $signed(product1) * (2.0**(-`WF));
	rp2 = $signed(product2) * (2.0**(-`WF));
	rp = $signed(product) * (2.0**(-`WF));
	luta0 = $signed(LUTA[0]) * (2.0**(-`WF));
	luta1 = $signed(LUTA[1]) * (2.0**(-`WF));
	luta2 = $signed(LUTA[2]) * (2.0**(-`WF));
	luta3 = $signed(LUTA[3]) * (2.0**(-`WF));
	lutb0 = $signed(LUTB[0]) * (2.0**(-`WF));
	lutb1 = $signed(LUTB[1]) * (2.0**(-`WF));
	lutb2 = $signed(LUTB[2]) * (2.0**(-`WF));
	lutb3 = $signed(LUTB[3]) * (2.0**(-`WF));
	lutc0 = $signed(LUTC[0]) * (2.0**(-`WF));
	lutc1 = $signed(LUTC[1]) * (2.0**(-`WF));
	lutc2 = $signed(LUTC[2]) * (2.0**(-`WF));
	lutc3 = $signed(LUTC[3]) * (2.0**(-`WF));
end

integer fp1;
integer fp2;

initial fp1 = $fopen("./aux_sdmout.txt");
initial fp2 = $fopen("./aux_phe.txt");

always @ (posedge CKVD) begin
	$fstrobe(fp1, "%3.15e %d", $realtime, $signed(dsm_car));
	$fstrobe(fp2, "%3.15e %.8f", $realtime, rphe);
end

// initial begin
	// fp_w1 = $fopen("dtc_dcw.txt");
	// fp_w2 = $fopen("dtc_luta.txt");
	// fp_w3 = $fopen("dtc_lutb.txt");
	// fp_w4 = $fopen("dtc_lutc.txt");
// end
// always @ (posedge CKVD) begin
	// $fstrobe(fp_w1, "%3.13e %d %d", $realtime, $unsigned(dsm_phe)*(2.0**(-`WF)), $unsigned(dtc_temp));
	// // LUTA
	// $fwrite(fp_w2, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w2, " %f", $signed(LUTA[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w2, "\n");
	// // LUTB
	// $fwrite(fp_w3, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w3, " %f", $signed(LUTB[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w3, "\n");
	// // LUTC
	// $fwrite(fp_w4, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w4, " %f", $signed(LUTC[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w4, "\n");
// end

endmodule