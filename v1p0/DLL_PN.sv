//----------------------------------------------------------------------------
// Revision History:
//----------------------------------------------------------------------------
// 1.0  Guopei Chen  2019/06/14
//      Create the V/DCO with phase noise based on DCO_W_INJ_W_BBPD_TDC_V5_dly_mis.v and DCO_PN.v
//
//----------------------------------------------------------------------------


`timescale 1s/1fs
//note that the least time_precision is 1fs
//time_unit — unit of measurement for times and delays. This specification consists of
//            one of three integers (1, 10, or 100) representing order of magnitude and one of six
//            character strings representing units of measurement:
//            {1 | 10 | 100} {s | ms | us | ns | ps | fs}
//            For example, 10 ns.
//time_precision — unit of measurement for rounding delay values before being used in
//                 simulation. Allowable values are the same as for time_unit.
`define MP_SEG_BIN 1
`define MP_SEG 2**`MP_SEG_BIN

//----------------------------------------------------------------------------
// Module definition
//----------------------------------------------------------------------------
module DLL_PN (
	// inputs
	DCTRL_C,
	DCTRL_F,
	//outputs
	MPH        // output
	);

//----------------------------------------------------------------------------
// Parameter declarations
//----------------------------------------------------------------------------
// "parameters_v1.v"
`define M_PI 3.14159265358979323846

//----------------------------------------------------------------------------
// IO
//----------------------------------------------------------------------------

//inputs
input  wire [5:0] DCTRL_C;
input  wire [6:0] DCTRL_F;
// input  real DCTRL_F;
// input  real DCTRL;

//outputs
output reg [`MP_SEG-1:0] MPH;
reg VOUT;
// output real fout;

//----------------------------------------------------------------------------
// Internal signal declarations
//----------------------------------------------------------------------------
real                    fout;
real                    delta_f;

localparam real KDCO_C		= 50e6;		    // coarse tune
localparam real KDCO_F		= 2e6;		    // fine tune
localparam real DCO_FREE	= 4e9 - KDCO_F*64.5 - KDCO_C*32;	// DCO center frequency: 4GHz
// localparam real DCO_FREE	= 1.6e9;	// DCO center frequency: 4GHz
localparam real myTo		= 1.0/DCO_FREE;		// DCO period


// // noise modeling
localparam real	WHITE_N		= -150.0;
localparam real UP_WHITE_N	= -90;
localparam real UP_WHITE_F	= 1.0e6;
localparam real UP_FLICK_N 	= -50;
localparam real UP_FLICK_F	= 100.0e3;

