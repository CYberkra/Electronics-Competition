//------------------------------------------------------------------------------
// EC11 Rotary Encoder Decoder
// 【EC11 旋转编码器正交解码 + 按键消抖】
//
// 功能：
//   - 2级同步器消除亚稳态
//   - 正交解码：检测 CW/CCW 旋转 → rotation 输出 ±1 脉冲
//   - 按键消抖 (~20ms) + 短按/长按(~1s) 检测
//
// EC11 时序:
//   CW (顺时针):  A ──┐   ┌──┐   相位 A 领先 B 90°
//                 B ──┼──┐│┌─┼──  当 A↓ 且 B=1 → CW
//   CCW (逆时针): A ──┐   ┌──┐   相位 B 领先 A 90°
//                 B ─┐┼──┘│└─┼─  当 A↓ 且 B=0 → CCW
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module ec11_decoder #(
    parameter [31:0] DEBOUNCE_MS   = 32'd20,       // 按键消抖时间 (ms)
    parameter [31:0] LONG_PRESS_MS = 32'd1000,     // 长按判定时间 (ms)
    parameter        CLK_HZ        = 25_000_000    // 输入时钟频率 (Hz)
) (
    input  wire           clk,
    input  wire           rst_n,

    // EC11 物理接口
    input  wire           ec11_a,
    input  wire           ec11_b,
    input  wire           ec11_btn,

    // 解码输出
    output reg  signed [7:0] rotation,    // +1(CW) / -1(CCW) / 0 单周期脉冲
    output reg            btn_short,      // 短按 (单周期脉冲)
    output reg            btn_long        // 长按 (单周期脉冲, >1s 释放时触发)
);

    //--------------------------------------------------------------------------
    // 时钟周期换算
    //--------------------------------------------------------------------------
    localparam [31:0] TICKS_PER_MS    = CLK_HZ / 1000;
    localparam [31:0] BTN_DEBOUNCE    = DEBOUNCE_MS   * TICKS_PER_MS;
    localparam [31:0] BTN_LONG_PRESS  = LONG_PRESS_MS * TICKS_PER_MS;

    //--------------------------------------------------------------------------
    // 2级同步器 — 消除亚稳态
    //--------------------------------------------------------------------------
    reg a_sync0, a_sync1;
    reg b_sync0, b_sync1;
    reg btn_sync0, btn_sync1;

    always @(posedge clk) begin
        {a_sync1, a_sync0}   <= {a_sync0, ec11_a};
        {b_sync1, b_sync0}   <= {b_sync0, ec11_b};
        {btn_sync1, btn_sync0} <= {btn_sync0, ec11_btn};
    end

    //--------------------------------------------------------------------------
    // Debounce for A and B quadrature inputs (~5ms at 25MHz = 125000 cycles)
    //--------------------------------------------------------------------------
    localparam [31:0] QUAD_DEBOUNCE = TICKS_PER_MS * 5;

    reg [31:0] a_db_cnt, b_db_cnt;
    reg        a_stable, b_stable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_db_cnt <= 32'd0; a_stable <= 1'b1;
            b_db_cnt <= 32'd0; b_stable <= 1'b1;
        end else begin
            // A input debounce
            if (a_sync1 != a_stable) begin
                if (a_db_cnt < QUAD_DEBOUNCE)
                    a_db_cnt <= a_db_cnt + 1'b1;
                else begin
                    a_stable <= a_sync1;
                    a_db_cnt <= 32'd0;
                end
            end else
                a_db_cnt <= 32'd0;

            // B input debounce
            if (b_sync1 != b_stable) begin
                if (b_db_cnt < QUAD_DEBOUNCE)
                    b_db_cnt <= b_db_cnt + 1'b1;
                else begin
                    b_stable <= b_sync1;
                    b_db_cnt <= 32'd0;
                end
            end else
                b_db_cnt <= 32'd0;
        end
    end

    //--------------------------------------------------------------------------
    // 正交解码 — 使用消抖后的 stable 信号
    //--------------------------------------------------------------------------
    reg a_prev;
    wire a_rise, a_fall;

    assign a_rise =  a_stable && !a_prev;
    assign a_fall = !a_stable &&  a_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_prev   <= 1'b0;
            rotation <= 8'sd0;
        end else begin
            a_prev <= a_stable;

            if (a_fall) begin
                rotation <= b_stable ? 8'sd1 : -8'sd1;
            end else if (a_rise) begin
                rotation <= b_stable ? -8'sd1 : 8'sd1;
            end else begin
                rotation <= 8'sd0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // 按键消抖 + 长按检测
    //--------------------------------------------------------------------------
    reg [31:0] btn_cnt;
    reg        btn_stable;
    reg        btn_stable_prev;
    reg        btn_held;
    reg [31:0] hold_cnt;
    reg        long_press_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_cnt            <= 32'd0;
            btn_stable         <= 1'b1;
            btn_stable_prev    <= 1'b1;
            btn_held           <= 1'b0;
            hold_cnt           <= 32'd0;
            long_press_latched <= 1'b0;
            btn_short          <= 1'b0;
            btn_long           <= 1'b0;
        end else begin
            btn_short <= 1'b0;
            btn_long  <= 1'b0;

            // 消抖计数器 — 信号稳定后才更新
            if (btn_sync1 != btn_stable) begin
                if (btn_cnt < BTN_DEBOUNCE) begin
                    btn_cnt <= btn_cnt + 1'b1;
                end else begin
                    btn_stable <= btn_sync1;
                    btn_cnt    <= 32'd0;
                end
            end else begin
                btn_cnt <= 32'd0;
            end

            btn_stable_prev <= btn_stable;

            // 按键按下 (低电平有效)
            if (!btn_stable) begin
                btn_held <= 1'b1;
                if (hold_cnt < BTN_LONG_PRESS) begin
                    hold_cnt <= hold_cnt + 1'b1;
                end else if (!long_press_latched) begin
                    // 长按达到阈值，触发一次
                    btn_long           <= 1'b1;
                    long_press_latched <= 1'b1;
                end
            end else begin
                // 按键释放
                if (btn_held) begin
                    if (!long_press_latched) begin
                        // 短按：释放时触发
                        btn_short <= 1'b1;
                    end
                    btn_held           <= 1'b0;
                    hold_cnt           <= 32'd0;
                    long_press_latched <= 1'b0;
                end
            end
        end
    end

endmodule
