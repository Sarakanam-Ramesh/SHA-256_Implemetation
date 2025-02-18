module sha256_compressor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [511:0] message_block,  // 16 x 32-bit words
    input wire [255:0] initial_hash,   // 8 x 32-bit hash values
    output reg [255:0] hash_out,       // Final hash output
    output reg done,                    // Completion signal
    output reg ready_for_scheduler
    );
    
        // Constants
    parameter ROUNDS_PER_CYCLE = 8;    // Process 8 words per cycle
    parameter TOTAL_CYCLES = 10;       // Complete in 10 cycles
    
    // K constants for SHA-256 (first 64 values)
    reg [31:0] K [0:63];
    initial begin
    K[0] = 32'h428a2f98; K[1] = 32'h71374491; K[2] = 32'hb5c0fbcf; K[3] = 32'he9b5dba5;
	K[4] = 32'h3956c25b; K[5] = 32'h59f111f1; K[6] = 32'h923f82a4; K[7] = 32'hab1c5ed5;
	K[8] = 32'hd807aa98; K[9] = 32'h12835b01; K[10] = 32'h243185be; K[11] = 32'h550c7dc3;
    K[12] = 32'h72be5d74; K[13] = 32'h80deb1fe; K[14] = 32'h9bdc06a7; K[15] = 32'hc19bf174; 
	K[16] = 32'he49b69c1; K[17] = 32'hefbe4786; K[18] = 32'h0fc19dc6; K[19] = 32'h240ca1cc; 
	K[20] = 32'h2de92c6f; K[21] = 32'h4a7484aa; K[22] = 32'h5cb0a9dc; K[23] = 32'h76f988da;
    K[24] = 32'h983e5152; K[25] = 32'ha831c66d; K[26] = 32'hb00327c8; K[27] = 32'hbf597fc7; 
	K[28] = 32'hc6e00bf3; K[29] = 32'hd5a79147; K[30] = 32'h06ca6351; K[31] = 32'h14292967; 
	K[32] = 32'h27b70a85; K[33] = 32'h2e1b2138; K[34] = 32'h4d2c6dfc; K[35] = 32'h53380d13;
    K[36] = 32'h650a7354; K[37] = 32'h766a0abb; K[38] = 32'h81c2c92e; K[39] = 32'h92722c85; 
	K[40] = 32'ha2bfe8a1; K[41] = 32'ha81a664b; K[42] = 32'hc24b8b70; K[43] = 32'hc76c51a3; 
	K[44] = 32'hd192e819; K[45] = 32'hd6990624; K[46] = 32'hf40e3585; K[47] = 32'h106aa070;
    K[48] = 32'h19a4c116; K[49] = 32'h1e376c08; K[50] = 32'h2748774c; K[51] = 32'h34b0bcb5; 
	K[52] = 32'h391c0cb3; K[53] = 32'h4ed8aa4a; K[54] = 32'h5b9cca4f; K[55] = 32'h682e6ff3;
    K[56] = 32'h748f82ee; K[57] = 32'h78a5636f; K[58] = 32'h84c87814; K[59] = 32'h8cc70208;
    K[60] = 32'h90befffa; K[61] = 32'ha4506ceb; K[62] = 32'hbef9a3f7; K[63] = 32'hc67178f2;
    end
    
    // Internal registers
    reg [31:0] w [0:63];              // Message schedule array
    reg [31:0] a, b, c, d, e, f, g, h; // Working variables
    reg [3:0] cycle_count;            // Counter for 10 cycles
    reg [5:0] round_base;             // Base round number
    
    // State machine
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam FINALIZE = 2'b10;
    reg [1:0] state;
    
    // SHA-256 functions
    function [31:0] ch;
        input [31:0] x, y, z;
        begin
            ch = (x & y) ^ (~x & z);
        end
    endfunction
    
    function [31:0] maj;
        input [31:0] x, y, z;
        begin
            maj = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction
    
    function [31:0] ep0;
        input [31:0] x;
        begin
            ep0 = {x[1:0],x[31:2]} ^ {x[12:0],x[31:13]} ^ {x[21:0],x[31:22]};
        end
    endfunction
    
    function [31:0] ep1;
        input [31:0] x;
        begin
            ep1 = {x[5:0],x[31:6]} ^ {x[10:0],x[31:11]} ^ {x[24:0],x[31:25]};
        end
    endfunction
    
    // Message schedule generation
    integer i;

    // Temporary variables for compression logic
    reg [31:0] t1; //[0:ROUNDS_PER_CYCLE-1];	// Cannot assign a packed type 'reg[31:0]' to an unpacked type 'wire[31:0] $[0:ROUNDS_PER_CYCLE-1]'.
    reg [31:0] t2; //[0:ROUNDS_PER_CYCLE-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ready_for_scheduler <= 1'b1;
        else if (start)
            ready_for_scheduler <= 1'b0;
        else if (done)
            ready_for_scheduler <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset message schedule
            for (i = 0; i < 64; i = i + 1) begin
                w[i] <= 32'h0;
            end
        end else if (state == IDLE && start) begin
            // Load initial message block
            for (i = 0; i < 16; i = i + 1) begin
                w[i] <= message_block[511-32*i -: 32];
            end
        end else if (state == PROCESS) begin
            // Generate next 8 words in parallel
             for (i = 16; i < 64; i = i + 1) begin
                w[i] <= w[i-16] + 
                       {w[i-15][6:0],w[i-15][31:7]} ^ 
                       {w[i-15][17:0],w[i-15][31:18]} ^ 
                       (w[i-15] >> 3) +
                       w[i-7] +
                       {w[i-2][16:0],w[i-2][31:17]} ^ 
                       {w[i-2][18:0],w[i-2][31:19]} ^ 
                       (w[i-2] >> 10);
            end
        end
    end
    
    // Main compression logic
    integer r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            round_base <= 6'd0;
            done <= 1'b0;
            hash_out <= 256'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        cycle_count <= 4'd0;
                        round_base <= 6'd0;
                        // Initialize working variables
                        a <= initial_hash[255:224];
                        b <= initial_hash[223:192];
                        c <= initial_hash[191:160];
                        d <= initial_hash[159:128];
                        e <= initial_hash[127:96];
                        f <= initial_hash[95:64];
                        g <= initial_hash[63:32];
                        h <= initial_hash[31:0];
                        done <= 1'b0;
                    end
                end
                
                PROCESS: begin
                    // Process 8 rounds in parallel
                        for (r = 0; r < ROUNDS_PER_CYCLE; r = r + 1) begin
                            // Compression round logic
                            t1 = h + ep1(e) + ch(e,f,g) + K[round_base+r] + w[round_base+r];
                            t2 = ep0(a) + maj(a,b,c);
                        end
			// update hashvalues
                            h <= g;
                            g <= f;
                            f <= e;
                            e <= d + t1[0];
                            d <= c;
                            c <= b;
                            b <= a;
                            a <= t1[0] + t2[0];

                    
                    round_base <= round_base + ROUNDS_PER_CYCLE;
                    cycle_count <= cycle_count + 1;
                    
                    if (cycle_count == TOTAL_CYCLES - 1) begin
                        state <= FINALIZE;
                    end
                end
                
                FINALIZE: begin
                    // Compute final hash
                    hash_out <= {
                        a + initial_hash[255:224],
                        b + initial_hash[223:192],
                        c + initial_hash[191:160],
                        d + initial_hash[159:128],
                        e + initial_hash[127:96],
                        f + initial_hash[95:64],
                        g + initial_hash[63:32],
                        h + initial_hash[31:0]
                    };
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule