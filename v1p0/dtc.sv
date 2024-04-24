`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: dtc
// Function: dtc range 80ps, resolution 160fs
// Author: Yang Yumeng Date: 9/10 2023
// Version: v1p0
// -------------------------------------------------------
module dtc (
CKIN,
CKOUT,
DCW
);

input CKIN;
input [9:0] DCW;
output CKOUT;

parameter real t_res = 60e-15;
parameter real t_ofst = 0;
real t_delta;
reg ck_delay;
reg [9:0] DCW_sync;

// sync DCW with CKIN neg
always @ (negedge CKIN) begin
	DCW_sync <= DCW;
end

// assign t_delta = t_ofst + $unsigned(DCW_sync) * t_res;
// 10 LSB INL
assign t_delta = t_ofst + $unsigned(DCW_sync) * t_res + 10 * $sin(1.0*$unsigned(DCW_sync)/1024 * 3.14) * t_res;

always @* begin
	ck_delay <= #(t_delta) CKIN;
end

// delay posedge
assign CKOUT = ck_delay & CKIN;

endmodule