`timescale 1s/1fs
`define Nx 3
`define Nseg 8
// ------------------------------------------------------------
// Module Name: CALI_RLS_PSEG
// Function: piecewise DCD-RLS
// Authot: Yumeng Yang Date: 2023-11-22
// Version: v1p0
// ------------------------------------------------------------
module CALI_RLS_PSEG(
NRST,
EN,
CLK,
CALI_MODE_RLS,
X,
ERR,
PSEGS,
Y
);

input NRST;
input EN;
input CLK;
input CALI_MODE_RLS;
input real X; 
input real ERR;
input [1:0] PSEGS; // segments select 2^0, 2^1, 2^2, 2^3

output real Y; // output RLS-Distortion data

reg [`Nseg-1:0] en_seg;
real y_seg [0:`Nseg-1];
integer x_int;
real x_frac;
integer i;

always @* begin
    // split x into multiple segments
    x_int = $floor(X / (2.0**-(1.0*PSEGS)));
    x_frac = X - x_int * (2.0**-(1.0*PSEGS));

    $display("%f %f", X, X /(2.0**-(1.0*PSEGS)));

    // wake up one of the rls LUTs
    en_seg = EN? (1'b1<<x_int): 0;

    // select y output
    Y = y_seg[x_int];
end

// instances of RLS
genvar geni;
generate
    for (geni=0; geni<`Nseg; geni=geni+1) begin: genblock_rls_segs
        CALI_RLS UGEN_RLS ( .NRST(NRST), .EN(en_seg[geni]), .CLK(CLK), .CALI_MODE_RLS(CALI_MODE_RLS), .X(x_frac), .ERR(ERR), .Y(y_seg[geni]) );
    end
endgenerate

endmodule
// ------------------------------------------------------------
// Module Name: CALI_RLS
// Function: DCD-RLS
// Authot: Yumeng Yang Date: 2023-11-22
// Version: v1p0
// ------------------------------------------------------------
module CALI_RLS (
NRST,
EN,
CLK,
CALI_MODE_RLS,
X,
ERR,
Y
);

`include "veractor_operation.sv"

input NRST;
input EN;
input CLK;
input CALI_MODE_RLS;
input real X; 
input real ERR;

output real Y; // output RLS-Distortion data

// internal signal

// RLS signal
real x;
real xv [0:`Nx-1];
real xv_mat [0:`Nx*`Nx-1];
real bv [0:`Nx-1];
real b0v [0:`Nx-1], dhv [0:`Nx-1];
real hv [0:`Nx-1], hv_d1 [0:`Nx-1];
real rv0 [0:`Nx-1];
real rv [0:`Nx-1], rv_d1 [0:`Nx-1], rv_d1_shrink [0:`Nx-1];
real rv_max_pm; integer rv_max_pi;
real Rv [0:`Nx*`Nx-1], Rv_d1 [0:`Nx*`Nx-1], Rv_d1_shrink [0:`Nx*`Nx-1];
real Rvpp;
real Rvp [0:`Nx-1], Rvp_shrink [0:`Nx-1];
real yv;
real err;
real alpha;
real dhv_step;
integer m;
// LMS signal
real lms_lut [0:`Nx-1], lms_lut_d1 [0:`Nx-1];
real y_lms;
real lms_step [0:`Nx-1];
real exv [0:`Nx-1];

// parameter
parameter real lambda = 1-2.0**-2;
parameter real H = 1;
parameter integer Mb = 16;
real lms_k [0:`Nx-1];

initial begin
    lms_k[0] = 1e-3;
    lms_k[1] = 1e-1;
    lms_k[2] = 1e-2;
end

// code begin
wire rls_en, lms_en;

assign rls_en = EN & CALI_MODE_RLS;
assign lms_en = EN & (~CALI_MODE_RLS);

integer i, j;

// RLS register
always @(posedge CLK or negedge NRST) begin
    if (!NRST) begin
        // RLS initial
        for (i=0; i<`Nx; i=i+1) begin
            hv_d1[i] = 0; // set to a proper initial point
            rv_d1[i] = 0; // reset to 0
        end
        // reset to a unit matrix
        for (i=0; i<`Nx; i=i+1) begin
            for (j=0; j<`Nx; j=j+1) begin
                if (i==j) begin
                    Rv_d1[i*`Nx+j] = 1;
                end else begin
                    Rv_d1[i*`Nx+j] = 0;
                end
            end
        end
    end else if (rls_en) begin
        // update veractor
        for (i=0; i<`Nx; i=i+1) begin
            hv_d1[i] <= hv[i];
            rv_d1[i] <= rv[i];
        end
        // update matrix
        for (i=0; i<`Nx*`Nx; i=i+1) begin
            Rv_d1[i] <= Rv[i];
        end
    end
end

// LMS register
always @(posedge CLK or negedge NRST) begin
    if (!NRST) begin
        for (i=0; i<`Nx; i=i+1) begin
            lms_lut_d1[i] <= 0; // set to a proper initial point
        end
    end else if (lms_en) begin
        for (i=0; i<`Nx; i=i+1) begin
            lms_lut_d1[i] <= lms_lut[i];
        end
    end
end

