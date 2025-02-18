module sha256_input_tb();

    reg clk, rst_n, start;
    reg [511:0] block_in;
    reg next_stage_ready;
    wire input_valid;
    wire [511:0] block_out;
    wire ready;
    
        // Clock period definitions
    localparam CLK_PERIOD = 66.67; // 15 MHz here it is ps
    localparam MAX_CYCLES = 10; // Maximum cycles per hash as per spec

    sha256_input dut (
        .clk(clk), .rst_n(rst_n),
        .start(start),
        .block_in(block_in),
        .input_valid(input_valid),
        .block_out(block_out),
        .ready(ready),
        .next_stage_ready(next_stage_ready)
    );

    // Clock generation - 15MHz
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        // Test case
        rst_n = 0;
        start = 0;
        block_in = 0;
        next_stage_ready = 1;
        
        // Reset
        #(CLK_PERIOD*2);
        rst_n = 1;
	start = 1;
        #(CLK_PERIOD*2);
        
        // Test case 1
        block_in = {32'h61626364, {15{32'h0}}};  // "abcd" padded
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        #(CLK_PERIOD*3);
        next_stage_ready = 0;
        #(CLK_PERIOD*2);
        next_stage_ready = 1;
        #(CLK_PERIOD*2);

        // Test case 2
        block_in = {32'h12345678, {15{32'h0}}};
        wait(ready);
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        #(CLK_PERIOD*3);
        next_stage_ready = 0;
        #(CLK_PERIOD*2);
        next_stage_ready = 1;
        #(CLK_PERIOD*2);

        // Test case 3
        block_in = {16{32'hAAAAAAAA}};
        wait(ready);
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        #(CLK_PERIOD*3);
        next_stage_ready = 0;
        #(CLK_PERIOD*2);
        next_stage_ready = 1;
        #(CLK_PERIOD*2);

        // End simulation
        #(CLK_PERIOD*5);
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time=%0t rst_n=%0b start=%0b ready=%0b input_valid=%0b",
                 $time, rst_n, start, ready, input_valid);
    end
endmodule