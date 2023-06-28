module finalproject(Clk, Reset, clk_PS2, PS2_Data, Switch_0, Button, hSync, vSync, vga_r, vga_g, vga_b, LED, left_segment, right_segment, left_enable, right_enable);
input Switch_0;
input Clk, Reset, clk_PS2;
input [2:0] Button; // left, jump, right
input PS2_Data;
output hSync, vSync; // VGA_hsync & VGA_vsync
output [3:0]vga_r, vga_g, vga_b;
output reg [15:0]LED;
output [7:0]left_segment, right_segment;
output [3:0]left_enable, right_enable;
wire pclk;
wire [9:0]h_cnt, v_cnt;
wire dataValid;
wire [11:0]rom_dout[4:0];
wire [7:0]PS2_DATA_value;
reg [13:0]rom_addr[4:0]; // 160*80 = 12800
reg [11:0]vga_data;
reg [2:0]cur_state, next_state;
reg [3:0]right_step_dec, left_step_dec;
reg [3:0]right_step_digit, left_step_digit;
reg fight_kirby_bool;

wire clk_1HZ, clk_2HZ, clk_debounce;
wire [1:0]clk_seg;
reg Goleft, Goright, Jump;
wire buttonGoleft, buttonGoright, buttonJump;
wire keyboardGoleft, keyboardGoright, keyboardJump;
wire key_state;
reg go_up_or_down_bool;//1?????W 0???U
reg level_1_bool;
reg [3:0]count_down_60_dec, count_down_60_digit, count_down_30_dec, count_down_30_digit;
reg [2:0]killcount;
reg [10:0]left_bound;
wire fall_bool_level_1,fall_bool_level_2;
reg [10:0]kirby_x, kirby_y, next_kirby_x, next_kirby_y, waddle_x, waddle_y,
monster_x[1:0], monster_y[1:0], next_monster_y[1:0], meta_x[2:0], meta_y[2:0];    
wire kirby_area, waddle;
wire meta_area[2:0];
wire monster_area[1:0];
wire [3:0]brick_area;
parameter kirby_length = 80, kirby_height= 80;
parameter meta_length = 80, meta_height = 80;
parameter monster_length = 80, monster_height= 80;
parameter waddle_length = 80, waddle_height= 160;
parameter Level1_Move = 3'b000, Win = 3'b001, Die = 3'b010, Level2_Move = 3'b011, Level2_fight_kirby = 3'b100; 

dcm_25M U0(.clk_in1(Clk), .clk_out1(pclk), .reset(!Reset));
kirby_rom up0(.clka(pclk), .addra(rom_addr[0]), .douta(rom_dout[0]));
meta_rom up1(.clka(pclk), .addra(rom_addr[1]), .douta(rom_dout[1]));
monster_rom up2(.clka(pclk), .addra(rom_addr[2]), .douta(rom_dout[2]));
waddle_rom up3(.clka(pclk), .addra(rom_addr[3]), .douta(rom_dout[3]));
fight_kirby_rom up4(.clka(pclk), .addra(rom_addr[4]), .douta(rom_dout[4]));

SyncGeneration U1(.pclk(pclk),.reset(Reset),.hSync(hSync),.vSync(vSync),.dataValid(dataValid),.hDataCnt(h_cnt),.vDataCnt(v_cnt));
clk_divider U2(.Clk(Clk), .Reset(Reset), .clk_1HZ(clk_1HZ), .clk_2HZ(clk_2HZ), .clk_debounce(clk_debounce), .clk_seg(clk_seg));
debounce U3(.clk(clk_debounce), .Reset(Reset), .button(Button), .Goright(buttonGoright), .Goleft(buttonGoleft), .Jump(buttonJump));
SevenSegDisplay U4(.Clk(Clk), .clk_seg(clk_seg), .Reset(Reset), .level1_bool(level_1_bool), .left_step_dec(left_step_dec), .left_step_digit(left_step_digit), .right_step_dec(right_step_dec), 
.right_step_digit(right_step_digit), .killcount(killcount), .countdown_60_dec(count_down_60_dec), .countdown_60_digit(count_down_60_digit), .countdown_30_dec(count_down_30_dec), 
.countdown_30_digit(count_down_30_digit),.left_enable(left_enable), .right_enable(right_enable), .left_segment(left_segment), .right_segment(right_segment), .cur_state(cur_state));
fall_debounce_level_1 U5(.clk(clk_debounce), .Reset(Reset), .clk_1HZ(clk_1HZ), .fall_bool(fall_bool_level_1));
fall_debounce_level_2 U6(.clk(clk_debounce), .Reset(Reset), .clk_2HZ(clk_2HZ), .fall_bool(fall_bool_level_2));
Keyboard_PS2 U7(.CLK100M(Clk), .Reset(Reset), .PS2CLK(clk_PS2), .PS2_Data(PS2_Data), .KeyState(key_state), .PS2_DATA_value(PS2_DATA_value));
PS2debounce U8(.clk(clk_debounce), .Reset(Reset), .keystate(key_state), .PS2DATA(PS2_DATA_value), .Goright(keyboardGoright), .Goleft(keyboardGoleft), .Jump(keyboardJump));


//-------------------------------------------------
reg [2:0]meta_killed_bool;
reg [1:0]monster_killed_bool;
reg [2:0]meta_sucked_bool;
reg [1:0]monster_sucked_bool;

