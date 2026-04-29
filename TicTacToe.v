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

    // --- 2. Inputs & Debouncing ---
    // Priority encoder for switches to map physical toggle to cell index 0-8
    wire [3:0] sw_sel = SW[0]?0 : SW[1]?1 : SW[2]?2 : SW[3]?3 : SW[4]?4 : 
                        SW[5]?5 : SW[6]?6 : SW[7]?7 : SW[8]?8 : 9;
    
    // 2-stage shift register to debounce active-low pushbuttons
    reg [1:0] k1_deb, k3_deb;
    always @(posedge pclk) begin
        k3_deb <= {k3_deb[0], ~KEY[3]}; 
        k1_deb <= {k1_deb[0], ~KEY[1]};
    end
    
    // Detect rising edge of the debounced signal (button press)
    wire human_press = k3_deb[0] & ~k3_deb[1]; 
    wire cpu_press   = k1_deb[0] & ~k1_deb[1];

    // --- 7. Geometry Math ---
    // Divide 640x480 into a 3x3 logical grid
    wire [1:0] col = (h_count < 213) ? 0 : (h_count < 427) ? 1 : 2;
    wire [1:0] row = (v_count < 160) ? 0 : (v_count < 320) ? 1 : 2;
    wire [3:0] cell_idx = (row * 3) + col;

    // Define pixel boundaries for the white grid lines
    wire is_grid = (h_count>211 && h_count<215) || (h_count>425 && h_count<429) || 
                   (v_count>158 && v_count<162) || (v_count>318 && v_count<322);

    // --- 9. Rendering Pipeline ---
    reg [23:0] rgb;
    always @(*) begin
        if (!video_on) rgb = 24'h000000;
        else if (is_grid) rgb = 24'hFFFFFF; // Draw the grid
        else rgb = 24'h000000;              // Fill empty space with black
    end
    
    assign {VGA_R, VGA_G, VGA_B} = rgb;

    // Tie off 7-segment displays to blank (active-low)
    assign HEX5 = 7'b1111111; 
    assign HEX4 = 7'b1111111; 
    assign HEX3 = 7'b1111111;
    assign HEX2 = 7'b1111111;     
    assign HEX1 = 7'b1111111; 
    assign HEX0 = 7'b1111111;

endmodule
