// -------------------------------------------------------
// Module Name: USWI1WF16SHIFT
// Function: [unsigned WI(1)WF(16)] = [unsigned WI(1)] * [unsigned WF(16)], realize multiplication by shift right
// Author: Yang Yumeng Date: 1/22 2022
// Version: v1p0
// -------------------------------------------------------
module USWI1WF16SHIFT(
PRO,
MULTIAI,
MULTIBF
);

parameter width_int = 1;
parameter width_frac = 16;

input [width_int-1:0] MULTIAI;
input [width_frac-1:0] MULTIBF;
output reg [width_int+width_frac-1:0] PRO;

integer i;
reg [width_int+width_frac-1:0] mai_ext;

always @ (MULTIAI or MULTIBF) begin
	mai_ext = MULTIAI<<width_frac;
	PRO = 0;
	for (i=width_frac-1; i>=0; i=i-1) begin
		PRO = MULTIBF[i]? (PRO+(mai_ext>>(width_frac-i))): PRO;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: USWF16WF16SHIFT
// Function: [unsigned WF(16)] = [unsigned WF(16)] * [unsigned WF(16)], realize multiplication by shift right
// Author: Yang Yumeng Date: 1/22 2022
// Version: v1p0
// -------------------------------------------------------
module USWF16WF16SHIFT(
PRO,
MULTIAF,
MULTIBF
);

parameter width_frac = 16;

input [width_frac-1:0] MULTIAF;
input [width_frac-1:0] MULTIBF;
output reg [width_frac-1:0] PRO;

integer i;

always @ (MULTIAF or MULTIBF) begin
	PRO = 0;
	for (i=width_frac-1; i>=0; i=i-1) begin
		PRO = MULTIBF[i]? (PRO+(MULTIAF>>(width_frac-i))): PRO;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: USWI1WF16PRO
// Function: [unsigned WI(2)WF(16)] = [unsigned WI(1)WF(16)] * [unsigned WI(1)WF(16)]
// Author: Yang Yumeng Date: 2/10 2022
// Version: v2p0, insert register to adjust temporal logic
// -------------------------------------------------------
module USWI1WF16PRO(
NRST,
CLK,
PRO,
MULTIA,
MULTIB
);

parameter width_int = 1;
parameter width_frac = 16;

input NRST;
input CLK;
input [width_int+width_frac-1:0] MULTIA;
input [width_int+width_frac-1:0] MULTIB;
output [2*width_int+width_frac-1:0] PRO;

// temp signal
wire [width_int-1:0] MAI;
wire [width_int-1:0] MBI;
wire [width_frac-1:0] MAF;
wire [width_frac-1:0] MBF;
wire [width_frac-1:0] PRF;
wire [2*width_int-1:0] proac;
wire [width_int+width_frac-1:0] proad;
wire [width_int+width_frac-1:0] procb;
wire [width_frac-1:0] probd;

reg [width_int-1:0] MAI_reg;
reg [width_int-1:0] MBI_reg;
reg [width_frac-1:0] MAF_reg;
reg [width_frac-1:0] MBF_reg;
reg [2*width_int-1:0] proac_reg;
reg [width_int+width_frac-1:0] proad_reg;
reg [width_int+width_frac-1:0] procb_reg;
reg [width_frac-1:0] probd_reg;

// divide into integer or decimal
assign MAI = MULTIA[width_int+width_frac-1:width_frac];
assign MBI = MULTIB[width_int+width_frac-1:width_frac];
assign MAF = MULTIA[width_frac-1:0];
assign MBF = MULTIB[width_frac-1:0];

// divide multiplication into 4 steps
assign proac = MAI_reg*MBI_reg;
USWI1WF16SHIFT #(width_int, width_frac) UX1_USWI1WF16PRO_USWI1WF16SHIFT (.PRO(proad), .MULTIAI(MAI_reg), .MULTIBF(MBF_reg));
USWI1WF16SHIFT #(width_int, width_frac) UX2_USWI1WF16PRO_USWI1WF16SHIFT (.PRO(procb), .MULTIAI(MBI_reg), .MULTIBF(MAF_reg));
USWF16WF16SHIFT #(width_frac) UX1_USWI1WF16PRO_USWF16WF16SHIFT (.PRO(probd), .MULTIAF(MAF_reg), .MULTIBF(MBF_reg));

// register
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		MAI_reg <= 0;
		MBI_reg <= 0;
		MAF_reg <= 0;
		MBF_reg <= 0;
		proac_reg <= 0;
		proad_reg <= 0;
		procb_reg <= 0;
		probd_reg <= 0;
	end else begin
		MAI_reg <= MAI;
		MBI_reg <= MBI;
		MAF_reg <= MAF;
		MBF_reg <= MBF;
		proac_reg <= proac;
		proad_reg <= proad;
		procb_reg <= procb;
		probd_reg <= probd;
	end
end

assign PRO = (proac_reg<<width_frac) + proad_reg + procb_reg + probd_reg;

endmodule

// -------------------------------------------------------
// Module Name: SWIWFPRO
// Function: [signed WI(1+12+2)WF(16)] = [signed WI(1+12)WF(16)] * [signed WI(1+2)WF(16)]
// Author: Yang Yumeng Date: 2/10 2022
// Version: v2p0, insert register to adjust temporal logic
// -------------------------------------------------------

module SWIWFPRO(
NRST,
CLK,
PROS,
MULTIAS,
MULTIBS
);

parameter width_int_a = 13;
parameter width_int_b = 3;
parameter width_frac = 16;

input NRST;
input CLK;
input [width_int_a+width_frac-1:0] MULTIAS;
input [width_int_b+width_frac-1:0] MULTIBS;
output [width_int_a+width_int_b+width_frac-2:0] PROS;

// temp signal
wire [width_int_a+width_frac-2:0] MULTIAUS;
wire [width_int_b+width_frac-2:0] MULTIBUS;
wire SA;
wire SB;
wire SP;
wire [width_int_a-2:0] MAI;
wire [width_int_b-2:0] MBI;
wire [width_frac-1:0] MAF;
wire [width_frac-1:0] MBF;
wire [width_int_a+width_int_b-3:0] proac;
wire [width_int_a+width_frac-2:0] proad;
wire [width_int_b+width_frac-2:0] procb;
wire [width_frac-1:0] probd;
wire [width_int_a+width_int_b+width_frac-3:0] prous;

reg SA_reg;
reg SB_reg;
reg SP_reg;
reg [width_int_a-2:0] MAI_reg;
reg [width_int_b-2:0] MBI_reg;
reg [width_frac-1:0] MAF_reg;
reg [width_frac-1:0] MBF_reg;
reg [width_int_a+width_int_b-3:0] proac_reg;
reg [width_int_a+width_frac-2:0] proad_reg;
reg [width_int_b+width_frac-2:0] procb_reg;
reg [width_frac-1:0] probd_reg;

// extract symbol bit
assign SA = MULTIAS[width_int_a+width_frac-1];
assign SB = MULTIBS[width_int_b+width_frac-1];
assign SP = SA_reg^SB_reg;
assign MULTIAUS = SA? (~MULTIAS[width_int_a+width_frac-2:0]+1'b1): MULTIAS[width_int_a+width_frac-2:0];
assign MULTIBUS = SB? (~MULTIBS[width_int_b+width_frac-2:0]+1'b1): MULTIBS[width_int_b+width_frac-2:0];

// divide into integer or decimal
assign MAI = MULTIAUS[width_int_a+width_frac-2:width_frac];
assign MBI = MULTIBUS[width_int_b+width_frac-2:width_frac];
assign MAF = MULTIAUS[width_frac-1:0];
assign MBF = MULTIBUS[width_frac-1:0];

// divide multiplication into 4 steps
assign proac = MAI_reg*MBI_reg;
USWI1WF16SHIFT #(width_int_a-1, width_frac) UX1_USWI1WF16PRO_USWI1WF16SHIFT (.PRO(proad), .MULTIAI(MAI_reg), .MULTIBF(MBF_reg));
USWI1WF16SHIFT #(width_int_b-1, width_frac) UX2_USWI1WF16PRO_USWI1WF16SHIFT (.PRO(procb), .MULTIAI(MBI_reg), .MULTIBF(MAF_reg));
USWF16WF16SHIFT #(width_frac) UX1_USWI1WF16PRO_USWF16WF16SHIFT (.PRO(probd), .MULTIAF(MAF_reg), .MULTIBF(MBF_reg));

// register
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		SA_reg <= 0;
		SB_reg <= 0;
		SP_reg <= 0;
		MAI_reg <= 0;
		MBI_reg <= 0;
		MAF_reg <= 0;
		MBF_reg <= 0;
		proac_reg <= 0;
		proad_reg <= 0;
		procb_reg <= 0;
		probd_reg <= 0;
	end else begin
		SA_reg <= SA;
		SB_reg <= SB;
		SP_reg <= SP;
		MAI_reg <= MAI;
		MBI_reg <= MBI;
		MAF_reg <= MAF;
		MBF_reg <= MBF;
		proac_reg <= proac;
		proad_reg <= proad;
		procb_reg <= procb;
		probd_reg <= probd;
	end
end

// associate values with symbol
assign prous = (proac_reg<<width_frac) + proad_reg + procb_reg + probd_reg;
assign PROS = SP_reg? (~{1'b0, prous}+1'b1): {1'b0, prous};

endmodule

// -------------------------------------------------------
// Module Name: USWI16DIV
// Function: quotient[unsigned WI(16)]. remainder[unsigned WI(16)] = [unsigned WI(16)] / [unsigned WI(16)]
// Author: Yang Yumeng Date: 4/8 2022
// Version: v1p0
// -------------------------------------------------------
module USWI16DIV (
DIVA,
DIVB,
QUO,
REM
);

parameter WI = 16;

input [WI-1:0] DIVA;
input [WI-1:0] DIVB;
output [WI-1:0] QUO;
output [WI-1:0] REM;
// DIVA / DIVB = QUO ... REM

integer i;
reg [2*WI-1:0] tempa;
reg [2*WI-1:0] tempb;
reg [2*WI-1:0] flag;

// divition
always @(DIVA or DIVB) begin
	tempa = {{WI{1'b0}}, DIVA};
	tempb = {DIVB, {WI{1'b0}}};
	for (i=0; i<WI; i=i+1) begin
		tempa = tempa << 1'b1;
		flag = tempa - tempb;
		if (flag[2*WI-1]) tempa = tempa; // tempa < tempb
		else tempa = tempa - tempb + 1'b1; // tempa >= tempb
	end
end

assign QUO = tempa[WI-1:0];
assign REM = tempa[2*WI-1:WI];

endmodule