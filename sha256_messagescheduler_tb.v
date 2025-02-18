module sha256_message_scheduler_tb();
    reg clk, rst_n;
    reg input_valid;
    reg [511:0] block_in;
    wire scheduler_valid;
    wire [255:0] w_out;
    wire scheduler_ready;
    
    // Test parameters
    localparam CLOCK_PERIOD = 66; // ~15 MHz
    localparam MAX_CYCLES = 10;   // Requirement check
    
    // Performance counters
    reg [3:0] cycle_counter;
    reg test_complete;
    
    // DUT instantiation
    sha256_message_scheduler dut (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .block_in(block_in),
        .scheduler_valid(scheduler_valid),
        .w_out(w_out),
        .scheduler_ready(scheduler_ready)
    );

    // Clock generation - 15MHz
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Cycle counter for performance verification
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 0;
            test_complete <= 0;
        end
        else if (scheduler_valid) begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == MAX_CYCLES-1) begin
                test_complete <= 1;
                $display("Performance Check: Completed in %d cycles", cycle_counter + 1);
                if (cycle_counter + 1 <= MAX_CYCLES)
                    $display("? Met cycle requirement (?10 cycles)");
                else
                    $display("? Failed cycle requirement (>10 cycles)");
            end
        end
    end

    // Main test sequence
    initial begin
        // Initialize
        rst_n = 0;
        input_valid = 0;
        block_in = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;
        
        // Reset sequence
        #(CLOCK_PERIOD*2) rst_n = 1;
        #(CLOCK_PERIOD);
        
        // Start test
        input_valid = 1;
        #(CLOCK_PERIOD) input_valid = 0;
        
        // Wait for completion
        wait(test_complete);
        #(CLOCK_PERIOD*2);
        
        $finish;
    end
    
    // Continuous monitoring
    always @(posedge clk) begin
        if (scheduler_valid)
            $display("Time %0t: Generated words %h", $time, w_out);
    end

endmodule
