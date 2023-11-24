`timescale 1s/1fs

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
output reg [7:0] FMP;

real freq_pll_aux;

// pll rtl
initial begin
    FMP = 0;
    freq_pll_aux = fin * fcw_pll_aux;
    forever begin
        #(1/freq_pll_aux/8);
        FMP[0] = 1;
        FMP[4] = 0;
        #(1/freq_pll_aux/8);
        FMP[1] = 1;
        FMP[5] = 0;
        #(1/freq_pll_aux/8);
        FMP[2] = 1;
        FMP[6] = 0;
        #(1/freq_pll_aux/8);
        FMP[3] = 1;
        FMP[7] = 0;
        #(1/freq_pll_aux/8);
        FMP[4] = 1;
        FMP[0] = 0;
        #(1/freq_pll_aux/8);
        FMP[5] = 1;
        FMP[1] = 0;
        #(1/freq_pll_aux/8);
        FMP[6] = 1;
        FMP[2] = 0;
        #(1/freq_pll_aux/8);
        FMP[7] = 1;
        FMP[3] = 0;
    end
end

endmodule