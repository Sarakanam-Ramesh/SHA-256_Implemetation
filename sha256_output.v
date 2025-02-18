module sha256_output(
    input wire clk, rst_n,
    input wire compression_valid,
    input wire [255:0] state_in,
    output reg [255:0] hash_out,
    output reg done,
    // Added control signals for pipeline management
    output reg ready_for_next
    );
    
        // Clock gating control
    reg clock_enable;
    wire gated_clk;
    
    // Clock gating cell
    assign gated_clk = clk & clock_enable;
    
    // Pipeline control
    reg [255:0] hash_pipe;
    reg pipeline_valid;
    
    // FSM states
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam OUTPUT = 2'b10;
    reg [1:0] state; 

    // Optimized control logic with reduced states
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            hash_out <= 0;
            hash_pipe <= 0;
            clock_enable <= 0;
            ready_for_next <= 1;
            pipeline_valid <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (compression_valid) begin
                        hash_pipe <= state_in;
                        state <= PROCESS;
                        clock_enable <= 1;
                        ready_for_next <= 0;
                        pipeline_valid <= 1;
                    end
                end
                
                PROCESS: begin
                    if (pipeline_valid) begin
                        hash_out <= hash_pipe;
                        done <= 1;
                        state <= OUTPUT;
                        clock_enable <= 0;
                    end
                end
                
                OUTPUT: begin
                    done <= 0;
                    state <= IDLE;
                    ready_for_next <= 1;
                    pipeline_valid <= 0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule