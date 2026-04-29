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

    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_MAX = 800;
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_MAX = 525;
    
    reg [9:0] h_count = 0, v_count = 0;

    always @(posedge pclk) begin
        if (h_count == H_MAX - 1) begin
            h_count <= 0;
            v_count <= (v_count == V_MAX - 1) ? 0 : v_count + 1;
        end else h_count <= h_count + 1;
    end
    
    assign VGA_HS = ~((h_count >= H_ACTIVE + H_FP) && (h_count < H_ACTIVE + H_FP + H_SYNC));
    assign VGA_VS = ~((v_count >= V_ACTIVE + V_FP) && (v_count < V_ACTIVE + V_FP + V_SYNC));
    
    wire video_on = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign VGA_BLANK_N = video_on; 
    assign VGA_SYNC_N = 1'b0;

    // --- 2. Inputs & Debouncing ---
    wire [3:0] sw_sel = SW[0]?0 : SW[1]?1 : SW[2]?2 : SW[3]?3 : SW[4]?4 : 
                        SW[5]?5 : SW[6]?6 : SW[7]?7 : SW[8]?8 : 9;
    
    reg [1:0] k1_deb, k3_deb;
    always @(posedge pclk) begin
        k3_deb <= {k3_deb[0], ~KEY[3]}; 
        k1_deb <= {k1_deb[0], ~KEY[1]};
    end
    wire human_press = k3_deb[0] & ~k3_deb[1]; 
    
    wire cpu_press   = k1_deb[0] & ~k1_deb[1]; 

    // --- 3. Game State & Logic ---
    reg [1:0] board [0:8]; 
    reg turn = 0;
    integer i;
    
    always @(posedge pclk) begin
        // Reset logic (Hard & Soft behave the same here since scoring isn't added yet)
        if (~KEY[2] || ~KEY[0]) begin 
            for(i=0; i<9; i=i+1) board[i] <= 0;
            turn <= 0;
        end else begin
            // Place piece if valid switch is selected and human presses KEY[3]
            if (human_press && sw_sel != 9 && board[sw_sel] == 0) begin
                board[sw_sel] <= (turn == 0) ? 1 : 2; 
                turn <= ~turn; 
            end
        end
    end

    // --- 7. Geometry Math ---
    wire [1:0] col = (h_count < 213) ? 0 : (h_count < 427) ? 1 : 2;
    wire [1:0] row = (v_count < 160) ? 0 : (v_count < 320) ? 1 : 2;
    wire [3:0] cell_idx = (row * 3) + col;
    
    wire is_grid = (h_count>211 && h_count<215) || (h_count>425 && h_count<429) || 
                   (v_count>158 && v_count<162) || (v_count>318 && v_count<322);

    // Calculate local pixel coordinates within each cell
    wire [7:0] x_local = h_count - (col * 213);
    wire [7:0] y_local = v_count - (row * 160);

    // Shape drawing logic (X and O formulas)
    wire x_d1 = (x_local>y_local)?(x_local-y_local<8):(y_local-x_local<8);
    wire x_d2 = (x_local+y_local>185) && (x_local+y_local<200);
    wire is_X = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_d1 || x_d2);
    wire is_O = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_local<60 || x_local>150 || y_local<40 || y_local>120);

    // --- 9. Rendering Pipeline ---
    wire [1:0] state = board[cell_idx];
    wire is_prev = (state == 0 && sw_sel == cell_idx);
    wire draw_shape = (state == 1) ? is_X : (state == 2) ? is_O : (is_prev ? ((turn==0)?is_X:is_O) : 1'b0);

    reg [23:0] rgb;
    always @(*) begin
        if (!video_on) rgb = 24'h000000;
        else if (is_grid) rgb = 24'hFFFFFF;
        else if (draw_shape) begin
            if (is_prev) rgb = 24'h0000FF;       // Blue for preview cursor
            else if (state==1) rgb = 24'hFF0000; // Red for Player 1 (X)
            else rgb = 24'h00FF00;               // Green for Player 2 (O)
        end else rgb = 24'h000000;
    end
    
    assign {VGA_R, VGA_G, VGA_B} = rgb;

    
    assign HEX5 = 7'b1111111; 
    assign HEX4 = 7'b1111111; 
    assign HEX3 = 7'b1111111;
    assign HEX2 = 7'b1111111;     
    assign HEX1 = 7'b1111111; 
    assign HEX0 = 7'b1111111;

endmodule