assign kirby_area = ((v_cnt >= kirby_y) & (v_cnt <= kirby_y + kirby_height - 1) & (h_cnt+left_bound>= kirby_x) & (h_cnt+left_bound <= kirby_x + kirby_length - 1)) ? 1'b1 : 1'b0;
assign waddle_area = ((v_cnt >= waddle_y) & (v_cnt <= waddle_y + waddle_height - 1) & (h_cnt+left_bound >= waddle_x) & (h_cnt+left_bound <= waddle_x + waddle_length - 1)) ? 1'b1 : 1'b0;
assign monster_area[0] = ((v_cnt >= monster_y[0]) & (v_cnt <= monster_y[0] + monster_height - 1) & (h_cnt+left_bound >= monster_x[0]) & (h_cnt+left_bound <= monster_x[0] + monster_length - 1)&(monster_killed_bool[0]==1'b0)&(monster_sucked_bool[0]==1'b0)) ? 1'b1 : 1'b0;
assign monster_area[1] = ((v_cnt >= monster_y[1]) & (v_cnt <= monster_y[1] + monster_height - 1) & (h_cnt+left_bound >= monster_x[1]) & (h_cnt+left_bound <= monster_x[1] + monster_length - 1)&(monster_killed_bool[1]==1'b0)&(monster_sucked_bool[1]==1'b0)) ? 1'b1 : 1'b0;
assign meta_area[0] = ((v_cnt >= meta_y[0]) & (v_cnt <= meta_y[0] + meta_height - 1) & (h_cnt+left_bound >= meta_x[0]) & (h_cnt+left_bound <= meta_x[0] + meta_length - 1)&(meta_killed_bool[0]==1'b0)&(meta_sucked_bool[0]==1'b0)) ? 1'b1 : 1'b0;
assign meta_area[1] = ((v_cnt >= meta_y[1]) & (v_cnt <= meta_y[1] + meta_height - 1) & (h_cnt+left_bound >= meta_x[1]) & (h_cnt+left_bound <= meta_x[1] + meta_length - 1)&(meta_killed_bool[1]==1'b0)&(meta_sucked_bool[1]==1'b0)) ? 1'b1 : 1'b0;
assign meta_area[2] = ((v_cnt >= meta_y[2]) & (v_cnt <= meta_y[2] + meta_height - 1) & (h_cnt+left_bound >= meta_x[2]) & (h_cnt+left_bound <= meta_x[2] + meta_length - 1)&(meta_killed_bool[2]==1'b0)&(meta_sucked_bool[2]==1'b0)) ? 1'b1 : 1'b0;
assign brick_area[3] = ((h_cnt+left_bound >= 11'd1040) && (h_cnt+left_bound <= 11'd1120) && (v_cnt >= 11'd320) && (v_cnt <= 11'd400)) ? 1'b1 : 1'b0;//stair
assign brick_area[2] = ((h_cnt+left_bound >= 11'd640) && (h_cnt+left_bound <= 11'd800) && (v_cnt >= 11'd240) && (v_cnt <= 11'd320)) ? 1'b1 : 1'b0;//stair
assign brick_area[1] = ((h_cnt >= 11'd0) && (h_cnt <= 11'd640) && (v_cnt >= 11'd400) && (v_cnt <= 11'd480)) ? 1'b1 : 1'b0;
assign brick_area[0] = ((h_cnt+left_bound >= 11'd80) && (h_cnt+left_bound <= 11'd240) && (v_cnt >= 11'd240) && (v_cnt <= 11'd320)) ? 1'b1 : 1'b0;//stair
//-------------------------------------------------

