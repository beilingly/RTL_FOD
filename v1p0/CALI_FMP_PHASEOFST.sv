`define WI 6
`define WF 16
`define WF_PHASE 24
`define MP_SEG_BIN 1
`define MP_SEG 2**`MP_SEG_BIN

// ------------------------------------------------------------
// Module Name: CALI_FMP_PHASEOFST
// Function: calibrate multi-phases offset in auxpll 
// Authot: Yumeng Yang Date: 2024-3-1
// Version: v1p0
// ------------------------------------------------------------
module CALI_FMP_PHASEOFST(
// input
NRST,
CLK,
EN,
PHE_MEASURE,
DPHASE_SEG_ARR
);

input NRST;
input CLK;
input EN; // cali en
input [`MP_SEG_BIN-1:0] PHE_MEASURE; // 0~31

output reg [`MP_SEG*`WF_PHASE-1:0] DPHASE_SEG_ARR; // dphase define array

// internal signal
reg [`WF_PHASE-1:0] dphase_seg [`MP_SEG-1:0];
reg [9:0] cntwin; // count window is 1024 CLK periods
reg [9:0] cnt [`MP_SEG-1:0], cnt_reg [`MP_SEG-1:0], cnt_reg_accum [`MP_SEG-1:0], cnt_reg_accum_iir [`MP_SEG-1:0];
integer i, j;

// counter window
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<`MP_SEG; i=i+1) begin
			cnt[i] <= 0;
			cnt_reg[i] <= 0;
		end
		cntwin <= 0;
	end else if (EN) begin
		// cnt window
		if (cntwin == ((1'b1<<10) - 1'b1)) begin
			cntwin <= 0;
		end else begin
			cntwin <= cntwin + 1;
		end
		// assert each dphase segments
		if (cntwin == 0) begin
			for (i=0; i<`MP_SEG; i=i+1) begin
				cnt[i] <= 0;
				cnt_reg[i] <= cnt[i];
			end
		end else begin
			cnt[PHE_MEASURE] <= cnt[PHE_MEASURE] + 1;
		end
	end
end

// accumulate cnt_reg
always @* begin
	for (i=0; i<`MP_SEG; i=i+1) begin
		cnt_reg_accum[i] = 0;
		for (j=0; j<=i; j=j+1) begin
			cnt_reg_accum[i] = cnt_reg_accum[i] + cnt_reg[j];
			// if (j < i) begin
			// 	cnt_reg_accum[i] = cnt_reg_accum[i] + cnt_reg[j];
			// end else begin
			// 	cnt_reg_accum[i] = cnt_reg_accum[i] + (cnt_reg[j] >> 1);
			// end
		end
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<`MP_SEG; i=i+1) begin
			cnt_reg_accum_iir[i] <= (i+1) << (10-`MP_SEG_BIN);
		end
	end else if (EN) begin
		if (cntwin == 0) begin
			for (i=0; i<`MP_SEG; i=i+1) begin
				cnt_reg_accum_iir[i] <= cnt_reg_accum_iir[i] - (cnt_reg_accum_iir[i]>>4) + (cnt_reg_accum[i]>>4);
				// cnt_reg_accum_iir[i] <= cnt_reg_accum[i];
			end
		end
	end
end

// dphase segments define
always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		for (i=0; i<`MP_SEG; i=i+1) begin
			DPHASE_SEG_ARR[(i+1)*`WF_PHASE-1-:`WF_PHASE] <= (i+1) << (`WF_PHASE-`MP_SEG_BIN);
		end

	end else if (EN) begin
		if (cntwin == 0) begin
			for (i=0; i<`MP_SEG; i=i+1) begin
				DPHASE_SEG_ARR[(i+1)*`WF_PHASE-1-:`WF_PHASE] <= cnt_reg_accum_iir[i] << (`WF_PHASE-10);
			end
		end
	end
end

endmodule