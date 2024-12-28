`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: mmd_5stage
// Function: 5 stage mmd module, cover divider range 4~63
// Author: Yang Yumeng Date: 9/10 2023
// Version: v1p0
// -------------------------------------------------------
module mmd_5stage(
CKV,
DIVNUM,
CKVD
);

// inputs
input CKV;
input [5:0] DIVNUM;

// outputs
output reg CKVD; 

reg [5:0] divnum;
reg  [5:0] counter;

initial begin
	divnum = 4;
	counter = 0;
end

// dcw is retimer @ pos CKVD
always @ (posedge CKVD) begin
	divnum <= DIVNUM;
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