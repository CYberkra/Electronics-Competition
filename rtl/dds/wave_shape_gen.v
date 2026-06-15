//------------------------------------------------------------------------------
// Waveform Shape Generator
// 【基础波形生成器】
//
// 功能说明：
//   基于相位地址直接生成方波、三角波、锯齿波，无需查表。
//   正弦波由 sine_lut.v 单独提供，本模块只负责非正弦波形。
//
// 波形公式：
//   Square   : 根据地址最高位判断正负半周
//   Triangle : 前半周期线性上升，后半周期线性下降
//   Sawtooth : 整个周期线性上升，到顶后瞬间归零
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module wave_shape_gen #(
    parameter ADDR_W = 12,
    parameter DATA_W = 16
)(
    input  wire [ADDR_W-1:0] addr,       // 相位地址 (0 ~ 4095)
    input  wire [2:0]        mode,       // 1=triangle, 2=square, 3=saw
    output reg  signed [DATA_W-1:0] wave_out
);

    localparam MAX_POS = 16'sd32767;   // +32767
    localparam MAX_NEG = -16'sd32768;  // -32768
    localparam HALF    = 12'd2048;     // 4096/2
    localparam MAX_U   = 11'd2047;     // 2047 (half period max)

    // 内部信号
    wire [ADDR_W-2:0] half_addr = addr[ADDR_W-2:0];  // 0 ~ 2047

    //----------------------------------------------------------------------
    // 三角波中间值（0~2047 范围）
    //----------------------------------------------------------------------
    wire [ADDR_W-2:0] tri_unsigned;
    assign tri_unsigned = addr[ADDR_W-1] ? (MAX_U - half_addr) : half_addr;

    // 三角波：映射到 16bit 有符号
    // (tri_unsigned - 1024) * 32 → 约 [-32768, 32736]
    wire signed [DATA_W-1:0] triangle_val;
    assign triangle_val = ($signed({1'b0, tri_unsigned}) - 12'sd1024) * 16'sd32;

    //----------------------------------------------------------------------
    // 锯齿波：映射到 16bit 有符号
    // (addr - 2048) * 16 → [-32768, 32752]
    //----------------------------------------------------------------------
    wire signed [DATA_W-1:0] saw_val;
    assign saw_val = ($signed({1'b0, addr}) - 13'sd2048) * 16'sd16;

    //----------------------------------------------------------------------
    // 波形选择
    //----------------------------------------------------------------------
    always @(*) begin
        case (mode)
            3'd1:   wave_out = triangle_val;                         // 三角波
            3'd2:   wave_out = addr[ADDR_W-1] ? MAX_NEG : MAX_POS;  // 方波
            3'd3:   wave_out = saw_val;                              // 锯齿波
            default: wave_out = 16'sd0;                             // 默认静音
        endcase
    end

endmodule
