module formula # (
	parameter LEN = 8
) (
	input                         clk,
	input                         rst,
	input  signed [    LEN - 1:0] a,
	input  signed [    LEN - 1:0] b,
	input  signed [    LEN - 1:0] c,
	input  signed [    LEN - 1:0] d,
	input                         input_vld,
	output signed [3 * LEN - 1:0] res,
	output                        res_overflow,
	output                        output_vld
);

	localparam logic [2 * LEN - 1:0] CONST1 = 1;
	localparam logic [3 * LEN - 1:0] CONST2 = 2;
	localparam logic [    LEN - 1:0] CONST3 = 3;
	localparam logic [    LEN - 1:0] CONST4 = 4;

	logic signed [    LEN    :0] sub_st1;            // a - b
	logic signed [2 * LEN - 1:0] mul1_st1, mul2_st1; // 3*c, 4*d
	logic signed [2 * LEN    :0] sum_st2;            // 1 + 3*c
	logic signed [3 * LEN - 1:0] mul2_st3;           // (a - b)*(1 + 3*c)
   logic signed [3 * LEN    :0] sub_st4;            // (a - b)*(1 + 3*c) - 4*d
	logic signed [3 * LEN - 1:0] div_st5;            // ((a - b)*(1 + 3*c) - 4*d)/2

	logic signed [    LEN - 1:0] sub_st1_reg;
	logic signed [2 * LEN - 1:0] mul1_st1_reg, mul2_st1_reg;
	logic signed [    LEN - 1:0] sub_st2_reg;
	logic signed [2 * LEN - 1:0] mul_st2_reg, sum_st2_reg;  
	logic signed [2 * LEN - 1:0] mul1_st3_reg;
	logic signed [3 * LEN - 1:0] mul2_st3_reg;               
	logic signed [3 * LEN - 1:0] sub_st4_reg;                              
	logic signed [3 * LEN - 1:0] div_st5_reg;   

	logic                    vld_st1, vld_st2, vld_st3, vld_st4, vld_st5;
	logic                    overflow_st1, overflow_st2, overflow_st3, overflow_st4, overflow_st5;	
			
	// VALID LOGIC
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			vld_st1 <= '0;
			vld_st2 <= '0;
			vld_st3 <= '0;
			vld_st4 <= '0;
			vld_st5 <= '0;
		end
		else begin
			vld_st1 <= input_vld;
			vld_st2 <= vld_st1;
			vld_st3 <= vld_st2;
			vld_st4 <= vld_st3;
			vld_st5 <= vld_st4;
		end
	
	// STAGE 1 CALCULATIONS	
	assign sub_st1  = $signed(a) - $signed(b);
	assign mul1_st1 = $signed(CONST3) * $signed(c);
	assign mul2_st1 = $signed(CONST4) * $signed(d);
		
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			sub_st1_reg  <= '0;
			mul1_st1_reg <= '0;
			mul2_st1_reg <= '0;
		end
		else if (input_vld) begin
			sub_st1_reg  <= sub_st1[LEN - 1:0];
			mul1_st1_reg <= mul1_st1;
			mul2_st1_reg <= mul2_st1;
		end
		
	// STAGE 1 OVERFLOW
	always_ff @ (posedge clk or posedge rst)
		if (rst)
			overflow_st1 <= '0;
		else if (input_vld)
			overflow_st1 <= (sub_st1[LEN] ^ sub_st1[LEN - 1]    )  ||
								 (c[LEN - 1]   ^ mul1_st1[2 * LEN - 1]) ||
								 (d[LEN - 1]   ^ mul2_st1[2 * LEN - 1]);

	// STAGE 2 CALCULATIONS
	assign sum_st2 = CONST1 + $signed(mul1_st1_reg);
		
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			sub_st2_reg <= '0;
			mul_st2_reg <= '0;
			sum_st2_reg <= '0;
		end
		else if (vld_st1 && ~overflow_st1) begin
			sub_st2_reg <= sub_st1_reg;
			mul_st2_reg <= mul2_st1_reg;
			sum_st2_reg <= sum_st2[2 * LEN - 1:0];
		end
		
	// STAGE 2 OVERFLOW
	always_ff @ (posedge clk or posedge rst)
		if (rst)
			overflow_st2 <= '0;
		else if (vld_st1)
			overflow_st2 <= overflow_st1 || 
								 (sum_st2[2 * LEN] ^ sum_st2[2 * LEN - 1]);
		
	// STAGE 3 CALCULATIONS
	assign mul2_st3 = $signed(sub_st2_reg) * $signed(sum_st2_reg);
	
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			mul1_st3_reg <= '0;
			mul2_st3_reg <= '0;
		end
		else if (vld_st2 && ~overflow_st2) begin
			mul1_st3_reg <= mul_st2_reg;
			mul2_st3_reg <= mul2_st3;
		end
		
	// STAGE 3 OVERFLOW
	always_ff @ (posedge clk or posedge rst)
		if (rst)
			overflow_st3 <= '0;
		else if (vld_st2)
			overflow_st3 <= overflow_st2 || 
								 ((sub_st2_reg[LEN - 1] == sum_st2_reg[2 * LEN - 1]) && (mul2_st3[3 * LEN - 1] ^ sub_st2_reg[LEN - 1]));
		
	// STAGE 4 CALCULATIONS
	assign sub_st4 = $signed(mul2_st3_reg) - $signed(mul1_st3_reg);
	
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			sub_st4_reg <= '0;
		end
		else if (vld_st3 && ~overflow_st3) begin
			sub_st4_reg <= sub_st4[3 * LEN - 1:0];
		end
		
	// STAGE 4 OVERFLOW
	always_ff @ (posedge clk or posedge rst)
		if (rst)
			overflow_st4 <= '0;
		else if (vld_st3)
			overflow_st4 <= overflow_st3 ||
								 (sub_st4[3 * LEN] ^ sub_st4[3 * LEN - 1]);
		
	// STAGE 5 CALCULATIONS
	assign div_st5 = $signed(sub_st4_reg) / $signed(CONST2);
	
	always_ff @ (posedge clk or posedge rst)
		if (rst) begin
			div_st5_reg <= '0;
		end
		else if (vld_st4 && ~overflow_st4) begin
			div_st5_reg <= div_st5;
		end
		
	// STAGE 5 OVERFLOW
	always_ff @ (posedge clk or posedge rst)
		if (rst)
			overflow_st5 <= '0;
		else if (vld_st4)
			overflow_st5 <= overflow_st4;
					
	// OUTPUTS				
	assign output_vld   = vld_st5;
	assign res          = div_st5_reg;
	assign res_overflow = overflow_st5;

endmodule
	