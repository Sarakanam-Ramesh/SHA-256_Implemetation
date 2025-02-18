module sha256_compressor_tb();

    // Testbench signals
    reg clk;
    reg rst_n;
    reg start;
    reg [511:0] message_block;
    reg [255:0] initial_hash;
    wire [255:0] hash_out;
    wire done;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Instantiate compression module
    sha256_compressor uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .message_block(message_block),
        .initial_hash(initial_hash),
        .hash_out(hash_out),
        .done(done)
    );
    
    // Test vectors
    // Using "abc" as test message (a well-known test vector for SHA-256)
    reg [511:0] test_message = {
        32'h61626380, // "abc" padded
        32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
        32'h00000000, 32'h00000000, 32'h00000000, 32'h00000018  // Length = 24 bits
    };
    
    reg [255:0] test_init_hash = {
        32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
        32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };
    
    // Expected output for "abc" (known SHA-256 hash)
    reg [255:0] expected_hash = 256'hBA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD;
    
    
    // Performance monitoring
    integer cycle_count;
    time start_time, end_time;
    
    // Test scenario
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        message_block = 0;
        initial_hash = 0;
        cycle_count = 0;
        
        // Reset sequence
        #20 rst_n = 1;
        
        // Wait for a few cycles
        #20;
        
        // Test Case 1: Standard compression
        $display("Starting Test Case 1: Standard compression");
        message_block = test_message;
        initial_hash = test_init_hash;
        start = 1;
        start_time = $time;
        
        // Wait for completion
        @(posedge done);
        end_time = $time;
        start = 0;
        
        // Verify results
        #10;
        if (hash_out === expected_hash) begin
            $display("Test Case 1: PASSED");
            $display("Processing time: %0d ns", end_time - start_time);
            $display("Clock cycles taken: %0d", (end_time - start_time)/(10)); // Assuming 100MHz clock
        end else begin
            $display("Test Case 1: FAILED");
            $display("Expected: %h", expected_hash);
            $display("Got     : %h", hash_out);
        end
        
        // Test Case 2: Performance test with random data
        $display("\nStarting Test Case 2: Performance test");
        message_block = {$random, $random, $random, $random,
                        $random, $random, $random, $random,
                        $random, $random, $random, $random,
                        $random, $random, $random, $random};
        initial_hash = test_init_hash;
        start = 1;
        start_time = $time;
        
        // Wait for completion
        @(posedge done);
        end_time = $time;
        start = 0;
        
        // Verify timing requirements
        #10;
        if ((end_time - start_time)/10 <= 10) begin // Checking if completed within 10 cycles
            $display("Performance Test: PASSED");
            $display("Completed within timing requirement");
            $display("Actual cycles taken: %0d", (end_time - start_time)/10);
        end else begin
            $display("Performance Test: FAILED");
            $display("Exceeded maximum cycle count");
            $display("Actual cycles taken: %0d", (end_time - start_time)/10);
        end
        
        // Test Case 3: Reset during operation
        $display("\nStarting Test Case 3: Reset during operation");
        message_block = test_message;
        initial_hash = test_init_hash;
        start = 1;
        #30; // Wait for a few cycles
        rst_n = 0; // Assert reset
        #10;
        rst_n = 1; // De-assert reset
        start = 0;
        
        // Verify reset behavior
        #10;
        if (hash_out === 256'h0) begin
            $display("Reset Test: PASSED");
        end else begin
            $display("Reset Test: FAILED");
        end
        
        // End simulation
        #100;
        $display("\nAll tests completed");
        $finish;
    end
    
    // Monitor state transitions
    always @(posedge clk) begin
        if (start) begin
            cycle_count <= cycle_count + 1;
        end
    end
endmodule