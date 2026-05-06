//------------------------------------------------------------------------------
// Sample Multiplexer
// 【样本选择器】
//
// 功能说明：
//   根据 mode 选择当前输出的波形源。
//   0=sine, 1=square, 2=triangle, 3=saw, 4=test pattern, 5=bram
//
// 设计要点：
//   纯组合逻辑，无时钟延迟，确保波形切换即时响应。
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sample_mux #(
    parameter DATA_W = 16
)(
    input  wire [2:0]        mode,
    input  wire signed [DATA_W-1:0] sine_sample,   // 来自 sine_lut
    input  wire signed [DATA_W-1:0] shape_sample,  // 来自 wave_shape_gen
    input  wire signed [DATA_W-1:0] bram_sample,   // 来自 bram_wave_player
    input  wire signed [DATA_W-1:0] test_sample,   // 测试码型（如 ramp、固定值）
    output reg  signed [DATA_W-1:0] sample_out
);

    always @(*) begin
        case (mode)
            3'd0: sample_out = sine_sample;    // 正弦波
            3'd1: sample_out = shape_sample;   // 方波
            3'd2: sample_out = shape_sample;   // 三角波
            3'd3: sample_out = shape_sample;   // 锯齿波
            3'd4: sample_out = test_sample;    // 测试码型
            3'd5: sample_out = bram_sample;    // BRAM 任意波形
            3'd6: sample_out = sine_sample;    // sweep mode still uses sine path
            default: sample_out = 16'sd0;      // 静音（非法模式保护）
        endcase
    end

endmodule
