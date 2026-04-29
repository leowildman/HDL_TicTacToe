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

    reg score_updated; 
    reg [3:0] p1_score = 0, p2_score = 0;
    
    // Combinatorial win detection
    wire w_r0 = (board[0]!=0) && (board[0]==board[1]) && (board[1]==board[2]);
    wire w_r1 = (board[3]!=0) && (board[3]==board[4]) && (board[4]==board[5]);
    wire w_r2 = (board[6]!=0) && (board[6]==board[7]) && (board[7]==board[8]);
    wire w_c0 = (board[0]!=0) && (board[0]==board[3]) && (board[3]==board[6]);
    wire w_c1 = (board[1]!=0) && (board[1]==board[4]) && (board[4]==board[7]);
    wire w_c2 = (board[2]!=0) && (board[2]==board[5]) && (board[5]==board[8]);
    wire w_d1 = (board[0]!=0) && (board[0]==board[4]) && (board[4]==board[8]);
    wire w_d2 = (board[2]!=0) && (board[2]==board[4]) && (board[4]==board[6]);

    wire win_1 = (board[0]==1&&w_r0) | (board[3]==1&&w_r1) | (board[6]==1&&w_r2) | 
                 (board[0]==1&&w_c0) | (board[1]==1&&w_c1) | (board[2]==1&&w_c2) | 
                 (board[0]==1&&w_d1) | (board[2]==1&&w_d2);
                 
    wire win_2 = (board[0]==2&&w_r0) | (board[3]==2&&w_r1) | (board[6]==2&&w_r2) | 
                 (board[0]==2&&w_c0) | (board[1]==2&&w_c1) | (board[2]==2&&w_c2) | 
                 (board[0]==2&&w_d1) | (board[2]==2&&w_d2);
                 
    wire game_over = w_r0 | w_r1 | w_r2 | w_c0 | w_c1 | w_c2 | w_d1 | w_d2;
    
    always @(posedge pclk) begin
        if (~KEY[2]) begin // Hard Reset
            for(i=0; i<9; i=i+1) board[i] <= 0;
            turn <= 0; p1_score <= 0; p2_score <= 0; score_updated <= 0;
        end else if (~KEY[0]) begin // Soft Reset
            for(i=0; i<9; i=i+1) board[i] <= 0;
            turn <= 0; score_updated <= 0;
        end else if (game_over) begin
            if (!score_updated) begin
                if (win_1) p1_score <= p1_score + 1;
                if (win_2) p2_score <= p2_score + 1;
                score_updated <= 1;
            end
        end else begin
            // Human piece placement logic
            if (human_press && sw_sel != 9 && board[sw_sel] == 0) begin
                board[sw_sel] <= (turn == 0) ? 1 : 2; 
                turn <= ~turn; 
            end
        end
    end

    // --- 6. 7-Segment Displays ---
    function [6:0] seg7(input [3:0] num);
        case(num)
            0: seg7=7'b1000000; 1: seg7=7'b1111001; 2: seg7=7'b0100100; 3: seg7=7'b0110000; 
            4: seg7=7'b0011001; 5: seg7=7'b0010010; 6: seg7=7'b0000010; 7: seg7=7'b1111000; 
            8: seg7=7'b0000000; 9: seg7=7'b0010000; default: seg7=7'b1111111;
        endcase
    endfunction
    
    assign HEX5 = seg7(p1_score); 
    assign HEX4 = 7'b1111111; 
    assign HEX3 = 7'b0111111;
    assign HEX2 = 7'b0111111;     
    assign HEX1 = 7'b1111111; 
    assign HEX0 = seg7(p2_score);

    // --- 7. Geometry Math ---
    wire [1:0] col = (h_count < 213) ? 0 : (h_count < 427) ? 1 : 2;
    wire [1:0] row = (v_count < 160) ? 0 : (v_count < 320) ? 1 : 2;
    wire [3:0] cell_idx = (row * 3) + col;
    
    wire is_grid = (h_count>211 && h_count<215) || (h_count>425 && h_count<429) || 
                   (v_count>158 && v_count<162) || (v_count>318 && v_count<322);

    wire [7:0] x_local = h_count - (col * 213);
    wire [7:0] y_local = v_count - (row * 160);

    wire x_d1 = (x_local>y_local)?(x_local-y_local<8):(y_local-x_local<8);
    wire x_d2 = (x_local+y_local>185) && (x_local+y_local<200);
    wire is_X = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_d1 || x_d2);
    wire is_O = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_local<60 || x_local>150 || y_local<40 || y_local>120);

    // --- 9. Rendering Pipeline ---
    wire [1:0] state = board[cell_idx];
    wire is_prev = (state == 0 && sw_sel == cell_idx && !game_over);
    wire draw_shape = (state == 1) ? is_X : (state == 2) ? is_O : (is_prev ? ((turn==0)?is_X:is_O) : 1'b0);

    reg [23:0] rgb;
    always @(*) begin
        if (!video_on) rgb = 24'h000000;
        else if (is_grid) rgb = 24'hFFFFFF;
        else if (draw_shape) begin
            if (is_prev) rgb = 24'h0000FF;         
            else if (state==1) rgb = 24'hFF0000; 
            else rgb = 24'h00FF00;                    
        end else rgb = 24'h000000;
    end
    
    assign {VGA_R, VGA_G, VGA_B} = rgb;

endmodule
