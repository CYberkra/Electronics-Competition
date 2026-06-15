//------------------------------------------------------------------------------
// Character Grid Buffer — 字符帧缓存 BRAM
// 【30列×17行 = 510 字节 字符码存储】
//
// Port A: 写端口 (菜单控制器 → 更新显示内容)
// Port B: 读端口 (tile_renderer → 逐像素扫描)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module char_grid #(
    parameter GRID_SIZE = 510     // 30 × 17
) (
    input  wire        clk,

    // Port A — 写端口
    input  wire        wr_en,
    input  wire [8:0]  wr_addr,    // 0-509
    input  wire [7:0]  wr_data,

    // Port B — 读端口
    input  wire [8:0]  rd_addr,    // 0-509
    output reg  [7:0]  rd_data
);

    (* ram_style = "block" *) reg [7:0] grid [0:GRID_SIZE-1];

    // 初始化全空格
    integer init_i;
    initial begin
        for (init_i = 0; init_i < GRID_SIZE; init_i = init_i + 1)
            grid[init_i] = 8'h20;
    end

    // Port A: 同步写
    always @(posedge clk) begin
        if (wr_en)
            grid[wr_addr] <= wr_data;
    end

    // Port B: 同步读 (1-cycle read latency)
    always @(posedge clk) begin
        rd_data <= grid[rd_addr];
    end

endmodule