// phase noise modeling	
localparam real Sigma_Tpp	= myTo/(2.0*`M_PI)*sqrt(pow(10.0, WHITE_N/10.0)*DCO_FREE);		// jitter
localparam real Sigma_Tdev1	= UP_WHITE_F/DCO_FREE*sqrt(myTo)*sqrt(pow(10.0,UP_WHITE_N/10));	// wander
localparam real Sigma_Tdev2	= UP_FLICK_F/DCO_FREE*sqrt(myTo)*sqrt(2*pow(10.0,(UP_FLICK_N-5.5)/10.0));	// flicker noise
//localparam real FN_DECIM	= 25;					// frequency decimation ratio
localparam real fs = 40e6;

//----------------------------------------------------------------------------
// Internal signals
//----------------------------------------------------------------------------

real f_tmp;			// calculate the frequency value
real period;		// DCO period

// for dithering the DCO period
real	adder_out;
real	period_F;
integer period_I;
reg		FB;

integer period_dithered;
real	period_half_1;
real	period_half_2;

// for phase noise modeling
real	prev;
real 	tckv;
real 	tdev1;			// time deviation caused by oscillator wander
real	sedtdev2;		// oscillator flicker noise 
real	tdev2;			// time deviation caused by oscillator flicker noise 
integer counter;		// counter used for decimation operation
real	tpp;
real	pre_tpp;

//real 	fs;

// phase noise random number generator seeds
integer seed1;			// random seed for jitter
integer seed2;			// random seed for wander
integer seed3;			// random seed for 1/f 

// flicker noise corner frequency
real	fc1;
real	fc2;
real	fc3;
real	fc4;
real	fc5;
real	fcaa;		// anti-aliasing filter corner frequency
//real	fs;			// all the 1/f filters' sampling frequency
// 1/f (IIR) filters' feedback coefficients' magnitude
real	a1;
real	a2;
real	a3;
real	a4;
real	a5;
real	aa;
// 1/f filters' output power
real	A;				// constant sqrt(10), used for noise power calculation
real	P1;
real	P2;
real	P3;
real	P4;
real	P5;
// output of each 1/f filters
real	y1;
real	y2;
real	y3;
real	y4;
real	y5;
// previous output sample of 1/f filters
real	pre_y1;
real	pre_y2;
real	pre_y3;
real	pre_y4;
real	pre_y5;
// sum of 1/f filters, running at fs domain
real	sum_y;
real	sum_y_sig;
// anti-aliasing filter output of sum_y, running at fosc domain
real	yaa;
real	yaa_prev;
real	yaa_sig;

integer Sigma_Tpp_i;
integer Sigma_Tdev1_i;
integer Sigma_Tdev2_i;


// variables for storing output crossing points
integer fp1;

integer FN_DECIM;

// for average fout and output
reg FreqOUT_OS;
real accum_fout_os;
real pre_accum_fout_os;
integer counter_fout;
integer OSR_freq;
real average_fout;
integer fp2;
integer fp3;

//----------------------------------------------------------------------------
// code body
//----------------------------------------------------------------------------	

// jitter modeling

// jitter modeling related variables initialization
initial
begin
	// VCTRL   = 0.5;
	VOUT    = 1'b0;
    f_tmp	= DCO_FREE;
	period_dithered = myTo;
	period			= myTo;
	FB				= 1'b0;
	adder_out       = 0;
	fp1		= $fopen("output_x_pts_dco.txt");
	
	
	tckv			= 0;
	
	// random function seeds
	seed1			= 23;
	seed2			= 15;
	seed3			= 7;
	//fs				= DCO_FREE/FN_DECIM;	// 1/f filters sampling frequency
	FN_DECIM		= f_tmp/fs;
	counter			= 0;
	// 1/f filters's corner frequency
	fc1				= 1.0e2;
	fc2				= 1.0e3;
	fc3				= 1.0e4;
	fc4				= 1.0e5;
	fc5				= 1.0e6;

	// 1/f filters' IIR feedback coefficients
	a1				= 2*`M_PI*fc1/fs;
	a2				= 2*`M_PI*fc2/fs;
	a3				= 2*`M_PI*fc3/fs;
	a4				= 2*`M_PI*fc4/fs;
	a5				= 2*`M_PI*fc5/fs;
	
	// 1/f filters' output power
	A				= pow(10.0, 10.0/20.0);
	P1				= a1*pow(A,-(1-1));
	P2				= a2*pow(A,-(2-1));
	P3				= a3*pow(A,-(3-1));
	P4				= a4*pow(A,-(4-1));
	P5				= a5*pow(A,-(5-1));
	
	// output of each 1/f filters
	y1				= 0;
	y2				= 0;
	y3				= 0;
	y4				= 0;
	y5				= 0;
	
	// previous output sample of each 1/f filters
	pre_y1			= 0;
	pre_y2			= 0;
	pre_y3			= 0;
	pre_y4			= 0;
	pre_y5			= 0;
	
	// sum of all 1/f filters, running at fs domain
	sum_y			= 0;
	sum_y_sig		= 0;
	
	// anti-aliasing output of 1/f filters sum, running at fosc domain	
	fcaa			= 2.0e6;
	aa				= 2*`M_PI*fcaa/DCO_FREE;
	yaa				= 0;
	yaa_sig			= 0;
	yaa_prev		= 0;
	
	// convert deviation to integer
	Sigma_Tdev1_i = floor(Sigma_Tdev1*1e18);
	Sigma_Tdev2_i = floor(Sigma_Tdev2*1e18);
	Sigma_Tpp_i	  = floor(Sigma_Tpp*1e18);

	// fout average and output
	accum_fout_os = 0;
	counter_fout = 0;
	OSR_freq = 100;
	average_fout =0;
	fp2 = $fopen("Freq_VCO.txt");
	fp3 = $fopen("Freq_DCO_noAverage.txt");
end

initial begin
	FreqOUT_OS = 1'b0;
	forever #(1/40e9/2) FreqOUT_OS = ~ FreqOUT_OS;
end

always @(*)
begin
	delta_f = $unsigned(DCTRL_C)* KDCO_C + $unsigned(DCTRL_F)* KDCO_F;
	// delta_f = $unsigned(DCTRL_C)* KDCO_C + DCTRL_F* KDCO_F;
end

always
begin
	
		//phase noise start
		counter = counter+1;
		if (counter == FN_DECIM)		// running at fs domain 
		begin
			sedtdev2 = $dist_normal(seed3, 0, floor(Sigma_Tdev2*1e18))*1e-18;	// osc wander 
			//sedtdev2 = $dist_normal(seed3, 0, Sigma_Tdev2_i)*1e-18;	// osc wander 
		
			// calculate each 1/f filter's output
			y1 = (1-a1)*pre_y1 + P1*sedtdev2;
			y2 = (1-a2)*pre_y2 + P2*sedtdev2;
			y3 = (1-a3)*pre_y3 + P3*sedtdev2;
			y4 = (1-a4)*pre_y4 + P4*sedtdev2;
			y5 = (1-a5)*pre_y5 + P5*sedtdev2;
		
			// send current output to register for next round calculation
			pre_y1 	= y1;
			pre_y2	= y2;
			pre_y3	= y3;
			pre_y4	= y4;
			pre_y5	= y5;
		
			// sum up all 1/f filters' output
			sum_y	= (y1+y2+y3+y4+y5)/sqrt(FN_DECIM);
			sum_y_sig	= sum_y;
		
			//reset counter to 0
			counter = 0;
		end
		
		// feed the 1/f filters' sum to anti-aliasing filter
		yaa = (1-aa)*yaa_prev + aa*sum_y;
		yaa_prev = yaa;
		yaa_sig = yaa;
		tdev2 = yaa;
	
		// above code is for 1/f noise modeling
		// following code is for jitter and wander modeling
		pre_tpp = tpp;	
		
		tpp = $dist_normal(seed1, 0, floor(Sigma_Tpp*1e18))*1e-18;		// jitter
		//tpp = $dist_normal(seed1, 0, Sigma_Tpp_i)*1e-18;		// jitter
										// previous sample value
		tdev1 = $dist_normal(seed2, 0, floor(Sigma_Tdev1*1e18))*1e-18;	// wander
		//tdev1 = $dist_normal(seed2, 0, Sigma_Tdev1_i)*1e-18;	// wander
	
		// calculate period based on all the variations
		// period = 1e18*(tdev1 + 1/(f_tmp));	// the unit is as(1e-18 second)
		// period = 1e18*(1/(DCO_FREE+delta_f));	// the unit is as(1e-18 second)
		period = 1e18*(tdev1 + 1/(DCO_FREE+delta_f));	// the unit is as(1e-18 second)
		// period = 1e18*(tdev1 + tdev2 + tpp - pre_tpp + 1/(DCO_FREE+delta_f));	// the unit is as(1e-18 second)
		// period = 1e18*(tdev1 + tdev2 + 1/(DCO_FREE+delta_f));	// the unit is as(1e-18 second)
		// fout = 1/(1/(DCO_FREE+delta_f));
		fout = 1/(tdev1 + 1/(DCO_FREE+delta_f));
		// fout = 1/(tdev1 + tdev2 + tpp - pre_tpp + 1/(DCO_FREE+delta_f));
		// fout = 1/(tdev1 + tdev2 + 1/(DCO_FREE+delta_f));
		// period = 1e18*(1/(DCO_FREE+delta_f));	// the unit is as(1e-18 second)
	
		// dither DCO period for time accuracy less than 1fs, split the period into fs and as
		period_I = floor(period/1000);		 // in fs
		period_F = period - period_I*1000;	 // in as
	
		period_dithered = period_I + FB;
		period_half_1	= period_dithered/2*1e-15;	// in s
		period_half_2	= period_dithered*1e-15 - period_half_1;	// in s
	
		#(period_half_1) begin
		    VOUT = ~VOUT;
		end
		#(period_half_2) begin
		    VOUT = ~VOUT;
		end
	
		// $fstrobe(fp1,"%3.13e",$realtime);
	
/* 		#(period_half_1) begin
			Vout_p = ~Vout_p;
			Vout_n = ~Vout_n;
		end
		#(period_half_2) begin
			Vout_p = ~Vout_p;
			Vout_n = ~Vout_n;
		end 	 */

end

always @ (posedge VOUT)
begin
    adder_out = adder_out + period_F;
    if (adder_out >= 1000)
    begin
        FB = 1'b1;
        adder_out = adder_out -1000;
    end
    else
        FB = 1'b0;
end

// generate DLL multi-phases
// integer i;
// always @ (posedge VOUT) begin
// 	if (i<7) i = i+1;
// 	else i = 0;
// 	if (i<4) begin
// 		// if (i==0) #20e-12;
// 		MPH[i] = 1'b1;
// 		MPH[i+4] = 1'b0;
// 	end else begin
// 		MPH[i] = 1'b1;
// 		MPH[i-4] = 1'b0;
// 	end
// end
integer i;

initial MPH = 0;

always @ (posedge VOUT) begin
	for (i=0; i<`MP_SEG; i=i+1) begin
		if (i<`MP_SEG/2) begin
			MPH[i] = 1;
			MPH[i+`MP_SEG/2] = 0;
		end else begin
			MPH[i] = 1;
			MPH[i-`MP_SEG/2] = 0;
		end
		if (i<`MP_SEG-1) begin
			# (period_dithered/`MP_SEG*1e-15);
		end
	end
