//------------------------------------------------------------------------------
// 8×16 ASCII Character ROM
// 【字符字模 ROM — BRAM 存储 8×16 等宽终端字体】
//
// 覆盖 ASCII 32-127 (96 可打印字符)
// 每个字符 8×16 像素 = 16 字节, 总计 1536 字节
// 地址: {char_code[6:0], row[3:0]} — 11bit 地址
//
// 字体数据由外部 .hex 文件初始化，通过 $readmemh 加载
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module char_rom #(
    parameter FONT_FILE = "font_8x16.hex"
) (
    input  wire        clk,
    input  wire [6:0]  char_code,   // ASCII 码 (0x20-0x7F → 0-95)
    input  wire [3:0]  row,          // 字符内行号 (0-15)
    output reg  [7:0]  bitmap        // 8 像素位图 (MSB=左)
);

    // BRAM: 1536 字节 = 96 chars × 16 rows
    (* ram_style = "block" *) reg [7:0] font_rom [0:1535];

    // 地址计算
    wire [10:0] rom_addr;
    // char_code 0x20-0x7F → index 0-95
    wire [6:0] char_index = char_code - 7'd32;
    assign rom_addr = {char_index[6:0], row[3:0]};

    initial begin
        $readmemh(FONT_FILE, font_rom);
    end

    always @(posedge clk) begin
        bitmap <= font_rom[rom_addr];
    end

endmodule
