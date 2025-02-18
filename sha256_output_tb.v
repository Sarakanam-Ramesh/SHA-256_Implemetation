module sha256_output_tb();
// Optimized testbench with comprehensive testing
    reg clk, rst_n;
    reg compression_valid;
    reg [255:0] state_in;
    wire [255:0] hash_out;
    wire done, ready_for_next;
    
    // Test parameters
    localparam CLOCK_PERIOD = 66; // For 15 MHz
    localparam MAX_CYCLES = 10;
    
    // Performance monitoring
    integer cycle_count;
    time start_time;
    
    // DUT instantiation
    sha256_output dut (
        .clk(clk),
        .rst_n(rst_n),
        .compression_valid(compression_valid),
        .state_in(state_in),
        .hash_out(hash_out),
        .done(done),
        .ready_for_next(ready_for_next)
    );
    
    // 15 MHz clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    // Test vectors from FIPS PUB 180-4
    reg [255:0] test_vectors [0:3];
    integer test_case;
    
    // Cycle counter
    always @(posedge clk) begin
        if (compression_valid || !ready_for_next)
            cycle_count <= cycle_count + 1;
        else
            cycle_count <= 0;
    end
    
    // Main test sequence
    initial begin
        // Initialize test vectors
        test_vectors[0] = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad; // "abc"
        test_vectors[1] = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1; // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        test_vectors[2] = 256'hcdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0; // Million 'a'
        test_vectors[3] = 256'h50e72a0e26442fe2552dc3938ac58658228c0cbfb1d2ca872ae435266fcd055e; // Random test vector
        
        // Initialize signals
        rst_n = 0;
        compression_valid = 0;
        state_in = 0;
        cycle_count = 0;
        
        // Reset sequence
        #(CLOCK_PERIOD*2);
        rst_n = 1;
        #(CLOCK_PERIOD);
        
        // Test each vector
        for (test_case = 0; test_case < 4; test_case = test_case + 1) begin
            // Wait for ready
            wait(ready_for_next);
            
            // Start test
            $display("\nStarting test case %0d", test_case);
            state_in = test_vectors[test_case];
            compression_valid = 1;
            start_time = $time;
            cycle_count = 0;
            
            #(CLOCK_PERIOD);
            compression_valid = 0;
            
            // Wait for completion
            wait(done);
            
            // Verify results
            if (hash_out === test_vectors[test_case]) begin
                $display("? Test case %0d passed", test_case);
                $display("  Cycles taken: %0d", cycle_count);
                if (cycle_count <= MAX_CYCLES)
                    $display("  ? Met cycle requirement (?10 cycles)");
                else
                    $display("  ? Failed cycle requirement (>10 cycles)");
            end else begin
                $display("? Test case %0d failed", test_case);
                $display("  Expected: %h", test_vectors[test_case]);
                $display("  Got     : %h", hash_out);
            end
            
            #(CLOCK_PERIOD*2);
        end
        
        // Test reset during operation
        $display("\nTesting reset during operation");
        state_in = test_vectors[0];
        compression_valid = 1;
        #(CLOCK_PERIOD);
        rst_n = 0;
        #(CLOCK_PERIOD);
        rst_n = 1;
        
        if (hash_out === 0 && !done && ready_for_next)
            $display("? Reset test passed");
        else
            $display("? Reset test failed");
        
        #(CLOCK_PERIOD*5);
        $finish;
    end
    
    // Clock frequency check
    initial begin
        #1;
        if (CLOCK_PERIOD != 66)
            $display("Warning: Clock period may not meet 15 MHz requirement");
    end

endmodule