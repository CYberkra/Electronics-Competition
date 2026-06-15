//------------------------------------------------------------------------------
// Sweep Engine — 可编程扫频引擎 (支持动态寄存器驱动)
//
// 工作模式:
//   线性 (sweep_log_mode=0): phase_inc 按固定 STEP_INC 线性步进
//   对数 (sweep_log_mode=1): phase_inc 按乘性因子步进
//
//   enable=0 时直通旁路: phase_inc_out = manual_phase_inc
//   enable=1 时扫频输出: phase_inc_out = sweep_inc (按 DWELL 周期更新)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sweep_engine #(
    parameter PHASE_W = 48,
    // 默认参数 (可被动态输入覆盖)
    parameter [PHASE_W-1:0] DEFAULT_START_INC = 48'h004189374BC7,  // 100 kHz
    parameter [PHASE_W-1:0] DEFAULT_STOP_INC  = 48'h028F5C28F5C3,  // 1 MHz
    parameter [PHASE_W-1:0] DEFAULT_STEP_INC  = 48'h004189374BC7,  // 100 kHz
    parameter [31:0]        DEFAULT_DWELL     = 32'd5_000_000      // 50 ms @ 100 MHz
) (
    input  wire                  clk,
    input  wire                  rst_n,

    // 控制
    input  wire                  enable,
    input  wire                  sweep_dir,       // 0=正向, 1=反向
    input  wire                  sweep_log_mode,  // 0=线性, 1=对数

    // 动态参数 (来自寄存器组, 为0时使用parameter默认值)
    input  wire [PHASE_W-1:0]   dyn_start_inc,
    input  wire [PHASE_W-1:0]   dyn_stop_inc,
    input  wire [PHASE_W-1:0]   dyn_step_inc,
    input  wire [31:0]          dyn_dwell,

    // 直通/扫频输出
    input  wire [PHASE_W-1:0]   manual_phase_inc,
    output reg  [PHASE_W-1:0]   phase_inc_out,
    output reg                  sweep_active
);

    // 选择动态参数或默认参数
    wire [PHASE_W-1:0] start_inc = (dyn_start_inc != {PHASE_W{1'b0}}) ? dyn_start_inc : DEFAULT_START_INC;
    wire [PHASE_W-1:0] stop_inc  = (dyn_stop_inc  != {PHASE_W{1'b0}}) ? dyn_stop_inc  : DEFAULT_STOP_INC;
    wire [PHASE_W-1:0] step_inc  = (dyn_step_inc  != {PHASE_W{1'b0}}) ? dyn_step_inc  : DEFAULT_STEP_INC;
    wire [31:0]        dwell     = (dyn_dwell      != 32'd0)          ? dyn_dwell      : DEFAULT_DWELL;

    reg [31:0] dwell_cnt;
    reg [PHASE_W-1:0] sweep_inc;
    reg internal_dir;  // 内部方向 (受 sweep_dir 影响)

    // 对数扫频: 乘性因子 (Q16 定点: 1.0 = 0x10000)
    // step_factor = 1.0 + step_inc / start_inc (近似)
    // 简化: 使用 2^N 倍频程步进
    reg [PHASE_W-1:0] log_current;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dwell_cnt      <= 32'd0;
            sweep_inc      <= start_inc;
            internal_dir   <= 1'b0;
            log_current    <= start_inc;
            phase_inc_out  <= {PHASE_W{1'b0}};
            sweep_active   <= 1'b0;
        end else begin
            if (!enable) begin
                // 直通旁路
                dwell_cnt     <= 32'd0;
                sweep_inc     <= start_inc;
                internal_dir  <= sweep_dir;
                log_current   <= start_inc;
                phase_inc_out <= manual_phase_inc;
                sweep_active  <= 1'b0;
            end else begin
                sweep_active <= 1'b1;

                if (dwell_cnt < dwell) begin
                    dwell_cnt <= dwell_cnt + 1'b1;
                end else begin
                    dwell_cnt <= 32'd0;

                    if (!sweep_log_mode) begin
                        //------------------------------------------------------
                        // 线性扫频
                        //------------------------------------------------------
                        if (!internal_dir) begin
                            // 正向
                            if (sweep_inc + step_inc >= stop_inc) begin
                                sweep_inc    <= stop_inc;
                                internal_dir <= 1'b1;  // 反转
                            end else begin
                                sweep_inc <= sweep_inc + step_inc;
                            end
                        end else begin
                            // 反向
                            if (sweep_inc <= start_inc + step_inc) begin
                                sweep_inc    <= start_inc;
                                internal_dir <= 1'b0;  // 反转
                            end else begin
                                sweep_inc <= sweep_inc - step_inc;
                            end
                        end
                    end else begin
                        //------------------------------------------------------
                        // 对数扫频 — 每次乘 ×(1 + 1/step_div)
                        // 简化实现: 每次左移1位 (2× 倍频程)
                        //------------------------------------------------------
                        if (!internal_dir) begin
                            if (log_current >= stop_inc || log_current[PHASE_W-1]) begin
                                log_current  <= stop_inc;
                                internal_dir <= 1'b1;
                            end else begin
                                log_current <= log_current << 1;  // 2× per step
                            end
                        end else begin
                            if (log_current <= start_inc || log_current == {PHASE_W{1'b0}}) begin
                                log_current  <= start_inc;
                                internal_dir <= 1'b0;
                            end else begin
                                log_current <= log_current >> 1;  // /2 per step
                            end
                        end
                        sweep_inc <= log_current;
                    end
                end

                // 输出
                phase_inc_out <= sweep_log_mode ? log_current : sweep_inc;
            end
        end
    end

endmodule