always @* begin
    // get data from external
    x = X;
    xv[2] = x**2; xv[1] = x; xv[0] = 1;

    // initial combination register
    err = 0;
    Y = 0;
    yv = 0;
    alpha = 0;
    m = 0;
    rv_max_pi = 0;
    rv_max_pm = 0;
    Rvpp = 0;
    dhv_step = 0;
    for (i=0; i<`Nx; i=i+1) begin
        Rv_d1_shrink[i] = 0;
        bv[i] = 0;
        rv_d1_shrink[i] = 0;
        b0v[i] = 0;
        rv0[i] = 0;
        dhv[i] = 0;
        Rvp[i] = 0;
        Rvp_shrink[i] = 0;
        rv[i] = 0;
        hv[i] = 0;
    end
    for (i=0; i<`Nx*`Nx; i=i+1) begin
        xv_mat[i] = 0;
        Rv[i] = 0;
    end
    // initial lsm register
    y_lms = 0;
    for (i=0; i<`Nx; i=i+1) begin
        exv[i] = 0;
        lms_step[i] = 0;
        lms_lut[i] = 0;
    end


    if (CALI_MODE_RLS) begin
        // RLS mode
        // Rn = lambda * Rn_d1 + xn * xn'
        veractor_pro_x_xt(rls_en, xv, xv_mat);
        mat_pro_x_mat(rls_en, lambda, Rv_d1, Rv_d1_shrink);
        mat_sum_m1_m2(rls_en, Rv_d1_shrink, xv_mat, Rv);

        // calculate distortion output
        // yn = hn_d1' * xn
        veractor_pro_xt_y(rls_en, hv_d1, xv, yv);
        Y = yv;

        // get error data from external
        // b0n = lambda * rn_d1 + en * xn
        err = rls_en? ERR: 0;
        veractor_pro_a_x(rls_en, err, xv, bv);
        veractor_pro_a_x(rls_en, lambda, rv_d1, rv_d1_shrink);
        veractor_sum_x1_x2(rls_en, rv_d1_shrink, bv, b0v);

        // DCD
        // Rn*dhn = b0n -> dhn, rn
        for (i=0; i<`Nx; i=i+1) begin
            rv0[i] = b0v[i];
        end
        alpha = H/2;
        m = 1;
        for (i=0; i<`Nx; i=i+1) begin
            dhv[i] = 0;
        end
        
        veractor_absmax_x(rls_en, rv0, rv_max_pi, rv_max_pm);

        // find: Rvpp < rv_max_pm <= 2*Rvpp
        Rvpp = Rv[rv_max_pi*`Nx+rv_max_pi];
        for (i=1; i<=Mb; i=i+1) begin
            if (rv_max_pm <= (alpha/2)*Rvpp) begin
                m = m + 1;
                alpha = alpha/2;
                if (m > Mb) begin
                    alpha = 0;
                end
            end
        end

        // update dhn and rn
        // find Rn[:,p]
        for (i=0; i<`Nx; i=i+1) begin
            Rvp[i] = Rv[i*`Nx + rv_max_pi];
        end
        // dhn_p = dhn_p + sign(rn_p) * alpha
        // rn = rn - sign(rn_p) * alpha * Rnp
        dhv_step = sign(rv0[rv_max_pi]) * alpha;
        dhv[rv_max_pi] = dhv[rv_max_pi] + dhv_step;
        veractor_pro_a_x(rls_en, -dhv_step, Rvp, Rvp_shrink);
        veractor_sum_x1_x2(rls_en, rv0, Rvp_shrink, rv);

        // update hn
        // hv = hv_d1 + dhv
        veractor_sum_x1_x2(rls_en, hv_d1, dhv, hv);
    end else begin
        // LMS mode
        // calculate distortion output
        veractor_pro_xt_y(lms_en, lms_lut_d1, xv, y_lms);
        Y = y_lms;

        // get error
        err = lms_en? ERR: 0;

        // update lut
        veractor_pro_a_x(lms_en, err, xv, exv);
        for (i=0; i<`Nx; i=i+1) begin
            lms_step[i] = exv[i] * lms_k[i];
        end
        veractor_sum_x1_x2(lms_en, lms_lut_d1, lms_step, lms_lut);
    end
end

endmodule

// ------------------------------------------------------------
// Module Name: CALI_RLS_TB
// Function: a test bentch for DCD-RLS
// Authot: Yumeng Yang Date: 2023-11-22
// Version: v1p0
// ------------------------------------------------------------
module CALI_RLS_TB;

reg CLK;
reg NRST;
reg EN;
real x;
real err;
real yv;

parameter real fclk = 10e9;

initial begin
    CLK = 0;
    NRST = 0;
    #1e-9;
    NRST = 1;
    forever begin
        #(1/fclk/2);
        CLK = ~CLK;
    end
end

initial begin
    EN = 1;
    // #10e-9;
    // EN = 0;
    // #5e-9;
    // EN = 1;
end

always @(posedge CLK) begin
    x <= $random * (2.0**-32) + 0.5; // Urand[0,1]
end

always @* begin
    err = x - (yv + 0.01*yv*(1-yv));
end

// CALI_RLS U0_CALI_RLS ( .NRST(NRST), .EN(EN), .CLK(CLK), .X(x), .ERR(err), .Y(yv) );
CALI_RLS_PSEG U0_CALI_RLS_PSEG ( .NRST(NRST), .EN(EN), .CLK(CLK), .CALI_MODE_RLS(1'b0), .X(x), .ERR(err), .PSEGS(2'd3), .Y(yv) );

endmodule