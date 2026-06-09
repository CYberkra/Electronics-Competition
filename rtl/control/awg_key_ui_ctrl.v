//------------------------------------------------------------------------------
// AWG Key UI Control
// 【AWG 按键控制层】
//
// 功能说明：
//   使用板载两个按键控制可调 AWG 前端：
//     - 单键操作：修改当前参数组中的数值
//     - 双键长按：切换参数组
//
// 参数组定义：
//   0 = 频率档位
//   1 = 波形模式
//   2 = 幅度档位
//   3 = 直流偏置档位
//
// 当前输出接口可直接接到 awg_core，后续也可替换为寄存器写入。
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_key_ui_ctrl #(
    parameter [31:0] DEBOUNCE_TICKS = 32'd2_000_000,   // 20ms @ 100MHz
    parameter [31:0] CHORD_TICKS    = 32'd25_000_000,  // 250ms @ 100MHz
    parameter PHASE_W = 48,
    parameter DATA_W   = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     key0,
    input  wire                     key1,
    output reg                      freq_load,
    output reg  [PHASE_W-1:0]       phase_inc,
    output reg  [PHASE_W-1:0]       phase_offset,
    output reg  [2:0]               wave_mode,
    output reg  [DATA_W-1:0]        amplitude,
    output reg  signed [DATA_W-1:0] offset,
    output reg  signed [DATA_W-1:0] test_sample,
    output reg  [1:0]               ui_mode
);

    //--------------------------------------------------------------------------
    // 频率档位常量（250MHz DDS 时钟）
    //--------------------------------------------------------------------------
    localparam [47:0] PHASE_INC_1HZ     = 48'h0000000002AF31E;
    localparam [47:0] PHASE_INC_10HZ    = 48'h000000001AD7F2A;
    localparam [47:0] PHASE_INC_100HZ   = 48'h000000010C6F7A1;
    localparam [47:0] PHASE_INC_1KHZ    = 48'h0000000A7C5AC47;
    localparam [47:0] PHASE_INC_10KHZ   = 48'h00000068DB8BAC7;
    localparam [47:0] PHASE_INC_100KHZ  = 48'h000004189374BC7;
    localparam [47:0] PHASE_INC_1MHZ    = 48'h000028F5C28F5C3;
    localparam [47:0] PHASE_INC_10MHZ   = 48'h0001999999999A;

    //--------------------------------------------------------------------------
    // 内部控制寄存器
    //--------------------------------------------------------------------------
    reg [2:0] freq_sel;
    reg [2:0] wave_sel;
    reg [2:0] amp_sel;
    reg [2:0] offset_sel;

    reg key0_d, key0_dd;
    reg key1_d, key1_dd;
    reg key0_stable;
    reg key1_stable;
    reg key0_stable_prev;
    reg key1_stable_prev;
    reg [31:0] key0_cnt;
    reg [31:0] key1_cnt;

    reg combo_seen;
    reg chord_latched;
    reg [31:0] chord_cnt;
    reg init_load_done;
    wire key0_release;
    wire key1_release;
    wire both_down;

    assign key0_release = !key0_stable_prev && key0_stable;
    assign key1_release = !key1_stable_prev && key1_stable;
    assign both_down    = !key0_stable && !key1_stable;

    //--------------------------------------------------------------------------
    // 参数表
    //--------------------------------------------------------------------------
    always @(*) begin
        case (freq_sel)
            3'd0: phase_inc = PHASE_INC_1HZ;
            3'd1: phase_inc = PHASE_INC_10HZ;
            3'd2: phase_inc = PHASE_INC_100HZ;
            3'd3: phase_inc = PHASE_INC_1KHZ;
            3'd4: phase_inc = PHASE_INC_10KHZ;
            3'd5: phase_inc = PHASE_INC_100KHZ;
            3'd6: phase_inc = PHASE_INC_1MHZ;
            3'd7: phase_inc = PHASE_INC_10MHZ;
            default: phase_inc = PHASE_INC_1HZ;
        endcase

        case (wave_sel)
            3'd0: wave_mode = 3'd0;   // sine
            3'd1: wave_mode = 3'd1;   // square
            3'd2: wave_mode = 3'd2;   // triangle
            3'd3: wave_mode = 3'd3;   // sawtooth
            3'd4: wave_mode = 3'd4;   // test / DC
            3'd5: wave_mode = 3'd5;   // BRAM waveform
            3'd6: wave_mode = 3'd6;   // linear sweep
            default: wave_mode = 3'd0;
        endcase

        case (amp_sel)
            3'd0: amplitude = 16'h1000;  // 12.5%
            3'd1: amplitude = 16'h2000;  // 25%
            3'd2: amplitude = 16'h4000;  // 50%
            3'd3: amplitude = 16'h6000;  // 75%
            3'd4: amplitude = 16'h7FFF;  // ~100%
            default: amplitude = 16'h7FFF;
        endcase

        case (offset_sel)
            3'd0: offset = -16'sd12000;
            3'd1: offset = -16'sd6000;
            3'd2: offset =  16'sd0;
            3'd3: offset =  16'sd6000;
            3'd4: offset =  16'sd12000;
            default: offset = 16'sd0;
        endcase

        phase_offset = {PHASE_W{1'b0}};
        test_sample   = offset;
    end

    //--------------------------------------------------------------------------
    // 复位和按键控制
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_sel          <= 3'd0;
            wave_sel          <= 3'd0;
            amp_sel           <= 3'd2;
            offset_sel        <= 3'd2;
            ui_mode           <= 2'd0;
            freq_load         <= 1'b0;
            key0_d            <= 1'b1;
            key0_dd           <= 1'b1;
            key1_d            <= 1'b1;
            key1_dd           <= 1'b1;
            key0_stable       <= 1'b1;
            key1_stable       <= 1'b1;
            key0_stable_prev  <= 1'b1;
            key1_stable_prev  <= 1'b1;
            key0_cnt          <= 32'd0;
            key1_cnt          <= 32'd0;
            combo_seen        <= 1'b0;
            chord_latched     <= 1'b0;
            chord_cnt         <= 32'd0;
            init_load_done    <= 1'b0;
        end else begin
            // 两级同步 + 消抖
            key0_d  <= key0;
            key0_dd <= key0_d;
            key1_d  <= key1;
            key1_dd <= key1_d;

            if (key0_d != key0_dd) begin
                key0_cnt <= 32'd0;
            end else if (key0_cnt < DEBOUNCE_TICKS) begin
                key0_cnt <= key0_cnt + 1'b1;
            end else begin
                key0_stable <= key0_dd;
            end

            if (key1_d != key1_dd) begin
                key1_cnt <= 32'd0;
            end else if (key1_cnt < DEBOUNCE_TICKS) begin
                key1_cnt <= key1_cnt + 1'b1;
            end else begin
                key1_stable <= key1_dd;
            end

            key0_stable_prev <= key0_stable;
            key1_stable_prev <= key1_stable;

            freq_load <= 1'b0;

            if (!init_load_done) begin
                init_load_done <= 1'b1;
                freq_load <= 1'b1;
            end

            // 双键同时按下，进入组合模式；长按到阈值后切换参数组
            if (both_down) begin
                combo_seen <= 1'b1;
                if (chord_cnt < CHORD_TICKS) begin
                    chord_cnt <= chord_cnt + 1'b1;
                end else if (!chord_latched) begin
                    ui_mode       <= ui_mode + 1'b1;
                    chord_latched <= 1'b1;
                end
            end else begin
                chord_cnt <= 32'd0;
                if (key0_stable && key1_stable) begin
                    combo_seen    <= 1'b0;
                    chord_latched <= 1'b0;
                end
            end

            // 单键释放后的动作提交
            if (key0_release) begin
                if (!combo_seen) begin
                    case (ui_mode)
                        2'd0: begin
                            if (freq_sel < 3'd7)
                                freq_sel <= freq_sel + 1'b1;
                            else
                                freq_sel <= 3'd0;
                            freq_load <= 1'b1;
                        end
                        2'd1: begin
                            if (wave_sel < 3'd6)
                                wave_sel <= wave_sel + 1'b1;
                            else
                                wave_sel <= 3'd0;
                        end
                        2'd2: begin
                            if (amp_sel < 3'd4)
                                amp_sel <= amp_sel + 1'b1;
                            else
                                amp_sel <= 3'd0;
                        end
                        2'd3: begin
                            if (offset_sel < 3'd4)
                                offset_sel <= offset_sel + 1'b1;
                            else
                                offset_sel <= 3'd0;
                        end
                        default: begin
                            // 保留
                        end
                    endcase
                end
            end

            if (key1_release) begin
                if (!combo_seen) begin
                    case (ui_mode)
                        2'd0: begin
                            if (freq_sel > 3'd0)
                                freq_sel <= freq_sel - 1'b1;
                            else
                                freq_sel <= 3'd7;
                            freq_load <= 1'b1;
                        end
                        2'd1: begin
                            if (wave_sel > 3'd0)
                                wave_sel <= wave_sel - 1'b1;
                            else
                                wave_sel <= 3'd6;
                        end
                        2'd2: begin
                            if (amp_sel > 3'd0)
                                amp_sel <= amp_sel - 1'b1;
                            else
                                amp_sel <= 3'd4;
                        end
                        2'd3: begin
                            if (offset_sel > 3'd0)
                                offset_sel <= offset_sel - 1'b1;
                            else
                                offset_sel <= 3'd4;
                        end
                        default: begin
                            // 保留
                        end
                    endcase
                end
            end
        end
    end

endmodule
