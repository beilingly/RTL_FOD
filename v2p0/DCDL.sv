`timescale 1s/1fs

module DCDL (
CKIN,
CKOUT,
DCW
);

input CKIN;
input [11:0] DCW;
output CKOUT;

parameter real t_res = 100e-15;
parameter real t_ofst = 0;
real t_delta;
reg ck_delay;
reg [11:0] DCW_sync;

// sync DCW with CKIN neg
always @ (negedge CKIN) begin
	DCW_sync <= DCW;
end

assign t_delta = t_ofst + $unsigned(DCW_sync) * t_res;

always @* begin
	ck_delay <= #(t_delta) CKIN;
end

// delay posedge
assign CKOUT = ck_delay;

endmodule