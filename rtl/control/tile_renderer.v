//------------------------------------------------------------------------------
// Tile Renderer — 字符网格到像素流转换
// 【Tile-based 字符渲染器 — 30列×17行 字符网格 → ST7789 像素流】
//
// 屏幕布局 (240×280, 旋转后):
//   30 列 × 17 行 = 510 字符 (每字符 8×16 像素)
//   标题行: 0, 菜单区: 1-15, 状态栏: 16
//
// 扫描顺序: 逐行逐像素 (0,0) → (239,279)
// 每个像素: 查所属 tile → 查字符码 → 查字模 → 输出 RGB565 颜色
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tile_renderer #(
    parameter COLS     = 30,          // 字符列数
    parameter ROWS     = 17,          // 字符行数
    parameter CHAR_W   = 8,           // 字符宽度 (像素)
    parameter CHAR_H   = 16,          // 字符高度 (像素)
    parameter SCR_W    = 240,         // 屏幕宽度
    parameter SCR_H    = 272          // 屏幕高度 (17×16=272, ≤280)
) (
    input  wire        clk,
    input  wire        rst_n,

    // 字符帧缓存接口 (双端口 BRAM 读)
    output reg  [8:0]  char_addr,     // 0-509, 字符码地址
    input  wire [7:0]  char_code,     // 该位置的 ASCII 码

    // 字模 ROM 接口
    output reg  [6:0]  font_char,     // ASCII 码 (7bit)
    output reg  [3:0]  font_row,      // 字模行 (0-15)
    input  wire [7:0]  font_bitmap,   // 8 像素位图

    // ST7789 像素输出
    output reg  [15:0] pixel_data,    // RGB565
    output reg         pixel_valid,
    input  wire        pixel_ready,

    // 颜色主题
    input  wire [15:0] fg_color,      // 前景色 (文字)
    input  wire [15:0] bg_color,      // 背景色
    input  wire [15:0] title_color,   // 标题栏背景
    input  wire [15:0] status_color,  // 状态栏背景
    input  wire [15:0] cursor_color,  // 光标/选中行背景

    // 光标位置
    input  wire [4:0]  cursor_row,    // 当前选中行 (0-16)
    input  wire [4:0]  cursor_col,    // 选中列起始

    // 控制
    output reg         frame_start,   // 帧开始脉冲
    output reg         vsync          // 帧同步 (可在帧间隙拉高)
);

    //--------------------------------------------------------------------------
    // 像素坐标计数器
    //--------------------------------------------------------------------------
    reg [7:0]  px_x;       // 0-239
    reg [8:0]  px_y;       // 0-271

    // 推导 tile 坐标
    wire [4:0]  tile_col = px_x[7:3];   // px_x / 8
    wire [4:0]  tile_row = px_y[8:4];   // px_y / 16
    wire [2:0]  sub_x    = px_x[2:0];   // 字符内列 (0-7)
    wire [3:0]  sub_y    = px_y[3:0];   // 字符内行 (0-15)

    //--------------------------------------------------------------------------
    // 流水线阶段
    //   Stage 0: 计算 tile 坐标 + 子像素坐标
    //   Stage 1: 读 char_code (从帧缓存) — BRAM 延迟 1 cycle
    //   Stage 2: 读 font_bitmap (从字模 ROM) — BRAM 延迟 1 cycle
    //   Stage 3: 输出像素颜色
    //--------------------------------------------------------------------------

    // Stage 0 → 1 寄存器
    reg [4:0]  tile_row_s1, tile_col_s1;
    reg [2:0]  sub_x_s1;
    reg [3:0]  sub_y_s1;

    // Stage 1 → 2 寄存器
    reg [7:0]  char_code_s1, char_code_s2;
    reg [4:0]  tile_row_s2, tile_col_s2;
    reg [2:0]  sub_x_s2;

    // Stage 2 → 3 寄存器
    reg [7:0]  char_code_s3;
    reg [4:0]  tile_row_s3;
    reg [7:0]  bitmap_s2, char_code_for_font;
    reg [2:0]  sub_x_s3;

    //--------------------------------------------------------------------------
    // 主扫描循环
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_x          <= 8'd0;
            px_y          <= 9'd0;
            char_addr     <= 9'd0;
            font_char     <= 7'd0;
            font_row      <= 4'd0;
            pixel_data    <= 16'd0;
            pixel_valid   <= 1'b0;
            frame_start   <= 1'b0;
            vsync         <= 1'b0;

            tile_row_s1   <= 5'd0; tile_col_s1 <= 5'd0;
            sub_x_s1      <= 3'd0; sub_y_s1    <= 4'd0;
            char_code_s1  <= 8'd0; char_code_s2<= 8'd0;
            tile_row_s2   <= 5'd0; tile_col_s2 <= 5'd0;
            sub_x_s2      <= 3'd0;
            char_code_s3  <= 8'd0; tile_row_s3 <= 5'd0;
            bitmap_s2     <= 8'd0; char_code_for_font <= 8'd0;
            sub_x_s3      <= 3'd0;
        end else begin
            frame_start <= 1'b0;
            vsync       <= 1'b0;

            if (pixel_ready) begin
                //--------------------------------------------------------------
                // Stage 0: 更新坐标，发起 char_code 读
                //--------------------------------------------------------------
                tile_col_s1 <= tile_col;
                tile_row_s1 <= tile_row;
                sub_x_s1    <= sub_x;
                sub_y_s1    <= sub_y;

                char_addr <= tile_row * COLS + tile_col;

                //--------------------------------------------------------------
                // Stage 0→1: 锁存 char_code (BRAM 输出)
                //--------------------------------------------------------------
                char_code_s1 <= char_code;

                //--------------------------------------------------------------
                // Stage 1→2: 发起字体 ROM 读
                //--------------------------------------------------------------
                tile_row_s2  <= tile_row_s1;
                tile_col_s2  <= tile_col_s1;
                sub_x_s2     <= sub_x_s1;
                char_code_s2 <= char_code_s1;

                // 处理扩展 ASCII / 非打印字符
                if (char_code_s1 >= 8'h20 && char_code_s1 < 8'h80) begin
                    char_code_for_font <= char_code_s1;
                end else begin
                    char_code_for_font <= 8'h20;  // 空格
                end

                font_char <= char_code_for_font[6:0];
                font_row  <= sub_y_s1;

                //--------------------------------------------------------------
                // Stage 2→3: 锁存字模和坐标，准备输出像素
                //--------------------------------------------------------------
                tile_row_s3  <= tile_row_s2;
                sub_x_s3     <= sub_x_s2;
                char_code_s3 <= char_code_s2;
                bitmap_s2    <= font_bitmap;

                //--------------------------------------------------------------
                // Stage 3: 输出像素颜色
                //--------------------------------------------------------------
                // 检查该像素位是否点亮 (MSB=最左列)
                if (bitmap_s2[3'd7 - sub_x_s3]) begin
                    // 前景色 (文字)
                    pixel_data <= fg_color;
                end else begin
                    // 背景色
                    if (tile_row_s3 == 5'd0) begin
                        pixel_data <= title_color;    // 标题栏
                    end else if (tile_row_s3 == 5'd16) begin
                        pixel_data <= status_color;   // 状态栏
                    end else if (tile_row_s3 == cursor_row) begin
                        pixel_data <= cursor_color;   // 选中行高亮
                    end else begin
                        pixel_data <= bg_color;
                    end
                end

                pixel_valid <= 1'b1;

                //--------------------------------------------------------------
                // 坐标递增
                //--------------------------------------------------------------
                if (px_x == (SCR_W - 1)) begin
                    px_x <= 8'd0;
                    if (px_y == (SCR_H - 1)) begin
                        px_y <= 9'd0;
                        frame_start <= 1'b1;
                        vsync <= 1'b1;
                    end else begin
                        px_y <= px_y + 1'b1;
                    end
                end else begin
                    px_x <= px_x + 1'b1;
                end
            end else begin
                pixel_valid <= 1'b0;
            end
        end
    end

endmodule
