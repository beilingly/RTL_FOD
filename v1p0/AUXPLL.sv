`timescale 1s/1fs

`define MP_SEG_BIN 3
`define MP_SEG 2**`MP_SEG_BIN

// ------------------------------------------------------------
// Module Name: AUXPLL
// Function: outputs 4G clocks in interleave 8 phases
// Authot: Yumeng Yang Date: 9/10 2023
// Version: v1p0
// ------------------------------------------------------------

module AUXPLL (
fin,
fcw_pll_aux,
FMP
);

// io defination
input real fin;
input real fcw_pll_aux;
output reg [`MP_SEG-1:0] FMP;

real freq_pll_aux;

real rnd_std;
real trnd [`MP_SEG-1:0];
integer rnd_seed [`MP_SEG-1:0];
integer i;
integer delay_as [`MP_SEG-1:0], delay_remain;
real delay_s [`MP_SEG-1:0];

// pll rtl
initial begin
    FMP = 0;
    freq_pll_aux = fin * fcw_pll_aux;
    for (i=0; i<`MP_SEG; i=i+1) begin
        rnd_seed[i] = i;
    end
    rnd_std = 1/freq_pll_aux/`MP_SEG * 0.01;

    delay_remain = 1/freq_pll_aux * 1e15; // fs
    for (i=0; i<`MP_SEG-1; i=i+1) begin
        delay_as[i] = 1/freq_pll_aux/`MP_SEG * 1e15; // fs
        delay_remain = delay_remain - delay_as[i];
    end
    delay_as[`MP_SEG-1] = delay_remain;
    for (i=0; i<`MP_SEG; i=i+1) begin
        delay_s[i] = delay_as[i] * 1e-15; // s
    end

    forever begin

        // for (i=0; i<`MP_SEG; i=i+1) begin
        //     trnd[i] = $dist_normal(rnd_seed[i], 0, $rtoi(rnd_std*1e18))*1e-18;
        // end

        for (i=0; i<`MP_SEG; i=i+1) begin
            trnd[i] = 0;
        end
        trnd[0] = 1/freq_pll_aux/64 * 0;
        trnd[1] = -1/freq_pll_aux/64 * 0;

        for (i=0; i<`MP_SEG; i=i+1) begin
            if (i<`MP_SEG/2) begin
                #(delay_s[i] + trnd[i]);
                FMP[i] = 1;
                FMP[i+`MP_SEG/2] = 0;
            end else begin
                #(delay_s[i] + trnd[i]);
                FMP[i] = 1;
                FMP[i-`MP_SEG/2] = 0;
            end
        end
    end



end

endmodule