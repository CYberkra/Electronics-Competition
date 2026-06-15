//------------------------------------------------------------------------------
// EC11 → AWG Register Bridge
// 【EC11 编码器 → AWG 寄存器写桥接】
//
// 功能:
//   - EC11 旋转 → 修改当前参数 (频率/波形/幅度)
//   - EC11 短按 → 切换参数页面
//   - EC11 长按 → APPLY (触发参数生效)
//
// 参数页面:
//   0 = 频率  (旋转改变频率)
//   1 = 波形  (旋转切换波形)
//   2 = 幅度  (旋转改变幅度)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module ec11_awg_bridge (
    input  wire        clk,
    input  wire        rst_n,

    // EC11 解码输入
    input  wire signed [7:0] rotation,   // +1 CW, -1 CCW, 0 idle
    input  wire        btn_short,
    input  wire        btn_long,

    // AWG 寄存器写接口
    output reg         wr_en,
    output reg  [7:0]  wr_addr,
    output reg  [31:0] wr_data,
    output reg         apply_trig,       // 写 0x2C 触发参数生效

    // 状态指示
    output reg  [1:0]  param_page,       // 当前参数页
    output reg         activity           // 编码器活动指示
);

    //--------------------------------------------------------------------------
    // 参数页
    //--------------------------------------------------------------------------
    localparam PAGE_FREQ = 2'd0;
    localparam PAGE_WAVE = 2'd1;
    localparam PAGE_AMP  = 2'd2;

    // 频率步进预设 (phase_inc units @ 250MHz DDS clock, 1e9 samples/s)
    // f_out * 2^48 / 1e9
    localparam [47:0] STEP_1HZ    = 48'h00000000002AF31E;
    localparam [47:0] STEP_10HZ   = 48'h0000000001AD7F2A;
    localparam [47:0] STEP_100HZ  = 48'h0000000010C6F7A1;
    localparam [47:0] STEP_1KHZ   = 48'h00000000A7C5AC47;
    localparam [47:0] STEP_10KHZ  = 48'h000000068DB8BAC7;
    localparam [47:0] STEP_100KHZ = 48'h000004189374BC7;
    localparam [47:0] STEP_1MHZ   = 48'h000028F5C28F5C3;
    localparam [47:0] STEP_10MHZ  = 48'h000199999999999A;

    //--------------------------------------------------------------------------
    // 内部状态
    //--------------------------------------------------------------------------
    reg [1:0]  page;
    reg [47:0] freq_phase_inc;    // 当前频率控制字
    reg [3:0]  freq_step_idx;     // 0=1Hz .. 7=10MHz
    reg [1:0]  wave_sel;          // 0=Sine, 1=Triangle, 2=Square, 3=Saw
    reg [15:0] amp_val;           // Q1.15 幅度值
    reg [3:0]  amp_step_idx;

    reg [7:0]  rot_acc;
    wire rot_trigger = (rot_acc >= 8'd4) || (rot_acc <= -8'd4);
    wire rot_cw  = (rot_acc >=  8'd4);
    wire rot_ccw = (rot_acc <= -8'd4);

    // 旋转脉冲累积
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rot_acc <= 8'd0;
        end else begin
            if (rotation != 8'sd0)
                rot_acc <= rot_acc + rotation;
            else if (rot_trigger)
                rot_acc <= 8'd0;
        end
    end

    //--------------------------------------------------------------------------
    // 主控制逻辑
    //--------------------------------------------------------------------------
    reg btn_short_d, btn_long_d;
    reg rot_trigger_d;
    reg [3:0] apply_delay;  // APPLY 之后的去抖

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page          <= PAGE_FREQ;
            freq_phase_inc <= 48'h0CCCCCCCCCCD;  // ~50MHz default
            freq_step_idx <= 4'd5;                // 100kHz step
            wave_sel      <= 2'd0;                // Sine
            amp_val       <= 16'h6000;            // 75%
            amp_step_idx  <= 4'd3;                // medium step
            param_page    <= 2'd0;
            wr_en         <= 1'b0;
            wr_addr       <= 8'd0;
            wr_data       <= 32'd0;
            apply_trig    <= 1'b0;
            activity      <= 1'b0;
            btn_short_d   <= 1'b0;
            btn_long_d    <= 1'b0;
            rot_trigger_d <= 1'b0;
            apply_delay   <= 4'd0;
        end else begin
            btn_short_d   <= btn_short;
            btn_long_d    <= btn_long;
            rot_trigger_d <= rot_trigger;
            wr_en         <= 1'b0;
            apply_trig    <= 1'b0;
            activity      <= 1'b0;

            // APPLY 延迟 (让 reg_bank 先锁存参数)
            if (apply_delay > 4'd0) begin
                apply_delay <= apply_delay - 1'b1;
                if (apply_delay == 4'd1) begin
                    // 触发 APPLY
                    wr_en    <= 1'b1;
                    wr_addr  <= 8'h2C;
                    wr_data  <= 32'd1;
                    apply_trig <= 1'b1;
                end
            end

            // 短按: 切换参数页
            if (btn_short && !btn_short_d) begin
                page <= page + 1'b1;
                param_page <= page + 1'b1;
                activity <= 1'b1;
            end

            // 长按: APPLY
            if (btn_long && !btn_long_d) begin
                apply_delay <= 4'd3;
                activity <= 1'b1;
            end

            // 旋转: 修改当前页参数
            if (rot_trigger && !rot_trigger_d) begin
                activity <= 1'b1;
                wr_en    <= 1'b1;

                case (page)
                    PAGE_FREQ: begin
                        if (rot_cw) begin
                            case (freq_step_idx)
                                4'd0: freq_phase_inc <= freq_phase_inc + STEP_1HZ;
                                4'd1: freq_phase_inc <= freq_phase_inc + STEP_10HZ;
                                4'd2: freq_phase_inc <= freq_phase_inc + STEP_100HZ;
                                4'd3: freq_phase_inc <= freq_phase_inc + STEP_1KHZ;
                                4'd4: freq_phase_inc <= freq_phase_inc + STEP_10KHZ;
                                4'd5: freq_phase_inc <= freq_phase_inc + STEP_100KHZ;
                                4'd6: freq_phase_inc <= freq_phase_inc + STEP_1MHZ;
                                4'd7: freq_phase_inc <= freq_phase_inc + STEP_10MHZ;
                            endcase
                        end else begin
                            case (freq_step_idx)
                                4'd0: freq_phase_inc <= freq_phase_inc - STEP_1HZ;
                                4'd1: freq_phase_inc <= freq_phase_inc - STEP_10HZ;
                                4'd2: freq_phase_inc <= freq_phase_inc - STEP_100HZ;
                                4'd3: freq_phase_inc <= freq_phase_inc - STEP_1KHZ;
                                4'd4: freq_phase_inc <= freq_phase_inc - STEP_10KHZ;
                                4'd5: freq_phase_inc <= freq_phase_inc - STEP_100KHZ;
                                4'd6: freq_phase_inc <= freq_phase_inc - STEP_1MHZ;
                                4'd7: freq_phase_inc <= freq_phase_inc - STEP_10MHZ;
                            endcase
                        end
                        wr_addr <= 8'h10;  // PHASE_INC_LO
                        wr_data <= freq_phase_inc[31:0];
                    end

                    PAGE_WAVE: begin
                        if (rot_cw) begin
                            wave_sel <= (wave_sel == 2'd3) ? 2'd0 : wave_sel + 1'b1;
                        end else begin
                            wave_sel <= (wave_sel == 2'd0) ? 2'd3 : wave_sel - 1'b1;
                        end
                        wr_addr <= 8'h28;  // WAVE_MODE
                        wr_data <= {30'd0, wave_sel};
                    end

                    PAGE_AMP: begin
                        if (rot_cw) begin
                            if (amp_val < 16'h7F00)
                                amp_val <= amp_val + 16'h0400;  // ~1.5% step
                        end else begin
                            if (amp_val > 16'h0400)
                                amp_val <= amp_val - 16'h0400;
                        end
                        wr_addr <= 8'h20;  // AMPLITUDE
                        wr_data <= {16'd0, amp_val};
                    end

                    default: begin
                        wr_en <= 1'b0;
                    end
                endcase
            end

            // 首次初始化: 写默认频率
            if (!btn_short_d && !btn_long_d && !rot_trigger_d &&
                freq_phase_inc == 48'h0CCCCCCCCCCD && apply_delay == 4'd0) begin
                // 已在复位时初始化，不需要额外操作
            end
        end
    end

endmodule
