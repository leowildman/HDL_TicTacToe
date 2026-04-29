module TicTacToe(
    input  wire CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [9:0] SW,
    output wire [7:0] VGA_R, VGA_G, VGA_B,
    output wire VGA_HS, VGA_VS, VGA_CLK, VGA_SYNC_N, VGA_BLANK_N,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    // --- 1. Clock & VGA Timing ---
    reg pclk = 0;
    always @(posedge CLOCK_50) pclk <= ~pclk;
    assign VGA_CLK = pclk;

    // VGA 640x480 @ 60Hz timing parameters
    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_MAX = 800;
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_MAX = 525;
    
    reg [9:0] h_count = 0, v_count = 0;

    // Pixel counters
    always @(posedge pclk) begin
        if (h_count == H_MAX - 1) begin
            h_count <= 0;
            v_count <= (v_count == V_MAX - 1) ? 0 : v_count + 1;
        end else h_count <= h_count + 1;
    end
    
    // Sync pulse generation (active low)
    assign VGA_HS = ~((h_count >= H_ACTIVE + H_FP) && (h_count < H_ACTIVE + H_FP + H_SYNC));
    assign VGA_VS = ~((v_count >= V_ACTIVE + V_FP) && (v_count < V_ACTIVE + V_FP + V_SYNC));
    
    // Blanking and video enable
    wire video_on = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign VGA_BLANK_N = video_on; 
    assign VGA_SYNC_N = 1'b0;
    
    // Output solid black for the display skeleton test
    assign {VGA_R, VGA_G, VGA_B} = 24'h000000;

    // Tie off 7-segment displays to blank (active-low)
    assign HEX5 = 7'b1111111; 
    assign HEX4 = 7'b1111111; 
    assign HEX3 = 7'b1111111;
    assign HEX2 = 7'b1111111;     
    assign HEX1 = 7'b1111111; 
    assign HEX0 = 7'b1111111;

endmodule
