//----------------------------------------------------------------------------
// Revision History:
//----------------------------------------------------------------------------
// 1.0  Guopei Chen  2019/06/14
//      Create the MMD module based on time_adv_enev and time_adv_odd
//		https://blog.csdn.net/moon9999/article/details/75020355
//
//----------------------------------------------------------------------------

`timescale 1s/1fs

//----------------------------------------------------------------------------
// Module definition
//----------------------------------------------------------------------------
module MMD(
NARST,
CKV,
DIVNUM,
CKVD
);

//----------------------------------------------------------------------------
// Parameter declarations
//----------------------------------------------------------------------------
reg  [6:0] counter;

//----------------------------------------------------------------------------
// IO
//----------------------------------------------------------------------------

// inputs
input CKV;
input NARST;
input [6:0] DIVNUM;

wire [6:0] divnum;

reg [6:0] divreg;

// outputs
output reg CKVD; 
// MMD logic refer to D:\seadrive_root\杨宇蒙\我的资料库\Project\BBPLL202108\汇报\杨宇蒙_BBPLL0823.pptx
always @ (negedge CKVD or negedge NARST) begin
	if (!NARST) divreg <= 32;
	else divreg <= DIVNUM;
end

assign divnum = divreg;

always @ (posedge CKV or negedge NARST) begin
	if (!NARST) begin
		counter <= 0;
	end
	else if (counter >= divnum -1) begin
		counter <= 0;
	end
	else begin
		counter <= counter + 1;
	end
end

// negedge is precise alignment
always @ (posedge CKV or negedge NARST) begin
	if (!NARST) begin
		//reset
		CKVD <= 1'b0;
	end
	else if (counter <= $floor(($unsigned(divnum)+0.0)/2)-1) begin
		CKVD <= 1'b0;
	end
	else begin //if (counter == DivNum -1) begin
		CKVD <= 1'b1;
	end
end // always @ (posedge clk or negedge nrst)

//----------------------------------------------------------------------------
// endmodule
//----------------------------------------------------------------------------	
endmodule