always @(posedge pclk or negedge Reset) begin: display
    if (!Reset) begin
        rom_addr[0] <= 14'd0;
        rom_addr[1] <= 14'd0;
        rom_addr[2] <= 14'd0;
        rom_addr[3] <= 14'd0;
        rom_addr[4] <= 14'd0;
        vga_data <= 12'd0;
    end
    else begin
        if(dataValid == 1'b1) begin
            if(((v_cnt >= 10'd79 && v_cnt <= 10'd81) || (v_cnt >= 10'd159 && v_cnt <= 10'd161) || (v_cnt >= 10'd239 && v_cnt <= 10'd241) || 
            (v_cnt >= 10'd319 && v_cnt <= 10'd321) || (v_cnt >= 10'd399 && v_cnt <= 10'd401)) && (h_cnt[3:0] < 4'd10))
                vga_data <= 12'h000;
            else if(((h_cnt >= 10'd79 && h_cnt <= 10'd81) || (h_cnt >= 10'd159 && h_cnt <= 10'd161) || (h_cnt >= 10'd239 && h_cnt <= 10'd241) || 
            (h_cnt >= 10'd319 && h_cnt <= 10'd321) || (h_cnt >= 10'd399 && h_cnt <= 10'd401) || (h_cnt >= 10'd479 && h_cnt <= 10'd481) || (h_cnt >= 10'd559 && h_cnt <= 10'd561)) && 
            (v_cnt[3:0] < 4'd10))
                vga_data <= 12'h000;
            else if(kirby_area == 1'b1 && !(cur_state == Die)) begin
                if(fight_kirby_bool)begin
                    rom_addr[4] <= (v_cnt - kirby_y) * kirby_length + (h_cnt - kirby_x + left_bound);
                    vga_data <= rom_dout[4];
                end
                else begin
                    rom_addr[0] <= (v_cnt - kirby_y) * kirby_length + (h_cnt - kirby_x + left_bound);
                    vga_data <= rom_dout[0];
                end
            end
            else if (waddle_area == 1'b1) begin
                rom_addr[3] <= (v_cnt - waddle_y) * waddle_length + (h_cnt - waddle_x + left_bound);
                vga_data <= rom_dout[3];
            end
            else if(monster_area[0] == 1'b1) begin
                rom_addr[2] <= (v_cnt - monster_y[0]) * monster_length + (h_cnt - monster_x[0] + left_bound);
                vga_data <= rom_dout[2];
            end
            else if(monster_area[1] == 1'b1) begin
                rom_addr[2] <= (v_cnt - monster_y[1]) * monster_length + (h_cnt - monster_x[1] + left_bound);
                vga_data <= rom_dout[2];
            end
            else if(meta_area[0] == 1'b1) begin
                rom_addr[1] <= (v_cnt - meta_y[0]) * meta_length + (h_cnt - meta_x[0] + left_bound);
                vga_data <= rom_dout[1];
            end
            else if(meta_area[1] == 1'b1) begin
                rom_addr[1] <= (v_cnt - meta_y[1]) * meta_length + (h_cnt - meta_x[1] + left_bound);
                vga_data <= rom_dout[1];
            end
            else if(meta_area[2] == 1'b1) begin
                rom_addr[1] <= (v_cnt - meta_y[2]) * meta_length + (h_cnt - meta_x[2] + left_bound);
                vga_data <= rom_dout[1];
            end
            else if(brick_area[3]||brick_area[2]||brick_area[1]||brick_area[0])begin
                vga_data <=12'hf82;
                rom_addr[0] <= rom_addr[0];
                rom_addr[1] <= rom_addr[1];
                rom_addr[2] <= rom_addr[2];
                rom_addr[3] <= rom_addr[3];
                rom_addr[4] <= rom_addr[4];
            end
            else begin
                vga_data <= 12'hfff;
                rom_addr[0] <= rom_addr[0];
                rom_addr[1] <= rom_addr[1];
                rom_addr[2] <= rom_addr[2];
                rom_addr[3] <= rom_addr[3];
                rom_addr[4] <= rom_addr[4];
            end
        end
        else begin
            vga_data <= 12'h000;
            if (v_cnt == 0) begin
                rom_addr[0] <= 14'd0;
                rom_addr[1] <= 14'd0;
                rom_addr[2] <= 14'd0;
                rom_addr[3] <= 14'd0;
                rom_addr[4] <= 14'd0;
            end
            else begin
                rom_addr[0] <= rom_addr[0];
                rom_addr[1] <= rom_addr[1];
                rom_addr[2] <= rom_addr[2];
                rom_addr[3] <= rom_addr[3];
                rom_addr[4] <= rom_addr[4];
            end
        end
    end
end
assign {vga_r,vga_g,vga_b} = vga_data;

always@(posedge pclk or negedge Reset) begin
    if(!Reset) begin
        if(Switch_0==0)begin
            waddle_x <= 11'd560;
            waddle_y <= 11'd80;
            meta_x[0] <= 11'd160;meta_y[0] <= 11'd320;
            meta_x[1] <= 11'd640;meta_y[1] <= 11'd320;
            meta_x[2] <= 11'd880;meta_y[2] <= 11'd320;
        end
        else begin
            waddle_x <= 11'd1360;
            waddle_y <= 11'd80;
            meta_x[0] <= 11'd160;meta_y[0] <= 11'd320;
            meta_x[1] <= 11'd640;meta_y[1] <= 11'd320;
            meta_x[2] <= 11'd880;meta_y[2] <= 11'd320;
        end
    end
    else begin
        meta_x[0]<= meta_x[0];
        meta_x[1]<= meta_x[1];
        meta_x[2]<= meta_x[2];
        meta_y[0]<= meta_y[0];
        meta_y[1]<= meta_y[1];
        meta_y[2]<= meta_y[2];
        waddle_x <= waddle_x;
        waddle_y <= waddle_y;
    end
end
always@(*) begin
    case(cur_state)
        Level1_Move: begin
            if(buttonGoright) begin
                Goleft = 1'b0;
                Goright = 1'b1;
                Jump = 1'b0;
            end
            else if(buttonGoleft) begin
                Goleft = 1'b1;
                Goright = 1'b0;
                Jump = 1'b0;
            end
            else if(buttonJump) begin
                Goleft = 1'b0;
                Goright = 1'b0;
                Jump = 1'b1;
            end
            else begin
                Goleft = 1'b0;
                Goright = 1'b0;
                Jump = 1'b0;
            end
        end
        Win, Die: begin
            Goleft = 1'b0;
            Goright = 1'b0;
            Jump = 1'b0;    
        end
        Level2_Move, Level2_fight_kirby: begin
            if(keyboardGoright) begin
                Goleft = 1'b0;
                Goright = 1'b1;
                Jump = 1'b0;
                
            end
            else if(keyboardGoleft) begin
                Goleft = 1'b1;
                Goright = 1'b0;
                Jump = 1'b0;
            end
            else if(keyboardJump) begin
                Goleft = 1'b0;
                Goright = 1'b0;
                Jump = 1'b1;
            end
            else begin
                Goleft = 1'b0;
                Goright = 1'b0;
                Jump = 1'b0;
            end
        end
        default: begin
            Goleft = 1'b0;
            Goright = 1'b0;
            Jump = 1'b0;
        end    
    endcase
end
always@(posedge clk_debounce or negedge Reset) begin
    if(!Reset) begin
        kirby_x <= 11'd0;
        kirby_y <= 11'd320;
    end
    else begin
        kirby_x <= next_kirby_x;
        kirby_y <= next_kirby_y;
    end
end
//----- next_kirby_x---------------
always@(*) begin
    next_kirby_x = 11'd0;
    case(cur_state)
        Level1_Move: begin
            if(Goright == 1'b1 && kirby_x < 11'd560 &&!(kirby_x == 11'd0 && kirby_y == 11'd240)) begin
                    next_kirby_x = kirby_x + 11'd80;
            end
            else if(Goleft == 1'b1 && kirby_x> 11'd0&&!(kirby_x == 11'd240 && kirby_y == 11'd240)) begin
                    next_kirby_x = kirby_x - 11'd80;
            end
            else next_kirby_x = kirby_x;
        end
        Win, Die: begin
            next_kirby_x = kirby_x;
        end
        Level2_Move, Level2_fight_kirby: begin
            if(Goright == 1'b1 && kirby_x < 11'd1360 &&!(kirby_x == 11'd0 && kirby_y == 11'd240)&&!(kirby_x == 11'd560 && kirby_y == 11'd240)&&!(kirby_x == 11'd960 && kirby_y == 11'd320))
                    next_kirby_x = kirby_x + 11'd80;

            else if(Goleft == 1'b1 && kirby_x> left_bound &&!(kirby_x == 11'd240 && kirby_y == 11'd240)&&!(kirby_x == 11'd800 && kirby_y == 11'd240)&&!(kirby_x == 11'd1120 && kirby_y == 11'd320))
                    next_kirby_x = kirby_x - 11'd80;

            else next_kirby_x = kirby_x;
        end
    endcase
end

//----------next_kirby_y-------
reg on_ground_bool;
always@(*)begin
    if(kirby_y==11'd320)
        on_ground_bool = 1'b1;
    else if(((kirby_y==11'd160)&&(kirby_x == 11'd80||kirby_x == 11'd160))||(kirby_y==11'd160&&(kirby_x==11'd640||kirby_x==11'd720))||(kirby_y==11'd240&&kirby_x==11'd1040))
        on_ground_bool = 1'b1;
    else on_ground_bool = 1'b0;
end

always@(*) begin
    next_kirby_y = 11'd320;
    case(cur_state)
        Level1_Move: begin
            if((Jump == 1'b1)&&(kirby_y==11'd320)&&(kirby_x == 11'd80||kirby_x == 11'd160))//under the stair
                next_kirby_y = 11'd320;
            else if(Jump == 1'b1 &&kirby_y < 11'd240) // 跳起來撞到天花板
                next_kirby_y = 11'd0;
            else if(Jump == 1'b1 && kirby_y >=11'd240) // 完整跳起來
                next_kirby_y = kirby_y - 11'd240;
            else if(Jump == 1'b0&&on_ground_bool==1'b0&& fall_bool_level_1)
                next_kirby_y=kirby_y+11'd80;
            else next_kirby_y = kirby_y;
        end
        Win, Die: begin
            next_kirby_y = kirby_y;
        end
        Level2_Move, Level2_fight_kirby: begin
            if((Jump == 1'b1)&&(kirby_y==11'd320)&&(kirby_x == 11'd80||kirby_x == 11'd160))//???_?????stair
                next_kirby_y = 11'd320;
            else if((Jump == 1'b1)&&(kirby_y==11'd320)&&(kirby_x == 11'd640||kirby_x == 11'd720))//under the stair
                next_kirby_y = 11'd320;
            else if(Jump == 1'b1 &&kirby_y < 11'd240)
                next_kirby_y = 11'd0;
            else if(Jump == 1'b1 && kirby_y >=11'd240)
                next_kirby_y = kirby_y - 11'd240;
            else if(Jump == 1'b0&&on_ground_bool==1'b0&& fall_bool_level_2)
                next_kirby_y=kirby_y+11'd80;
            else next_kirby_y = kirby_y;
        end
    endcase
end
//----left_bound的賦值------

always@(posedge Clk,negedge Reset)begin
    if(!Reset)begin
        left_bound<=11'b0;
    end
    else if(cur_state==Level2_Move||cur_state==Level2_fight_kirby)begin
        if(next_kirby_x==11'd1280)
            left_bound<=left_bound;
        else if(next_kirby_x==left_bound+11'd480)
            left_bound<=left_bound+11'd80;
        else left_bound<=left_bound;
    end
    else left_bound<=left_bound;
end

always@(posedge clk_debounce or negedge Reset) begin
    if(!Reset) begin
        left_step_dec <= 4'b0000;
        right_step_dec <= 4'b0000;
        left_step_digit <= 4'b0000;
        right_step_digit <= 4'b0000;
    end
    else begin
        if(Goright == 1'b1 && (cur_state == Level1_Move || cur_state == Level2_Move || cur_state == Level2_fight_kirby)) begin
            left_step_dec <= left_step_dec;
            left_step_digit <= left_step_digit;
            if(right_step_digit < 4'd9) begin
                right_step_dec <= right_step_dec;
                right_step_digit <= right_step_digit + 1'b1;
            end
            else if(right_step_dec < 4'd9) begin
                right_step_dec <= right_step_dec + 1'b1;
                right_step_digit <= 4'b0000;
            end
            else begin
                right_step_dec <= 4'b0000;
                right_step_digit <= 4'b0000;
            end
        end
        else if(Goleft == 1'b1 && (cur_state == Level1_Move || cur_state == Level2_Move || cur_state == Level2_fight_kirby)) begin
            if(left_step_digit < 4'd9) begin
                left_step_dec <= left_step_dec;
                left_step_digit <= left_step_digit + 1'b1;
            end
            else if(left_step_dec < 4'd9) begin
                left_step_dec <= left_step_dec + 1'b1;
                left_step_digit <= 4'b0000;
            end
            else begin
                left_step_dec <= 4'b0000;
                left_step_digit <= 4'b0000;
            end
            right_step_dec <= right_step_dec;
            right_step_digit <= right_step_digit;
        end
        else begin
            left_step_dec <= left_step_dec;
            left_step_digit <= left_step_digit;
            right_step_dec <= right_step_dec;
            right_step_digit <= right_step_digit;
        end    
    end
end

//--------monster??m?B?z--------------
always@(posedge clk_1HZ or negedge Reset)begin
    if(!Reset)begin
        monster_x[0] <= 11'd480;
        monster_y[0] <= 11'd320;
        monster_x[1] <= 11'd1200;
        monster_y[1] <= 11'd320;
    end
    else begin
        monster_x[0] <=monster_x[0];
        monster_y[0] <=next_monster_y[0];
        monster_x[1] <=monster_x[1];
        monster_y[1] <=next_monster_y[1];
    end
end

always@(posedge clk_1HZ or negedge Reset)begin // go_up_or_down_bool =1 ???W, go_up_or_down_bool =0 ???U
    if(!Reset)begin
        go_up_or_down_bool<=1;
    end
    else begin
        if(monster_y[0] == 11'd0) go_up_or_down_bool <= 0;
        else if(monster_y[0] == 11'd320) go_up_or_down_bool <= 1;
        else go_up_or_down_bool<=go_up_or_down_bool;
    end
end

//----monster---state---------
always@(*)begin
    if(cur_state==Level1_Move||cur_state==Level2_Move||cur_state==Level2_fight_kirby)begin
        if((monster_y[0]==11'd0)||(monster_y[0]==11'd320))begin
            next_monster_y[0]=11'd160;
        end
        else if((monster_y[0]==11'd160)&&(go_up_or_down_bool==0))begin 
            next_monster_y[0]=11'd320;
        end
        else if((monster_y[0]==11'd160)&&(go_up_or_down_bool==1))begin 
            next_monster_y[0]=11'd0;
        end
        else next_monster_y[0]=monster_y[0];
    end
    else next_monster_y[0]=monster_y[0];
end

always@(*)begin
    if(cur_state==Level1_Move||cur_state==Level2_Move||cur_state==Level2_fight_kirby)begin
        if((monster_y[1]==11'd0)||(monster_y[1]==11'd320))begin
            next_monster_y[1]=11'd160;
        end
        else if((monster_y[1]==11'd160)&&(go_up_or_down_bool==0))begin 
            next_monster_y[1]=11'd320;
        end
        else if((monster_y[1]==11'd160)&&(go_up_or_down_bool==1))begin 
            next_monster_y[1]=11'd0;
        end
        else next_monster_y[1]=monster_y[1];
    end
    else next_monster_y[1]=monster_y[1];
end
//-------------------------------------
//-------------------------

always@(posedge clk_1HZ or negedge Reset)begin
    if(!Reset)begin
        count_down_60_dec<=4'd6;
        count_down_60_digit<=4'd0;
    end
    else if(cur_state==Level2_Move || cur_state==Level2_fight_kirby)begin
        
        if(count_down_60_digit==4'd0&&count_down_60_dec>4'd0)begin
            count_down_60_digit<=4'd9;
            count_down_60_dec<=count_down_60_dec-1'd1;
        end
        //?w?g??00
        else if(count_down_60_digit==4'd0&&count_down_60_dec==4'd0)begin
            count_down_60_digit<=count_down_60_digit;
            count_down_60_dec<=count_down_60_dec;
        end
        else begin
            count_down_60_digit<=count_down_60_digit-1'd1;
            count_down_60_dec<=count_down_60_dec;
        end
    end
    else begin
        count_down_60_digit<=count_down_60_digit;
        count_down_60_dec<=count_down_60_dec;
    end
end

always@(posedge clk_1HZ or negedge Reset)begin
    if(!Reset)begin
        count_down_30_dec<=4'd3;
        count_down_30_digit<=4'd0;
    end
    else if(cur_state==Level1_Move)begin
        if(count_down_30_digit==4'd0&&count_down_30_dec>4'd0)begin
            count_down_30_digit<=4'd9;
            count_down_30_dec<=count_down_30_dec-1'd1;
        end
        else if(count_down_30_digit==4'd0&&count_down_30_dec==4'd0)begin
            count_down_30_digit<=count_down_30_digit;
            count_down_30_dec<=count_down_30_dec;
        end
        else begin
            count_down_30_digit<=count_down_30_digit-1'd1;
            count_down_30_dec<=count_down_30_dec;
        end
    end
    else begin
        count_down_30_digit<=count_down_30_digit;
        count_down_30_dec<=count_down_30_dec;
    end
end
//---------------------------------------------
reg level_1_LED_bool;
    //-------level1 LED---counter--------
always@(posedge clk_2HZ or negedge Reset)begin
    if(!Reset)begin
        level_1_LED_bool<=1;
    end
    else if(level_1_LED_bool==1)level_1_LED_bool<=0;
    else level_1_LED_bool<=1;
end
//-----------LED-------------
always@(posedge clk_2HZ or negedge Reset)begin
    if(!Reset)begin
        LED<=16'b0000_0000_0000_0000;
    end
    else if((cur_state==Win||cur_state==Die)&&(LED==16'b0))begin
        LED<=16'b1000_0000_0000_0000;
    end
    //level 2 case
    else if((level_1_bool==0)&&(cur_state==Die)&&(LED!=16'b1111_1111_1111_1111))begin
        LED<={1'b1,LED[15:1]};
    end
    else if((level_1_bool==0)&&(cur_state==Die)&&(LED==16'b1111_1111_1111_1111))begin
        LED<=16'b1000_0000_0000_0000;
    end
    else if((level_1_bool==0)&&(cur_state==Win)&&(LED!=16'b0000_0000_0000_0001))begin
        LED<={1'b0,LED[15:1]};
    end
    else if((level_1_bool==0)&&(cur_state==Win)&&(LED==16'b0000_0000_0000_0001))begin
        LED<=16'b1000_0000_0000_0000;
    end

    //level 1 case
    else if((level_1_bool==1)&&(cur_state==Die)&&(LED!=16'b1111_1111_1111_1111)&&level_1_LED_bool)begin
        LED<={1'b1,LED[15:1]};
    end
    else if((level_1_bool==1)&&(cur_state==Die)&&(LED==16'b1111_1111_1111_1111)&&level_1_LED_bool)begin
        LED<=16'b1000_0000_0000_0000;
    end
    else if((level_1_bool==1)&&(cur_state==Win)&&(LED!=16'b0000_0000_0000_0001)&&level_1_LED_bool)begin
        LED<={1'b0,LED[15:1]};
    end
    else if((level_1_bool==1)&&(cur_state==Win)&&(LED==16'b0000_0000_0000_0001)&&level_1_LED_bool)begin
        LED<=16'b1000_0000_0000_0000;
    end
    else LED<=LED;
end

//---------------------------------
reg transform_bool;
always@(posedge Clk or negedge Reset)begin
    if(!Reset)begin
        meta_killed_bool<=3'b0;
        monster_killed_bool<=2'b0;
        killcount <= 3'b000;
    end
    else if(cur_state == Level2_fight_kirby)begin
        if((kirby_y==monster_y[0])&&(kirby_x+11'd80==monster_x[0])&&(PS2_DATA_value == "K")&&(key_state == 1'b1)&&(monster_killed_bool[0]==1'b0))begin
            monster_killed_bool[0]<=1'b1;
            monster_killed_bool[1]<=monster_killed_bool[1];
            killcount <= killcount + 1'b1;
            meta_killed_bool<=meta_killed_bool;
        end
        else if((kirby_y==monster_y[1])&&(kirby_x+11'd80==monster_x[1])&&(PS2_DATA_value == "K")&&(key_state == 1'b1)&&(monster_killed_bool[1]==1'b0))begin
            monster_killed_bool[1]<=1'b1;
            monster_killed_bool[0]<=monster_killed_bool[0];
            killcount <= killcount + 1'b1;
            meta_killed_bool<=meta_killed_bool;
        end
        //--------------------------------
        else if((kirby_y==meta_y[0])&&(kirby_x+11'd80==meta_x[0])&&(PS2_DATA_value == "K")&&(key_state == 1'b1)&&(meta_killed_bool[0]==1'b0))begin
            meta_killed_bool[0]<=1'b1;
            meta_killed_bool[1]<=meta_killed_bool[1];
            meta_killed_bool[2]<=meta_killed_bool[2];
            killcount <= killcount + 1'b1;
            monster_killed_bool<=monster_killed_bool;
        end
        else if((kirby_y==meta_y[1])&&(kirby_x+11'd80==meta_x[1])&&(PS2_DATA_value == "K")&&(key_state == 1'b1)&&(meta_killed_bool[1]==1'b0))begin
            meta_killed_bool[1]<=1'b1;
            meta_killed_bool[0]<=meta_killed_bool[0];
            meta_killed_bool[2]<=meta_killed_bool[2];
            killcount <= killcount + 1'b1;
            monster_killed_bool<=monster_killed_bool;
        end
        else if((kirby_y==meta_y[2])&&(kirby_x+11'd80==meta_x[2])&&(PS2_DATA_value == "K")&&(key_state == 1'b1)&&(meta_killed_bool[2]==1'b0))begin
            meta_killed_bool[2]<=1'b1;
            meta_killed_bool[1]<=meta_killed_bool[1];
            meta_killed_bool[0]<=meta_killed_bool[0];
            killcount <= killcount + 1'b1;
            monster_killed_bool<=monster_killed_bool;
        end
        //--------------------------------------------
        else begin
            killcount <= killcount;
            meta_killed_bool<=meta_killed_bool;
            monster_killed_bool<=monster_killed_bool;
        end
    end
    else begin
        killcount <= killcount;
        meta_killed_bool<=meta_killed_bool;
        monster_killed_bool<=monster_killed_bool;
    end
end    

//-----吸怪物----------
always@(posedge Clk or negedge Reset)begin
    if(!Reset)begin 
        transform_bool<=1'b0;
        meta_sucked_bool<=3'b0;
        monster_sucked_bool<=2'b0;
    end
    else  if((PS2_DATA_value == "J")&&cur_state == Level2_Move)begin
        //吸到meta才會變身
        if((kirby_x+11'd80==meta_x[0])&&(kirby_y==meta_y[0]))begin
            transform_bool<=1'b1;
            meta_sucked_bool[0]<=1'b1;
            meta_sucked_bool[1]<=meta_sucked_bool[1];
            meta_sucked_bool[2]<=meta_sucked_bool[2];
            monster_sucked_bool<=monster_sucked_bool;
        end
        else if((kirby_x+11'd80==meta_x[1])&&(kirby_y==meta_y[1]))begin
            transform_bool<=1'b1;
            meta_sucked_bool[1]<=1'b1;
            meta_sucked_bool[0]<=meta_sucked_bool[0];
            meta_sucked_bool[2]<=meta_sucked_bool[2];
            monster_sucked_bool<=monster_sucked_bool;
        end
        else if((kirby_x+11'd80==meta_x[2])&&(kirby_y==meta_y[2]))begin
            transform_bool<=1'b1;
            meta_sucked_bool[2]<=1'b1;
            meta_sucked_bool[1]<=meta_sucked_bool[1];
            meta_sucked_bool[0]<=meta_sucked_bool[0];
            monster_sucked_bool<=monster_sucked_bool;
        end
        //---------------------------------------------------
        else if((kirby_x+11'd80==monster_x[0])&&(kirby_y==monster_y[0]))begin
            transform_bool<=1'b0;
            monster_sucked_bool[0]<=1'b1;
            monster_sucked_bool[1]<=monster_sucked_bool[1];
            meta_sucked_bool<=meta_sucked_bool;
        end
        else if((kirby_x+11'd80==monster_x[1])&&(kirby_y==monster_y[1]))begin
            transform_bool<=1'b0;
            monster_sucked_bool[1]<=1'b1;
            monster_sucked_bool[0]<=monster_sucked_bool[0];
            meta_sucked_bool<=meta_sucked_bool;
        end
        else begin
            transform_bool<=transform_bool;
            monster_sucked_bool<=monster_sucked_bool;
            meta_sucked_bool<=meta_sucked_bool;
        end
    end
    else begin 
        transform_bool<=transform_bool;
        monster_sucked_bool<=monster_sucked_bool;
        meta_sucked_bool<=meta_sucked_bool;
    end
end

//-------next state register-----------
always@(posedge Clk,negedge Reset)begin//next state register
    if(!Reset)  begin if(Switch_0==0) begin level_1_bool <= 1'b1; cur_state<= Level1_Move; end
        else begin level_1_bool <= 1'b0; cur_state<= Level2_Move; end
    end
    else cur_state<=next_state;
end

//----next state logic--------------------------
reg Die_bool,Win_bool;

    //Die_bool
always@(*)begin
    if(kirby_area&&monster_area[0])Die_bool=1;
    else if(kirby_area&&monster_area[1])Die_bool=1;
    else if(monster_killed_bool[0]==1'b0&&kirby_x == 11'd480 && kirby_y == 11'd80 && ((monster_y[0] == 11'd160 && go_up_or_down_bool && clk_1HZ) || (monster_y[0] == 11'd0 && !go_up_or_down_bool && clk_1HZ)))Die_bool=1;
    else if(monster_killed_bool[0]==1'b0&&kirby_x == 11'd480 && kirby_y == 11'd240 && ((monster_y[0] == 11'd160 && !go_up_or_down_bool && clk_1HZ) || (monster_y[0] == 11'd0 && go_up_or_down_bool && clk_1HZ)))Die_bool=1;
    else if(monster_killed_bool[1]==1'b0&&kirby_x == 11'd1200 && kirby_y == 11'd80 && ((monster_y[1] == 11'd160 && go_up_or_down_bool && clk_1HZ) || (monster_y[1] == 11'd0 && !go_up_or_down_bool && clk_1HZ)))Die_bool=1;
    else if(monster_killed_bool[1]==1'b0&&kirby_x == 11'd1200 && kirby_y == 11'd240 && ((monster_y[1] == 11'd160 && !go_up_or_down_bool && clk_1HZ) || (monster_y[1] == 11'd0 && go_up_or_down_bool && clk_1HZ)))Die_bool=1;
    //--------------------------------------------------------------------------
    else if(kirby_area&&meta_area[0])Die_bool=1;
    else if(kirby_area&&meta_area[1])Die_bool=1;
    else if(kirby_area&&meta_area[2])Die_bool=1;
    //-----------------------------------------
    else if(level_1_bool==1&&(count_down_30_digit==4'd0)&&(count_down_30_dec==4'd0))Die_bool=1;
    else if(level_1_bool==0&&(count_down_60_digit==4'd0)&&(count_down_60_dec==4'd0))Die_bool=1;
    else Die_bool=0;
end
    //win_bool
always@(*)begin
    if(kirby_area&&waddle_area)Win_bool=1;
    else Win_bool=0;
end

always@(*)begin
    case(cur_state)
        Level1_Move:begin
            if(Die_bool)next_state=Die;
            else if(Win_bool)next_state=Win;
            else next_state=Level1_Move;
        end 
        Win:next_state=Win;

        Die:next_state=Die;

        Level2_Move:begin
            if(Die_bool)next_state=Die;
            else if(Win_bool)next_state=Win;
            else if(transform_bool)next_state=Level2_fight_kirby;
            else next_state=Level2_Move;
        end

        Level2_fight_kirby:begin
            if(Die_bool)next_state=Die;
            else if(Win_bool)next_state=Win;
            else next_state=Level2_fight_kirby;
        end 
        default:next_state=Level1_Move;
    endcase
end
//---例外處理fight kirby------------
always@(posedge Clk,negedge Reset)begin
    if(!Reset) fight_kirby_bool<=1'b0;
    else if(cur_state==Level2_fight_kirby)fight_kirby_bool<=1'b1;
    else fight_kirby_bool<=fight_kirby_bool;
end
endmodule

//syncgeneration
module SyncGeneration(pclk, reset, hSync, vSync, dataValid, hDataCnt, vDataCnt);
input pclk;
input reset;
output hSync;
output vSync;
output dataValid;
output [9:0] hDataCnt;
output [9:0] vDataCnt;

parameter H_SP_END = 96;
parameter H_BP_END = 144;
parameter H_FP_START = 785;
parameter H_TOTAL = 800;

parameter V_SP_END = 2;
parameter V_BP_END = 35;
parameter V_FP_START = 516;
parameter V_TOTAL= 525;
reg [9:0] x_cnt, y_cnt;
wire h_valid, y_valid;

always @(posedge pclk or negedge reset) begin
    if (!reset)
        x_cnt <= 10'd1;
    else begin
        if (x_cnt == H_TOTAL) // horizontal 
            x_cnt <= 10'd1; // retracing
        else
            x_cnt <= x_cnt + 1'b1;
    end
end
always @(posedge pclk or negedge reset) begin
    if (!reset)
        y_cnt <= 10'd1;
    else begin
        if (y_cnt == V_TOTAL & x_cnt == H_TOTAL)
            y_cnt <= 1; // vertical retracing
        else if (x_cnt == H_TOTAL)
            y_cnt <= y_cnt + 1;
        else 
            y_cnt<=y_cnt;
    end
end

assign hSync = ((x_cnt > H_SP_END)) ? 1'b1 : 1'b0;
assign vSync = ((y_cnt > V_SP_END)) ? 1'b1 : 1'b0;
// Check P7 for horizontal timing
assign h_valid = ((x_cnt > H_BP_END) & (x_cnt < H_FP_START)) ? 1'b1 : 1'b0;
// Check P9 for vertical timing
assign v_valid = ((y_cnt > V_BP_END) & (y_cnt < V_FP_START)) ? 1'b1 : 1'b0;
assign dataValid = ((h_valid == 1'b1) & (v_valid == 1'b1)) ? 1'b1 : 1'b0;
// hDataCnt from 1 if h_valid==1
assign hDataCnt = ((h_valid == 1'b1)) ? x_cnt - H_BP_END : 10'b0;
// vDataCnt from 1 if v_valid==1
assign vDataCnt = ((v_valid == 1'b1)) ? y_cnt - V_BP_END : 10'b0;
endmodule

module debounce( 
input clk,
input Reset,
input [2:0]button,
output Goright,
output Goleft,
output Jump
);
reg [2:0]q1, q2, q3;
always @ (posedge clk or negedge Reset) begin
    if(!Reset) begin
        q1 <= 3'b000;
        q2 <= 3'b000;
        q3 <= 3'b000;
    end
    else begin
        q1 <= button;
        q2 <= q1;
        q3 <= q2;
    end
end
assign Goright = q1[0] & q2[0] & (!q3[0]); // right
assign Jump = q1[1] & q2[1] & (!q3[1]); // jump
assign Goleft = q1[2] & q2[2] & (!q3[2]); // left
endmodule

module fall_debounce_level_1( 
input clk,
input Reset,
input clk_1HZ,
output fall_bool
);
reg q1, q2, q3;
always @ (posedge clk or negedge Reset) begin
    if(!Reset) begin
        q1 <= 1'b0;
        q2 <= 1'b0;
        q3 <= 1'b0;
    end
    else begin
        q1 <= clk_1HZ;
        q2 <= q1;
        q3 <= q2;
    end
end
assign fall_bool = q1 & q2 & (!q3); // fall_bool
endmodule
//---------------------------------------------------------

module fall_debounce_level_2( 
input clk,
input Reset,
input clk_2HZ,
output fall_bool
);
reg q1, q2, q3;
always @ (posedge clk or negedge Reset) begin
    if(!Reset) begin
        q1 <= 1'b0;
        q2 <= 1'b0;
        q3 <= 1'b0;
    end
    else begin
        q1 <= clk_2HZ;
        q2 <= q1;
        q3 <= q2;
    end
end
assign fall_bool = q1 & q2 & (!q3); // fall_bool
endmodule
//--------------------------------------------------------------

module clk_divider(Clk,Reset,clk_1HZ,clk_2HZ,clk_debounce,clk_seg);
    input Clk,Reset;
    output [1:0]clk_seg;
    output clk_1HZ,clk_2HZ,clk_debounce;
    reg [27:0]count_27;
    always@(posedge Clk,negedge Reset)begin
        if(!Reset)count_27<=27'd0;
        else count_27<=count_27+1'd1;
    end
    assign clk_1HZ=count_27[26];
    assign clk_2HZ=count_27[25];
    assign clk_debounce=count_27[19];
    assign clk_seg=count_27[19:18];    
endmodule

module SevenSegDisplay(Clk, clk_seg, Reset, level1_bool, left_step_digit, left_step_dec, right_step_digit, right_step_dec, 
killcount, countdown_60_dec, countdown_60_digit, countdown_30_dec, countdown_30_digit, left_enable, right_enable, left_segment, right_segment, cur_state);
input Clk, Reset, level1_bool;
input [1:0]clk_seg;
input [2:0]cur_state, killcount;
input [3:0]left_step_digit, left_step_dec, right_step_digit, right_step_dec, countdown_60_dec, countdown_60_digit, countdown_30_dec, countdown_30_digit;
output reg[3:0]left_enable, right_enable;
output reg [7:0]left_segment, right_segment;
reg [3:0] left_letter, right_letter;
parameter Level1_Move = 3'b000, Win = 3'b001, Die = 3'b010, Level2_Move = 3'b011, Level2_fight_kirby = 3'b100; 
always@(posedge Clk or negedge Reset) begin
    if(!Reset) 
        left_enable <= 4'b0000;
    else begin
        case(clk_seg)
            2'b00: begin
                left_enable <= 4'b1000;
                right_enable <= 4'b1000;
            end
            2'b01: begin
                left_enable <= 4'b0100;
                right_enable <= 4'b0100;
            end
            2'b10: begin
                left_enable <= 4'b0010;
                right_enable <= 4'b0010;
            end
            2'b11: begin
                left_enable <= 4'b0001;
                right_enable <= 4'b0001;
            end
            default: begin
                left_enable <= 4'b0000;
                right_enable <= 4'b0000;
            end
        endcase
    end
end
always@(*) begin
    left_letter = 4'b0000;
    right_letter = 4'b0000;
    case(clk_seg)
        2'b00: begin
            left_letter = left_step_dec;
            if(level1_bool)
                right_letter = 4'b1010;
            else
                right_letter = 4'b0000;
            
        end
        2'b01: begin
            left_letter = left_step_digit;
            if(level1_bool)
                right_letter = 4'b1010;
            else
                right_letter = {1'b0, killcount};
        end
        2'b10: begin
            left_letter = right_step_dec;
            if(level1_bool) begin
                right_letter = countdown_30_dec;
            end
            else begin
                right_letter = countdown_60_dec;
            end
        end
        2'b11: begin
            left_letter = right_step_digit;
            if(level1_bool) begin
                right_letter = countdown_30_digit;
            end
            else begin
                right_letter = countdown_60_digit;
            end
            
        end
        default: begin
            left_letter = 4'b0000;
            right_letter = 4'b0000;
        end
    endcase
    left_segment = 8'b0000_0000;
    right_segment = 8'b0000_0000;
    case(left_letter)
        4'b0000: left_segment = 8'b1111_1100; // 0
        4'b0001: left_segment = 8'b0110_0000; // 1
        4'b0010: left_segment = 8'b1101_1010; // 2
        4'b0011: left_segment = 8'b1111_0010; // 3
        4'b0100: left_segment = 8'b0110_0110; // 4
        4'b0101: left_segment = 8'b1011_0110; // 5
        4'b0110: left_segment = 8'b1011_1110; // 6
        4'b0111: left_segment = 8'b1110_0100; // 7
        4'b1000: left_segment = 8'b1111_1110; // 8
        4'b1001: left_segment = 8'b1111_0110; // 9
        default: left_segment = 8'b0000_0000;
    endcase
    case(right_letter)
        4'b0000: right_segment = 8'b1111_1100; // 0
        4'b0001: right_segment = 8'b0110_0000; // 1
        4'b0010: right_segment = 8'b1101_1010; // 2
        4'b0011: right_segment = 8'b1111_0010; // 3
        4'b0100: right_segment = 8'b0110_0110; // 4
        4'b0101: right_segment = 8'b1011_0110; // 5
        4'b0110: right_segment = 8'b1011_1110; // 6
        4'b0111: right_segment = 8'b1110_0100; // 7
        4'b1000: right_segment = 8'b1111_1110; // 8
        4'b1001: right_segment = 8'b1111_0110; // 9
        default: right_segment = 8'b0000_0000;
    endcase
end
endmodule

module Keyboard_PS2(CLK100M, Reset, PS2CLK, PS2_Data, KeyState, PS2_DATA_value); // ps2 keyboard
input CLK100M, Reset, PS2CLK, PS2_Data;
output reg KeyState;
output reg [7:0]PS2_DATA_value;
reg PS2CLK_r0, PS2CLK_r1; 
reg Keydata_r0, Keydata_r1;
always @ (posedge CLK100M or negedge Reset) begin
    if(!Reset) begin
        PS2CLK_r0 <= 1'b1;
        PS2CLK_r1 <= 1'b1;
        Keydata_r0 <= 1'b1;
        Keydata_r1 <= 1'b1;
    end 
    else begin
        PS2CLK_r0 <= PS2CLK;
        PS2CLK_r1 <= PS2CLK_r0;
        Keydata_r0 <= PS2_Data;
        Keydata_r1 <= Keydata_r0;
    end
end
wire PS2CLK_neg = PS2CLK_r1 & (!PS2CLK_r0); // 1 & 0 
reg [3:0]counter; 
reg [7:0]temp_data;
always @ (posedge CLK100M or negedge Reset) begin
    if(!Reset) begin
        counter <= 4'd0;
        temp_data <= 8'd0;
    end
    else if(PS2CLK_neg) begin 
        if(counter >= 4'd10) 
            counter <= 4'd0;
        else 
            counter <= counter + 1'b1;
    case (counter)
        4'd0: ; // begin
        4'd1: temp_data[0] <= Keydata_r1;
        4'd2: temp_data[1] <= Keydata_r1;
        4'd3: temp_data[2] <= Keydata_r1;
        4'd4: temp_data[3] <= Keydata_r1;
        4'd5: temp_data[4] <= Keydata_r1;
        4'd6: temp_data[5] <= Keydata_r1;
        4'd7: temp_data[6] <= Keydata_r1;
        4'd8: temp_data[7] <= Keydata_r1;
        4'd9: ; // test
        4'd10:; // end
        default: ;
    endcase
    end
end 
reg key_break = 1'b0; 
reg [7:0]key_byte = 1'b0;
always @ (posedge CLK100M or negedge Reset) begin 
    if(!Reset) begin
        key_break <= 1'b0;
        KeyState <= 1'b0;
         key_byte <= 1'b0;
     end
     else if(counter == 4'd10 && PS2CLK_neg) begin 
         if(temp_data == 8'hf0) 
            key_break <= 1'b1;
         else if(!key_break) begin
            KeyState <= 1'b1;
            key_byte <= temp_data; 
         end
        else begin
            KeyState <= 1'b0;
            key_break <= 1'b0;
        end
    end
end
always @ (key_byte) begin
    case (key_byte) //translate key_byte to key_ascii
         8'h1d: PS2_DATA_value = "W";//8'h57;   //W
         8'h1c: PS2_DATA_value = "A";//8'h41;   //A
         8'h23: PS2_DATA_value = "D";//8'h44;   //D
         8'h3b: PS2_DATA_value = "J";//8'h4a;   //J
         8'h42: PS2_DATA_value = "K";//8'h4b; //K
        default: PS2_DATA_value = 8'b0000_0000;
    endcase
end
endmodule
module PS2debounce( 
input clk,
input Reset,
input keystate,
input [7:0]PS2DATA,
output Goright,
output Goleft,
output Jump
);
reg [2:0]in;
reg [2:0]q1, q2, q3;
always@(*) begin
    if(PS2DATA == "W" && keystate == 1'b1)
        in = 3'b010;
    else if(PS2DATA == "A" && keystate == 1'b1)
        in = 3'b100;
    else if(PS2DATA == "D" && keystate == 1'b1)
        in = 3'b001;
    else
        in = 3'b000;
end
always @ (posedge clk or negedge Reset) begin
    if(!Reset) begin
        q1 <= 3'b000;
        q2 <= 3'b000;
        q3 <= 3'b000;
    end
    else begin
        q1 <= in;
        q2 <= q1;
        q3 <= q2;
    end
end
assign Goright = q1[0] & q2[0] & (!q3[0]); // right
assign Jump = q1[1] & q2[1] & (!q3[1]); // jump
assign Goleft = q1[2] & q2[2] & (!q3[2]); // left
endmodule
