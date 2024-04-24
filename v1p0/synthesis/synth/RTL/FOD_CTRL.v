`define WI 6
`define WI_DLF 7
`define WF 16
`define WF_DLF 26
`define OTWC_L 6
`define OTWF_L 7

// -------------------------------------------------------
// Module Name: FOD_CTRL
// Function: FOD digital ctrl, main dig + aux dig
// Author: Yang Yumeng Date: 4/17 2023
// Version: v1p0
// -------------------------------------------------------
module FOD_CTRL(
// rst clk w
NARST,
REFMOD1, REFMOD2,
CONFIGWIN,

// analog input
PDE1, PDE2,

// SPI input
SPI_FCW1, SPI_FCW2,
SPI_MMD_EN, SPI_DTC_EN, SPI_GAC_EN, SPI_DSM_EN, SPI_DN_EN, SPI_IIR1EN, SPI_IIR2EN, SPI_DSM1STEN, SPI_DLFEN,
SPI_MMD_SOR, SPI_DTC_SOR, SPI_OTWF_SOR,
SPI_MMDDCW_P, SPI_MMDDCW_S, SPI_DTCDCW, 
SPI_OTW_C, SPI_OTW_F,
SPI_CALIORDER, SPI_PSEC, SPI_DN_WEIGHT, SPI_DSM_MODE, SPI_DN_MODE, SPI_KDTCA_INIT, SPI_KDTCB_INIT, SPI_KDTCC_INIT, SPI_KA, SPI_KB, SPI_KC, SPI_KPS, SPI_KIS, SPI_KIIR1S, SPI_KIIR2S,
SPI_SECSEL_TEST, SPI_REGSEL_TEST,
// SPI input aux dig
SPI_PHASEC_EN, SPI_PHASE_DN_EN, SPI_KPHASE,
SPI_KA_AUX, SPI_KB_AUX, SPI_KC_AUX,

// output
O_MMDDCW_P1, O_MMDDCW_S1, O_DTCDCW1, 
// O_DTCDCW_MSB1, O_DTCDCW_LSB1,
O_MMDDCW_P2, O_MMDDCW_S2, O_DTCDCW2, 
// O_DTCDCW_MSB2, O_DTCDCW_LSB2,
O_OTW_C, O_OTW_F,
KDTC_TEST1, KDTC_TEST2
);

// rst
input NARST;

// CLK
input REFMOD1;
input REFMOD2;
input CONFIGWIN;

// analog input
input PDE1;
input PDE2;

// SPI input 
input [6+16-1:0] SPI_FCW1;
input [6+16-1:0] SPI_FCW2;
input SPI_MMD_EN;
input SPI_DTC_EN;
input SPI_GAC_EN;
input SPI_DSM_EN;
input SPI_DN_EN;
input SPI_IIR1EN;
input SPI_IIR2EN;
input SPI_DSM1STEN;
input SPI_DLFEN;
input SPI_MMD_SOR;
input SPI_DTC_SOR;
input SPI_OTWF_SOR;
input [6:0] SPI_MMDDCW_P;
input SPI_MMDDCW_S;
input [11:0] SPI_DTCDCW;
input [6-1:0] SPI_OTW_C;
input [7-1:0] SPI_OTW_F;
input [2:0] SPI_CALIORDER;
input [2:0] SPI_PSEC;
input [4:0] SPI_DN_WEIGHT;
input [1:0] SPI_DSM_MODE;
input [1:0] SPI_DN_MODE;
input [12:0] SPI_KDTCA_INIT;
input [12:0] SPI_KDTCB_INIT;
input [12:0] SPI_KDTCC_INIT;
input [4:0] SPI_KA;
input [4:0] SPI_KB;
input [4:0] SPI_KC;
input [5:0] SPI_KPS;
input [5:0] SPI_KIS;
input [5:0] SPI_KIIR1S;
input [5:0] SPI_KIIR2S;
input [1:0] SPI_SECSEL_TEST;
input [3:0] SPI_REGSEL_TEST;
// SPI input aux dig
input SPI_PHASEC_EN;
input SPI_PHASE_DN_EN;
input [4:0] SPI_KPHASE;
input [4:0] SPI_KA_AUX;
input [4:0] SPI_KB_AUX;
input [4:0] SPI_KC_AUX;

// output 
output [6:0] O_MMDDCW_P1;
output [6:0] O_MMDDCW_P2;
output O_MMDDCW_S1;
output O_MMDDCW_S2;
output [11:0] O_DTCDCW1;
output [11:0] O_DTCDCW2;
// output [63:0] O_DTCDCW_MSB1;
// output [63:0] O_DTCDCW_MSB2;
// output [5:0] O_DTCDCW_LSB1;
// output [5:0] O_DTCDCW_LSB2;
output [6-1:0] O_OTW_C;
output [7-1:0] O_OTW_F;
output [13-1:0] KDTC_TEST1;
output [13-1:0] KDTC_TEST2;



