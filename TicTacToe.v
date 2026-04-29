module TicTacToe(
    input  wire CLOCK_50,
    input  wire [3:0] KEY,  // [3]=Human, [2]=Hard Reset, [1]=CPU, [0]=Soft Reset (Active Low)
    input  wire [9:0] SW,   // Grid selection
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

    // --- 3. Game Logic ---
    reg [1:0] board [0:8]; 
    reg turn, score_updated; 
    reg [3:0] p1_score = 0, p2_score = 0;
    
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

    // --- 4. CPU AI ---
    wire [3:0] block_targ = 
        (board[1]==1 && board[2]==1 && board[0]==0)?0 : (board[0]==1 && board[2]==1 && board[1]==0)?1 : (board[0]==1 && board[1]==1 && board[2]==0)?2 : 
        (board[4]==1 && board[5]==1 && board[3]==0)?3 : (board[3]==1 && board[5]==1 && board[4]==0)?4 : (board[3]==1 && board[4]==1 && board[5]==0)?5 : 
        (board[7]==1 && board[8]==1 && board[6]==0)?6 : (board[6]==1 && board[8]==1 && board[7]==0)?7 : (board[6]==1 && board[7]==1 && board[8]==0)?8 : 
        (board[3]==1 && board[6]==1 && board[0]==0)?0 : (board[0]==1 && board[6]==1 && board[3]==0)?3 : (board[0]==1 && board[3]==1 && board[6]==0)?6 : 
        (board[4]==1 && board[7]==1 && board[1]==0)?1 : (board[1]==1 && board[7]==1 && board[4]==0)?4 : (board[1]==1 && board[4]==1 && board[7]==0)?7 : 
        (board[5]==1 && board[8]==1 && board[2]==0)?2 : (board[2]==1 && board[8]==1 && board[5]==0)?5 : (board[2]==1 && board[5]==1 && board[8]==0)?8 : 
        (board[4]==1 && board[8]==1 && board[0]==0)?0 : (board[0]==1 && board[8]==1 && board[4]==0)?4 : (board[0]==1 && board[4]==1 && board[8]==0)?8 : 
        (board[4]==1 && board[6]==1 && board[2]==0)?2 : (board[2]==1 && board[6]==1 && board[4]==0)?4 : (board[2]==1 && board[4]==1 && board[6]==0)?6 : 9;

    wire [3:0] cpu_target = (block_targ != 9) ? block_targ : (board[4] == 0) ? 4 :
                            (board[0]==0)?0 : (board[1]==0)?1 : (board[2]==0)?2 : 
                            (board[3]==0)?3 : (board[5]==0)?5 : (board[6]==0)?6 :
                            (board[7]==0)?7 : (board[8]==0)?8 : 9;

    // --- 5. State Machine & Animation ---
    reg [9:0] anim_count = 0;
    integer i;
    
    always @(posedge pclk) begin
        if (~KEY[2]) begin // Hard Reset
            for(i=0; i<9; i=i+1) board[i] <= 0;
            turn <= 0; p1_score <= 0; p2_score <= 0; score_updated <= 0; anim_count <= 0;
        end else if (~KEY[0]) begin // Soft Reset
            for(i=0; i<9; i=i+1) board[i] <= 0;
            turn <= 0; score_updated <= 0; anim_count <= 0;
        end else if (game_over) begin
            if (!score_updated) begin
                if (win_1) p1_score <= p1_score + 1;
                if (win_2) p2_score <= p2_score + 1;
                score_updated <= 1;
            end
            if (h_count == 0 && v_count == V_MAX - 1 && anim_count < 800) anim_count <= anim_count + 15;
        end else begin
            if (human_press && sw_sel != 9 && board[sw_sel] == 0) begin
                board[sw_sel] <= (turn == 0) ? 1 : 2; turn <= ~turn; 
            end else if (cpu_press && cpu_target != 9) begin
                board[cpu_target] <= (turn == 0) ? 1 : 2; turn <= ~turn; 
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
    
    assign HEX5 = seg7(p1_score); assign HEX4 = 7'b1111111; assign HEX3 = 7'b0111111;
    assign HEX2 = 7'b0111111;     assign HEX1 = 7'b1111111; assign HEX0 = seg7(p2_score);

    // --- 7. Geometry Math ---
    wire [1:0] col = (h_count < 213) ? 0 : (h_count < 427) ? 1 : 2;
    wire [1:0] row = (v_count < 160) ? 0 : (v_count < 320) ? 1 : 2;
    wire [3:0] cell_idx = (row * 3) + col;
    
    wire [7:0] x_local = h_count - (col * 213);
    wire [7:0] y_local = v_count - (row * 160);

    wire is_grid = (h_count>211 && h_count<215) || (h_count>425 && h_count<429) || 
                   (v_count>158 && v_count<162) || (v_count>318 && v_count<322);

    wire x_d1 = (x_local>y_local)?(x_local-y_local<8):(y_local-x_local<8);
    wire x_d2 = (x_local+y_local>185) && (x_local+y_local<200);
    wire is_X = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_d1 || x_d2);
    wire is_O = (x_local>50 && x_local<160 && y_local>30 && y_local<130) && (x_local<60 || x_local>150 || y_local<40 || y_local>120);

    // Win Line Math
    wire signed [12:0] diff1 = (v_count * 4) - (h_count * 3); 
    wire signed [12:0] diff2 = (v_count * 4) - ((640 - h_count) * 3);  
    wire anim_on = (w_c0 || w_c1 || w_c2) ? (v_count < anim_count) : (h_count < anim_count);
    
    wire draw_win_line = game_over && anim_on && (
        (w_r0 && v_count>75 && v_count<85)   || (w_r1 && v_count>235 && v_count<245) || (w_r2 && v_count>395 && v_count<405) ||
        (w_c0 && h_count>101 && h_count<111) || (w_c1 && h_count>315 && h_count<325) || (w_c2 && h_count>528 && h_count<538) ||
        (w_d1 && diff1 > -25 && diff1 < 25)  || (w_d2 && diff2 > -25 && diff2 < 25)
    );

    // --- 8. Text & Watermark ---
    wire in_txt = (v_count >= 200 && v_count <= 260); wire [9:0] dy = v_count - 200; 
    wire draw_text = in_txt && game_over && anim_count > 640 && (
        ((h_count>=160 && h_count<=200) && (h_count<170 || dy<10 || (dy>25&&dy<35) || (h_count>190&&dy<35))) || // P
        (win_1 && h_count>=230 && h_count<=240) || // 1
        (win_2 && (h_count>=210 && h_count<=250) && (dy<10 || (dy>25&&dy<35) || dy>50 || (h_count>240&&dy<35) || (h_count<220&&dy>25))) || // 2
        ((h_count>=280 && h_count<=330) && (h_count<290 || h_count>320 || dy>45 || (h_count>300&&h_count<310&&dy>20))) || // W
        (h_count>=340 && h_count<=350) || // I
        ((h_count>=360 && h_count<=400) && (h_count<370 || h_count>390 || (h_count-360 >= dy/2 && h_count-360 <= dy/2+15))) // N
    );

    wire in_wm = (v_count >= 460 && v_count <= 470); wire [4:0] uy = v_count - 460;
    wire draw_wm = in_wm && (
        (h_count>=10 && h_count<=15 && (h_count-10<2 || uy>8)) || // L
        (h_count>=18 && h_count<=23 && (h_count-18>3 || uy>8 || (uy>6 && h_count-18<2))) || // J
        (h_count>=26 && h_count<=31 && (h_count-26<2 || uy<2 || (uy>4&&uy<7) || (h_count-26>3&&uy<6) || (h_count-26==uy/2&&uy>4))) || // R
        (h_count>=34 && h_count<=39 && (h_count-34<2 || h_count-34>3 || uy>7 || (h_count-34==2&&uy>4))) || // W
        (h_count>=42 && h_count<=47 && (uy<2 || (uy>4&&uy<7) || uy>8 || (h_count-42>3&&uy<5) || (h_count-42<2&&uy>5))) || // 2
        (h_count>=50 && h_count<=55 && (h_count-50<2 || h_count-50>3 || uy<2 || uy>8)) || // 0
        (h_count>=58 && h_count<=63 && ((uy>3&&uy<7) || (h_count-58>1&&h_count-58<4))) || // +
        (h_count>=66 && h_count<=71 && (h_count-66<2 || uy<2 || (uy>4&&uy<7) || uy>8)) || // E
        (h_count>=74 && h_count<=79 && (h_count-74<2 || h_count-74>3 || (uy>3&&uy<7))) || // H
        (h_count>=82 && h_count<=87 && (uy<2 || (uy>4&&uy<7) || uy>8 || (h_count-82>3&&uy<5) || (h_count-82<2&&uy>5))) || // 2
        (h_count>=90 && h_count<=95 && (uy<2 || (uy>4&&uy<7) || uy>8 || h_count-90>3)) || // 3
        (h_count>=98 && h_count<=103&& (uy<2 || (uy>4&&uy<7) || uy>8 || (h_count-98>3&&uy<5) || (h_count-98<2&&uy>5))) || // 2
        (h_count>=106&& h_count<=111&& ((h_count-106>1&&h_count-106<4) || uy>8 || (h_count-106<3&&uy<3))) // 1
    );

    // --- 9. Rendering Pipeline ---
    wire [1:0] state = board[cell_idx];
    wire is_prev = (state == 0 && sw_sel == cell_idx && !game_over);
    wire draw_shape = (state == 1) ? is_X : (state == 2) ? is_O : (is_prev ? ((turn==0)?is_X:is_O) : 1'b0);

    reg [23:0] rgb;
    always @(*) begin
        if (!video_on) rgb = 24'h000000;
        else if (draw_wm) rgb = 24'hAAAAAA; 
        else if (draw_text) rgb = 24'hFFFFFF;  
        else if (game_over && in_txt && anim_count > 640) rgb = 24'h000000; 
        else if (draw_win_line) rgb = 24'hFFFF00; 
        else if (is_grid) rgb = 24'hFFFFFF;
        else if (draw_shape) begin
            if (is_prev) rgb = 24'h0000FF;         
            else if (state==1) rgb = 24'hFF0000; 
            else rgb = 24'h00FF00;                    
        end else rgb = 24'h000000;
    end
    
    assign {VGA_R, VGA_G, VGA_B} = rgb;

endmodule
