//------------------------------------------------------------------------------
// AWG DDS LED Demo Top - K325T Board Test
// 【AWG 板级演示顶层】
//
// 功能说明：
//   使用板载 100MHz 差分时钟驱动可调 AWG 前端。
//   两个按键构成最小控制面：
//     - KEY0：当前参数组 +1
//     - KEY1：当前参数组 -1
//     - KEY0 + KEY1 长按：切换参数组
//
//   当前参数组：
//     0 = 频率档位
//     1 = 波形模式
//     2 = 幅度档位
//     3 = 直流偏置档位
//
//   正弦/方波/三角/锯齿/测试输出送到教学 DAC，同时用 LED 指示波形。
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_dds_led_top (
    input  wire        sys_clk_p,
    input  wire        sys_clk_n,
    input  wire        sys_rst_n,
    input  wire        key0,
    input  wire        key1,
    output wire [1:0]  led,
    output wire        da_clk,
    output wire [7:0]  da_data
);

    wire clk_ibuf;
    wire clk;
    wire rst_n;

    wire [47:0] phase_inc;
    wire [47:0] phase_offset;
    wire [2:0]  wave_mode;
    wire [15:0] amplitude;
    wire signed [15:0] offset;
    wire signed [15:0] test_sample;
    wire [1:0]  ui_mode;
    wire        freq_load;
    wire [15:0] awg_sample;
    wire        sample_valid;
    wire [1:0]  wave_led;

    IBUFDS u_clk_ibufds (
        .I  (sys_clk_p),
        .IB (sys_clk_n),
        .O  (clk_ibuf)
    );

    BUFG u_clk_bufg (
        .I (clk_ibuf),
        .O (clk)
    );

    assign rst_n = sys_rst_n;

    awg_key_ui_ctrl #(
        .DEBOUNCE_TICKS (32'd2_000_000),
        .CHORD_TICKS    (32'd25_000_000),
        .PHASE_W        (48),
        .DATA_W         (16)
    ) u_key_ctrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .key0         (key0),
        .key1         (key1),
        .freq_load    (freq_load),
        .phase_inc    (phase_inc),
        .phase_offset (phase_offset),
        .wave_mode    (wave_mode),
        .amplitude    (amplitude),
        .offset       (offset),
        .test_sample  (test_sample),
        .ui_mode      (ui_mode)
    );

    awg_core #(
        .PHASE_W (48),
        .ADDR_W  (12),
        .DATA_W  (16)
    ) u_awg_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .freq_load    (freq_load),
        .phase_inc    (phase_inc),
        .phase_offset (phase_offset),
        .wave_mode    (wave_mode),
        .amplitude    (amplitude),
        .offset       (offset),
        .test_sample  (test_sample),
        .phase_addr   (),
        .phase_inc_active (),
        .sample_raw   (),
        .sample_out   (awg_sample),
        .sample_valid (sample_valid)
    );

    dac_edu_parallel_if u_dac_if (
        .clk      (clk),
        .rst_n    (rst_n),
        .sine_in  (awg_sample),
        .da_clk   (da_clk),
        .da_data  (da_data)
    );

    assign wave_led[0] = awg_sample[15];
    assign wave_led[1] = awg_sample[14] ^ awg_sample[15];

    awg_led_status #(
        .STATUS_TICKS (32'd100_000_000)
    ) u_led_status (
        .clk        (clk),
        .rst_n      (rst_n),
        .ui_mode    (ui_mode),
        .wave_mode  (wave_mode),
        .phase_inc  (phase_inc),
        .amplitude  (amplitude),
        .offset     (offset),
        .wave_led   (wave_led),
        .led        (led)
    );

`ifdef AWG_DEBUG_ILA
    ila_awg_debug u_ila_awg_debug (
        .clk    (clk),
        .probe0 (key0),
        .probe1 (key1),
        .probe2 (rst_n),
        .probe3 (ui_mode),
        .probe4 (wave_mode),
        .probe5 (freq_load),
        .probe6 (phase_inc),
        .probe7 (amplitude),
        .probe8 (offset),
        .probe9 (awg_sample),
        .probe10(sample_valid),
        .probe11(da_data),
        .probe12(led)
    );
`endif

endmodule