//***************************** Main Dig (FOD Cali+ADPLL) *****************************
MAINDIG U1_MAINDIG (
// rst clk w
.NARST 			(NARST),
.CKVD			(REFMOD1),
.CONFIGWIN 		(CONFIGWIN),
// analog input
.PDE			(PDE1),
// SPI input
.SPI_FCW		(SPI_FCW1),
.SPI_MMD_EN     (SPI_MMD_EN), 
.SPI_DTC_EN     (SPI_DTC_EN), 
.SPI_GAC_EN     (SPI_GAC_EN), 
.SPI_DSM_EN     (SPI_DSM_EN), 
.SPI_DN_EN      (SPI_DN_EN), 
.SPI_IIR1EN     (SPI_IIR1EN), 
.SPI_IIR2EN     (SPI_IIR2EN), 
.SPI_DSM1STEN   (SPI_DSM1STEN), 
.SPI_DLFEN      (SPI_DLFEN),
.SPI_MMD_SOR    (SPI_MMD_SOR), 
.SPI_DTC_SOR    (SPI_DTC_SOR), 
.SPI_OTWF_SOR   (SPI_OTWF_SOR),
.SPI_MMDDCW_P   (SPI_MMDDCW_P), 
.SPI_MMDDCW_S   (SPI_MMDDCW_S), 
.SPI_DTCDCW     (SPI_DTCDCW), 
.SPI_OTW_C      (SPI_OTW_C), 
.SPI_OTW_F      (SPI_OTW_F),
.SPI_CALIORDER  (SPI_CALIORDER), 
.SPI_PSEC       (SPI_PSEC), 
.SPI_DN_WEIGHT  (SPI_DN_WEIGHT), 
.SPI_DSM_MODE   (SPI_DSM_MODE), 
.SPI_DN_MODE    (SPI_DN_MODE), 
.SPI_KDTCA_INIT (SPI_KDTCA_INIT), 
.SPI_KDTCB_INIT (SPI_KDTCB_INIT), 
.SPI_KDTCC_INIT (SPI_KDTCC_INIT), 
.SPI_KA         (SPI_KA), 
.SPI_KB         (SPI_KB), 
.SPI_KC         (SPI_KC), 
.SPI_KPS        (SPI_KPS), 
.SPI_KIS        (SPI_KIS), 
.SPI_KIIR1S     (SPI_KIIR1S), 
.SPI_KIIR2S     (SPI_KIIR2S),
.SPI_SECSEL_TEST(SPI_SECSEL_TEST), 
.SPI_REGSEL_TEST(SPI_REGSEL_TEST),
// output
.O_MMDDCW_P 	(O_MMDDCW_P1),
.O_MMDDCW_S     (O_MMDDCW_S1),
.O_DTCDCW		(O_DTCDCW1),
// .O_DTCDCW_MSB   (O_DTCDCW_MSB1), 
// .O_DTCDCW_LSB   (O_DTCDCW_LSB1),
.O_OTW_C        (O_OTW_C), 
.O_OTW_F        (O_OTW_F),
.KDTC_TEST      (KDTC_TEST1)
);

//***************************** Aux Dig2 (FOD Cali) *****************************
AUXDIG U2_AUXDIG (
// rst clk w
.NARST 			(NARST),
.CKVD			(REFMOD2),
.CONFIGWIN 		(CONFIGWIN),
// analog input
.PDE			(PDE2),
// SPI input
.SPI_FCW		(SPI_FCW2),
.SPI_FCW_REF	(SPI_FCW1),
.SPI_MMD_EN     (SPI_MMD_EN), 
.SPI_DTC_EN     (SPI_DTC_EN), 
.SPI_GAC_EN     (SPI_GAC_EN), 
.SPI_DSM_EN     (SPI_DSM_EN), 
.SPI_DN_EN      (SPI_DN_EN), 
.SPI_MMD_SOR    (SPI_MMD_SOR), 
.SPI_DTC_SOR    (SPI_DTC_SOR), 
.SPI_MMDDCW_P   (SPI_MMDDCW_P), 
.SPI_MMDDCW_S   (SPI_MMDDCW_S), 
.SPI_DTCDCW     (SPI_DTCDCW), 
.SPI_CALIORDER  (SPI_CALIORDER), 
.SPI_PSEC       (SPI_PSEC), 
.SPI_DN_WEIGHT  (SPI_DN_WEIGHT), 
.SPI_DSM_MODE   (SPI_DSM_MODE), 
.SPI_DN_MODE    (SPI_DN_MODE), 
.SPI_KDTCA_INIT (SPI_KDTCA_INIT), 
.SPI_KDTCB_INIT (SPI_KDTCB_INIT), 
.SPI_KDTCC_INIT (SPI_KDTCC_INIT), 
.SPI_SECSEL_TEST(SPI_SECSEL_TEST), 
.SPI_REGSEL_TEST(SPI_REGSEL_TEST),
.SPI_PHASEC_EN	(SPI_PHASEC_EN),
.SPI_PHASE_DN_EN(SPI_PHASE_DN_EN),
.SPI_KPHASE		(SPI_KPHASE),
.SPI_KA			(SPI_KA_AUX),
.SPI_KB			(SPI_KB_AUX),
.SPI_KC			(SPI_KC_AUX),

// output
.O_MMDDCW_P 	(O_MMDDCW_P2),
.O_MMDDCW_S     (O_MMDDCW_S2),
.O_DTCDCW		(O_DTCDCW2),
// .O_DTCDCW_MSB   (O_DTCDCW_MSB2), 
// .O_DTCDCW_LSB   (O_DTCDCW_LSB2),
.KDTC_TEST      (KDTC_TEST2)
);

endmodule