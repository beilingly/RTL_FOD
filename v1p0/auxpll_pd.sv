// -------------------------------------------------------
// Module Name: auxpll_pd
// Function: 16-divider + bbpd
// Author: Yang Yumeng Date: 3/1 2024
// Version: v1p0
// -------------------------------------------------------
module auxpll_pd(
REF250M,
CK4G,
PD
);

input REF250M;
input CK4G;
output reg PD;

reg ck2g, ck1g, ck500m, ck250m;
initial begin
    ck2g = 0;
    ck1g = 0;
    ck500m = 0;
    ck250m = 0;
end

always @ (posedge CK4G) begin
    ck2g <= ~ck2g;
end

always @ (posedge ck2g) begin
    ck1g <= ~ck1g;
end

always @ (posedge ck1g) begin
    ck500m <= ~ck500m;
end

always @ (posedge ck500m) begin
    ck250m <= ~ck250m;
end

always @ (posedge ck250m) begin
    PD <= REF250M;
end

endmodule