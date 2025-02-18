module sha256_message_scheduler(
    input wire clk, rst_n,
    input wire input_valid,
    input wire [511:0] block_in,
    output reg scheduler_valid,
    output reg [255:0] w_out,	
    output reg scheduler_ready	
    );
    
    reg [31:0] w[0:15];		// 16 word buffer for optimized implementation
    reg [2:0] counter;
    integer i;
    
    // Optimized next word calculation for parallel processing
    function [255:0] next_eight_words;
        input [3:0] base_index;
        reg [31:0] words[0:7];
        integer j;
        begin
            for (j = 0; j < 8; j = j + 1) begin
                words[j] = sigma0_1(w[(base_index+j-2) & 15], 1) + 
                          w[(base_index+j-7) & 15] + 
                          sigma0_1(w[(base_index+j-15) & 15], 0) + 
                          w[(base_index+j-16) & 15];
            end
            next_eight_words = {words[0], words[1], words[2], words[3],
                              words[4], words[5], words[6], words[7]};
        end
    endfunction
    
        function [31:0] sigma0_1;
        input [31:0] x;
        input is_sigma1;  // 0 for sigma0, 1 for sigma1
        begin
            sigma0_1 = is_sigma1 ? 
                ({x[16:0],x[31:17]} ^ {x[18:0],x[31:19]} ^ (x >> 10)) :
                ({x[6:0],x[31:7]} ^ {x[17:0],x[31:18]} ^ (x >> 3));
        end
    endfunction

    // logic to drive scheduler ready
    always @(posedge clk or negedge rst_n) begin
    	if (!rst_n)
        	scheduler_ready <= 1'b0;
    	else if (input_valid)
        	scheduler_ready <= 1'b1;
    	else if (scheduler_valid)
        	scheduler_ready <= 1'b0;
    end
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            scheduler_valid <= 0;
            //w_array_loaded <= 1'b0;
            w_out <= 0;  // Initialize w_out during reset
            for (i = 0; i < 16; i = i + 1) begin
                w[i] <= 0;  // Initialize w array during reset
		//counter <= 0;
		//scheduler_valid <= 0;	// commented previous logic
            end
	    end
        else if (input_valid) begin
            // Load initial message words
            for (i = 0; i < 16; i = i + 1) begin
                w[i] <= block_in[511-i*32 -: 32];
            end
            counter <= 0;
            scheduler_valid <= 1;
            //w_array_loaded <= 1'b1;
            w_out <= block_in[511:256];  // Output first four words
        end
        else if ( scheduler_valid) begin
            if (counter < 7) begin	//process 64 words in pairs (8 cycles )
                w_out <= next_eight_words(counter * 8);
                counter <= counter + 1;
            end
    	    end
            else begin
                scheduler_valid <= 1'b0;
                //w_array_loaded <= 1'b0;
                w_out <= 0;
            end
        end
            
endmodule