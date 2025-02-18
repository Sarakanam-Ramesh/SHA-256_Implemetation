module sha256_top(
    input wire clk,	// 15 MHz clock
    input wire rst_n,	// Active Low reset
    input wire start,	// Start signal
    input wire [511:0] data_in, 	// Input block
    output wire [255:0] hash_out,	// FInal hash
    output wire done,	// Processing complete
    // Internal signals for module interconnection
    output wire input_valid,
    output wire [511:0] input_block,
    output wire scheduler_valid,
    output wire [255:0] scheduler_words,
    output wire compression_valid,
    output wire [255:0] compression_state,
    output wire ready_for_next,
    output wire input_ready,
    output wire scheduler_ready,
    output wire compression_ready,
    wire gated_clk,
    reg clock_enable
    );

    // Initial hash values (H0 to H7) as per SHA-256 spec
    wire [255:0] initial_hash = {
        32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
        32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };

    // Clock gating logic to meet power and timing constraints
    reg [3:0] stage_counter;
    reg pipeline_active;	
    wire stage_timeout;		
    reg [1:0] rst_sync;
    wire rst_n_sync;

    // Stage timeout detection
    assign stage_timeout = (stage_counter >= 4'd10);

    // Reset synchronizer		
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rst_sync <= 2'b00;
        else
            rst_sync <= {rst_sync[0], 1'b1};
    end
    assign rst_n_sync = rst_sync[1];

	//pipeline stage counter
    always @(posedge clk or negedge rst_n_sync) begin	
    	if (!rst_n_sync)	
        	stage_counter <= 4'd0;		
    	else if (start)
        	stage_counter <= 4'd0;		
    	else if (pipeline_active && !stage_timeout)	
        	stage_counter <= stage_counter + 4'd1;	
    end

    // Pipeline activity control		
    always @(posedge clk or negedge rst_n_sync) begin
        if (!rst_n_sync)
            pipeline_active <= 1'b0;
        else if (start)
            pipeline_active <= 1'b1;
        else if (done || stage_timeout)
            pipeline_active <= 1'b0;
    end

    // clock gating logic
    always @(posedge clk or negedge rst_n_sync) begin	
        if (!rst_n_sync)	
            clock_enable <= 1'b0;
        else if (start)
            clock_enable <= 1'b1;
        else if (done || stage_timeout)	
            clock_enable <= 1'b0;
    end
    
    assign gated_clk = clk & clock_enable;

	// Input stage
    sha256_input input_module (
        .clk(gated_clk), .rst_n(rst_n_sync),
        .start(start),
        .block_in(data_in),	
        .input_valid(input_valid),
        .block_out(input_block),	
	.ready(input_ready),
	.next_stage_ready(scheduler_ready)
    );

	// Message scheduler stage
    sha256_message_scheduler scheduler (
        .clk(gated_clk), .rst_n(rst_n_sync),
        .input_valid(input_valid),
        .block_in(input_block),	
        .scheduler_valid(scheduler_valid),
        .w_out(scheduler_words),	
        .scheduler_ready(scheduler_ready)
    );

	// Compression stage
    sha256_compressor compressor (
        .clk(gated_clk), 
        .rst_n(rst_n_sync),
        .start(scheduler_valid),
        .message_block(input_block),	// connect to input module's output
        .initial_hash(initial_hash),
        .hash_out(compression_state),	// 256-bit output
	.done(compression_valid),
        .ready_for_scheduler(compression_ready)
    );

	// Output stage
    sha256_output output_module (
        .clk(gated_clk), .rst_n(rst_n_sync),
        .compression_valid(compression_valid),
        .state_in(compression_state),	// conect to compressor outpu
        .hash_out(hash_out),	// connect to top-level output
        .done(done),
	.ready_for_next(ready_for_next)
    );
endmodule

