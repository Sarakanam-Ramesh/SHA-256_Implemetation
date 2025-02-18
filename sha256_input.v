module sha256_input(
    input wire clk, rst_n,
    input wire start,
    input wire [511:0] block_in,
    output reg input_valid,
    output reg [511:0] block_out,
    output reg ready,           // Indicates module is ready for new input
    input wire next_stage_ready
    );
    
    // Simple state machine
    reg processing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_out <= 512'b0;
            input_valid <= 1'b0;
            ready <= 1'b1;
            processing <= 1'b0;
        end
        else begin
            if (start && ready) begin
                block_out <= block_in;
                input_valid <= 1'b1;
                ready <= 1'b0;
                processing <= 1'b1;
            end
            else if (processing && next_stage_ready) begin
                input_valid <= 1'b0;
                ready <= 1'b1;
                processing <= 1'b0;
            end
        end
    end

endmodule
