module tb();

	logic               clk, rst;
	logic signed [ 7:0] a, b, c, d;
	logic               input_vld;
	logic signed [23:0] res;
	logic               res_overflow, output_vld;

	formula formula_dut (
		.clk          (clk),
		.rst          (rst),
		.a            (a),
		.b            (b),
		.c            (c),
		.d            (d),
		.input_vld    (input_vld),
		.res          (res),
		.res_overflow (res_overflow),
		.output_vld   (output_vld)
	);
	
	typedef struct {
		logic signed [7:0] a;
		logic signed [7:0] b;
		logic signed [7:0] c;
		logic signed [7:0] d;
	} packet;
	
	mailbox#(packet) monitor = new();
	
	initial begin
		void'($urandom(42));
	end
	
	initial begin
		clk = 1'b0;
		
		forever #5 clk = ~clk;
	end
	
	initial begin
		rst = 1'b1;
		
		#10 rst = 1'b0;
	end
	
	initial begin
		packet pkt;
		
		input_vld = 1'b0;
		a = 'z;
		b = 'z;
		c = 'z;
		d = 'z;
		@(negedge rst);
		@(posedge clk);
		
		repeat(30) begin
			input_vld = $urandom_range(0, 1);
			
			if (input_vld) begin
				a = $urandom();
				b = $urandom();
				c = $urandom();
				d = $urandom();
				
				pkt.a = a;
				pkt.b = b;
				pkt.c = c;
				pkt.d = d;
				monitor.put(pkt);
			end
			else begin
				a = 'z;
				b = 'z;
				c = 'z;
				d = 'z;
			end
			
			@(posedge clk);
		end
		
		repeat (6) @(posedge clk);
		$finish;
	end
	
	initial begin
		packet pkt;
		int expected;
	
		forever begin
			@(posedge clk);
			if (output_vld) begin
				monitor.get(pkt);
				expected = (((pkt.a - pkt.b) * (1 + 3 * pkt.c)) - 4 * pkt.d) / 2;
				if (res !== expected && ~res_overflow) $error("%0t BAD RESULT. %d - %d", $time(), res, expected);
				if (res_overflow) $info("%0t OVERFLOW DETECTED", $time());
			end
		end
	end

endmodule