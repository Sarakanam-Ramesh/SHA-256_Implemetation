module sha256_top_tb();
    // Test signals
    reg clk;
    reg rst_n;
    reg start;
    reg [511:0] data_in;
    wire [255:0] hash;
    wire done;
    
    // Additional monitoring signals	
    wire scheduler_valid;
    wire compression_valid;
    wire input_ready;
    wire scheduler_ready;
    wire compression_ready;  
    wire clock_enable;
    wire gated_clk;
    wire [511:0] input_block;
    wire [255:0] scheduler_words;
    wire [255:0] compression_state;
    wire ready_for_next;
    wire input_valid;

    reg prev_input_valid, prev_scheduler_valid, prev_compression_valid;
    reg [31:0] handshake_violations;
    reg [3:0] previous_stage;
    integer i;
    reg [31:0] cycle_time_violations;
    
    // Clock period definitions (15 MHz = 66.67ns)
    localparam CLOCK_PERIOD = 66.67;
    
    // Test parameters
    localparam MAX_CYCLES = 10;
    localparam NUM_TEST_VECTORS = 4;
    
    // Performance monitoring
    integer cycle_count;
    real total_time;
    
    // State monitoring		
    reg [3:0] current_stage;
    localparam STAGE_IDLE = 0;
    localparam STAGE_INPUT = 1;
    localparam STAGE_SCHEDULE = 2;
    localparam STAGE_COMPRESS = 3;
    localparam STAGE_OUTPUT = 4;

    // Enhanced pipeline metrics
    integer stage_transitions;
    reg [3:0] stage_cycle_counts[0:4]; // Cycle counts for each stage

    // Test vectors and expected results
    reg [511:0] test_vectors [0:NUM_TEST_VECTORS-1];
    reg [255:0] expected_hashes [0:NUM_TEST_VECTORS-1];

    // Helper function to convert stage to string 
    function [8*8-1:0] stage_to_string;
        input [3:0] stage;
        begin
            case (stage)
                STAGE_IDLE: stage_to_string = "IDLE";
                STAGE_INPUT: stage_to_string= "INPUT";
                STAGE_SCHEDULE: stage_to_string = "SCHEDULE";
                STAGE_COMPRESS: stage_to_string = "COMPRESS";
                STAGE_OUTPUT: stage_to_string = "OUTPUT";
                default: stage_to_string  = "UNKNOWN";
            endcase
        end
    endfunction 

    // DUT instantiation
    sha256_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .hash_out(hash),
        .done(done),
        .scheduler_valid(scheduler_valid),
        .compression_valid(compression_valid),
        .input_ready(input_ready),
        .scheduler_ready(scheduler_ready),
        .clock_enable(clock_enable),
        .gated_clk(gated_clk),
	    .input_valid(input_valid),
	    .input_block(input_block),
        .scheduler_words(scheduler_words),
        .compression_state(compression_state),
        .ready_for_next(ready_for_next),
        .compression_ready(compression_ready)
    );


    // check_hash task with pipeline monitoring
    task automatic check_hash;
        input integer test_case;
        begin
            if (hash === expected_hashes[test_case]) begin
                $display("\nTest Case %0d: PASSED", test_case);
                $display("Clock cycles: %0d", cycle_count);
                $display("Pipeline stages traversed:");
                $display("Handshake Violations: %0d", handshake_violations);
                
                if (cycle_count <= MAX_CYCLES)
                    $display("? Met cycle requirement (?10 cycles)");
                else
                    $display("? Failed cycle requirement (>10 cycles)");
            end 
            else begin
                $display("\nTest Case %0d: FAILED", test_case);
                $display("Expected: %h", expected_hashes[test_case]);
                $display("Got     : %h", hash);
                $display("Stage at failure: %s", stage_to_string(current_stage));
                $display("Pipeline state at failure:");
                $display("  Input valid: %b", input_valid);
                $display("  Scheduler ready: %b", scheduler_ready);	
                $display("  Compression ready: %b", compression_ready);	
            end
        end
    endtask
    
    // Pipeline stage transition detection
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 5; i = i + 1)
                stage_cycle_counts[i] <= 0;
            stage_transitions <= 0;
            previous_stage <= STAGE_IDLE;
        end
        else begin
            // Count cycles per stage
            stage_cycle_counts[current_stage] <= stage_cycle_counts[current_stage] + 1;
            
            // Track stage transitions
            if (current_stage != previous_stage)
                stage_transitions <= stage_transitions + 1;
                
            previous_stage <= current_stage;
        end
    end
    
   // stage transition monitoring
    always @(posedge clk) begin
        if (!rst_n) begin
            current_stage <= STAGE_IDLE;
        end
        else begin    
            // Track pipeline stages
            case (current_stage)
                STAGE_IDLE: 
                    if (start) current_stage <= STAGE_INPUT;
                STAGE_INPUT: 
                    if (input_valid && scheduler_ready) current_stage <= STAGE_SCHEDULE;	
                STAGE_SCHEDULE: 
                    if (scheduler_valid && compression_ready) current_stage <= STAGE_COMPRESS;
                STAGE_COMPRESS: 
                    if (compression_valid && ready_for_next) current_stage <= STAGE_OUTPUT;	
                STAGE_OUTPUT: 
                    if (done) current_stage <= STAGE_IDLE;
                default: 
                    current_stage <= STAGE_IDLE;
            endcase
        end
    end

    // handshake verification
    always @(posedge clk) begin			
        if (!rst_n) begin
            handshake_violations <= 0;
            prev_input_valid <= 0;
            prev_scheduler_valid <= 0;
            prev_compression_valid <= 0;
        end
        else begin
            // Store previous values
            prev_input_valid <= input_valid;
            prev_scheduler_valid <= scheduler_valid;
            prev_compression_valid <= compression_valid;

            // Check for handshake violations
            if (input_valid && !scheduler_ready && prev_input_valid)
                handshake_violations <= handshake_violations + 1;
            
            if (scheduler_valid && !compression_ready && prev_scheduler_valid)
                handshake_violations <= handshake_violations + 1;
            
            if (compression_valid && !ready_for_next && prev_compression_valid)
                handshake_violations <= handshake_violations + 1;
        end
    end

    // task for display_performance metrics		
    task display_performance_metrics;
        input integer test_case;
        begin
            $display("\nPerformance Metrics for Test Case %0d:", test_case);
            $display("Total Cycles: %0d", cycle_count);
            $display("Stage Transitions: %0d", stage_transitions);
            
            $display("\nStage Cycle Counts:");
            for (i = 0; i < 5; i = i + 1)
                $display("  %s: %0d cycles", stage_to_string(i), stage_cycle_counts[i]);
            
            if (cycle_count > MAX_CYCLES)
                $display("WARNING: Exceeded maximum cycle count (%0d > %0d)", 
                    cycle_count, MAX_CYCLES);
        end
    endtask

    // run_test_case task with pipeline monitoring
    task automatic run_test_case;
        input integer test_case;
        begin
            cycle_count = 0;
            stage_transitions = 0;
            for (i = 0; i < 5; i = i + 1)
                stage_cycle_counts[i] = 0;

            // Wait for any previous operation to complete	
            @(posedge clk);
            while (!done) @(posedge clk);
            
            // Start new test
            $display("\nStarting Test Case %0d", test_case);
            $display("Input data: %h", test_vectors[test_case]);
            data_in = test_vectors[test_case];
            cycle_count = 0;
            
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Monitor pipeline progression
            fork
                begin: timeout_check	
                    repeat(MAX_CYCLES * 2) @(posedge clk);
                    $display("ERROR: Test case %0d timed out", test_case);
                    $display("Pipeline state at timeout:");	
                    $display("  Current stage: %s", stage_to_string(current_stage));
                    $display("  Input valid: %b", input_valid);
                    $display("  Scheduler ready: %b", scheduler_ready);
                    $display("  Compression ready: %b", compression_ready); 	
                    disable execution_block;	
                end
                begin: execution_block	
                    @(posedge done);
                    disable timeout_check;	
                end
            join
            // Check results
            #(CLOCK_PERIOD);
            check_hash(test_case);
            display_performance_metrics(test_case);	
        end
    endtask

    // Clock generation - 15MHz
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    
    
    // Cycle counter for performance verification
    always @(posedge clk) begin
        if (start || !done)
            cycle_count <= cycle_count + 1;
        else
            cycle_count <= 0;
    end
    
    // Initialize test vectors
    initial begin
        // Test vector 1: "abc"
        test_vectors[0] = {
            32'h61626380, // "abc" padded
            {15{32'h0}},  // padding
            32'h00000018  // length = 24 bits
        };
        expected_hashes[0] = 256'hBA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD;
        
        // Test vector 2: Empty string
        test_vectors[1] = {
            32'h80000000, // padding start
            {15{32'h0}},  // padding
            32'h0        // length = 0 bits
        };
        expected_hashes[1] = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
        
        // Test vector 3: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" (first block)
        test_vectors[2] = {
            32'h61626364, 32'h62636465, 32'h63646566, 32'h64656667,
            32'h65666768, 32'h66676869, 32'h6768696a, 32'h68696a6b,
            32'h696a6b6c, 32'h6a6b6c6d, 32'h6b6c6d6e, 32'h6c6d6e6f,
            32'h6d6e6f70, 32'h6e6f7071, 32'h80000000, 32'h000001c0
        };
        expected_hashes[2] = 256'h248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1;
        
        // Test vector 4: All ones
        test_vectors[3] = {
            {16{32'hFFFFFFFF}}
        };
        expected_hashes[3] = 256'haf9613760f72635fbdb44a5a0a63c39f12af30f950a6ee5c971be188e89c4051;
    end
    
    // Main test sequence
    initial begin
        // Initialize signals
	    clk = 0;	
        rst_n = 0;
        start = 0;
        data_in = 0;
        cycle_count = 0;
        
        // Wait 100ns for global reset
        #100;
        
        // Release reset
        rst_n = 1;
        #100;
        
        // Test frequency check
        total_time = $time;
        repeat(100) @(posedge clk);
        total_time = $time - total_time;
        $display("Clock Frequency Check:");
        $display("Measured frequency: %0.2f MHz", 100000/total_time);
        if (100000/total_time > 15.1)
            $display("Warning: Clock frequency exceeds 15 MHz specification");
        
        // Run all test cases
        for (i = 0; i < NUM_TEST_VECTORS; i = i + 1) begin
            run_test_case(i);
            #(CLOCK_PERIOD*2);
        end
        
        // Test reset during operation
        $display("\nTesting reset during operation...");
        data_in = test_vectors[0];
        start = 1;
        @(posedge clk);
        start = 0;
        #(CLOCK_PERIOD*2);
        rst_n = 0;
        #(CLOCK_PERIOD);
        rst_n = 1;
        
        if (hash === 256'h0 && !done)
            $display("Reset Test: PASSED");
        else
            $display("Reset Test: FAILED");
        
        // Test back-to-back operations
        $display("\nTesting back-to-back operations...");
        run_test_case(0);
        run_test_case(1);
        
        // End simulation
        #(CLOCK_PERIOD*10);
        $display("\nAll tests completed");
        $finish;
    end
    
    // Additional Monitoring
    initial cycle_time_violations = 0;
    
    always @(posedge done) begin
        if (cycle_count > MAX_CYCLES) begin
            cycle_time_violations <= cycle_time_violations + 1;
            $display("Warning: Cycle count violation detected at time %0t", $time);
        end
    end
endmodule
