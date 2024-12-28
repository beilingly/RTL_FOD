`timescale 1s/1fs

// -------------------------------------------------------
// Module Name: retimer_pos_neg
// Function: use pos or neg to retimer
// Author: Yang Yumeng Date: 9/10 2023
// Version: v1p0
// -------------------------------------------------------
module retimer_pos_neg (
D,
CK,
POLARITY,
OUT
);

input D;
input CK;
input POLARITY;
output OUT;

reg D_pos;
reg D_neg;
reg POLARITY_sync;

always @ (posedge CK) begin
    D_pos <= D; // delay for 1 CK cycle
end

always @ (negedge CK) begin
    D_neg <= D; // delay for 0.5 CK cycle
end

// sync POLARITY with D neg
always @ (negedge D) begin
    POLARITY_sync <= POLARITY;
end

// assign OUT = POLARITY_sync? D_pos: D_neg;
assign #(5e-12) OUT = POLARITY_sync? D_neg: D;

endmodule