end

always @(posedge VOUT) begin
	$fstrobe(fp1,"%3.13e",$realtime);
end

always @ (posedge FreqOUT_OS) begin
	$fstrobe(fp3,"%3.13e %5.13e",$realtime,fout);
	accum_fout_os = accum_fout_os + fout;
	counter_fout = counter_fout + 1;
	if (counter_fout == (OSR_freq)) begin
		average_fout = (accum_fout_os - pre_accum_fout_os)/OSR_freq;
		pre_accum_fout_os = accum_fout_os;
		// $fstrobe(fp2,"%3.13e %5.13e %5.13e %5.13e %5.13e %5.13e",$realtime,counter_fout,accum_fout_os,fout,pre_accum_fout_os,average_fout);
		$fstrobe(fp2,"%3.13e %5.18e",$realtime,average_fout);
		counter_fout  = 0;
	end
end

//----------------------------------------------------------------------------
// Functions
//----------------------------------------------------------------------------
function  real sqrt;
    input real x;
begin
    sqrt = x ** 0.5;
end
endfunction


function  real pow;
    input real x;
    input real y;
begin
    pow = x ** y;
end
endfunction


function  integer floor;
    input real    x;
begin
    floor = $rtoi(x);
end
endfunction

//----------------------------------------------------------------------------
// endmodule
//----------------------------------------------------------------------------	
endmodule


