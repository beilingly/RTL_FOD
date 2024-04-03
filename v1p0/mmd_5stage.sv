`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: mmd_6stage
// Function: 6 stage mmd module, cover divider range 4~127
// Author: Yang Yumeng Date: 2024-4-3
// Version: v1p0
// -------------------------------------------------------
module mmd_6stage(
CKV,
DIVNUM,
CKVD
);

// inputs
input CKV;
input [6:0] DIVNUM;

// outputs
output reg CKVD; 

reg [6:0] divnum, divnum_d1;
reg  [6:0] counter;

initial begin
	divnum = 4;
	divnum_d1 = 4;
	counter = 0;
end

// dcw is retimer @ pos CKVD
always @ (posedge CKVD) begin
	divnum_d1 <= DIVNUM;
	divnum <= divnum_d1;
end

always @ (posedge CKV) begin
	if (counter >= divnum -1) begin
		counter <= 0;
	end
	else begin
		counter <= counter + 1;
	end
end

// negedge is precise alignment
always @ (posedge CKV) begin
	if (counter <= $floor(($unsigned(divnum)+0.0)/2)-1) begin
		CKVD <= 1'b1;
	end
	else begin //if (counter == DivNum -1) begin
		CKVD <= 1'b0;
	end
end // always @ (posedge clk or negedge nrst)

//----------------------------------------------------------------------------
// endmodule
//----------------------------------------------------------------------------	
endmodule