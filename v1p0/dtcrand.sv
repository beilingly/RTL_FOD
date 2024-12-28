`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: dtcrand
// Function: dtc range 32ps, resolution 1ps
// Author: Yang Yumeng Date: 3/8 2024
// Version: v1p0
// -------------------------------------------------------
module dtcrand (
CKIN,
CKOUT
);

input CKIN;
output CKOUT;

parameter real t_res = 125e-12/64 * 1;
parameter real t_ofst = 0;
real t_delta;
reg ck_delay;

reg [5:0] rand6bit;
real delay_nonlinear;

always @(posedge CKIN) begin
	rand6bit = {$random} %64;
	delay_nonlinear = 0 * $sin(1.0*rand6bit/64 * 3.14) * t_res;
end

assign t_delta = t_ofst + $unsigned(rand6bit) * t_res + delay_nonlinear;

always @* begin
	ck_delay <= #(t_delta) CKIN;
end

// delay posedge
assign CKOUT = ck_delay & CKIN;
// assign CKOUT = CKIN;

endmodule