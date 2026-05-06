//------------------------------------------------------------------------------
// AWG Core Front-End
// 【AWG 可调前端核心】
//
// 功能说明：
//   将 DDS、波形选择、幅度缩放、直流偏置和饱和限幅串成一个
//   可复用的前端模块，后续可直接接到教学 DAC 或 AD9144 数据通道。
//
// 数据流：
//   phase_inc / phase_offset / freq_load
//        -> dds_nco
//        -> sine_lut + wave_shape_gen
//        -> sample_mux
//        -> amp_offset_scale
//
// 设计约定：
//   - freq_load 仅用于更新相位控制字和相位偏置
//   - wave_mode / amplitude / offset 可由寄存器或上层逻辑直接驱动
//   - sample_valid 在首次装载后有效，便于后续顶层接入
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_core #(
    parameter PHASE_W = 64,
    parameter ADDR_W  = 12,
    parameter DATA_W  = 16,
    parameter [31:0] SWEEP_DWELL_TICKS = 32'd2_000_000,
    parameter [PHASE_W-1:0] SWEEP_START_INC = 48'h004189374BC7,
    parameter [PHASE_W-1:0] SWEEP_STOP_INC  = 48'h028F5C28F5C3,
    parameter [PHASE_W-1:0] SWEEP_STEP_INC  = 48'h004189374BC7
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      freq_load,
    input  wire [PHASE_W-1:0]        phase_inc,
    input  wire [PHASE_W-1:0]        phase_offset,
    input  wire [2:0]                wave_mode,
    input  wire [DATA_W-1:0]         amplitude,
    input  wire signed [DATA_W-1:0]  offset,
    input  wire signed [DATA_W-1:0]  test_sample,
    output wire [ADDR_W-1:0]         phase_addr,
    output wire [PHASE_W-1:0]        phase_inc_active,
    output wire signed [DATA_W-1:0]  sample_raw,
    output wire signed [DATA_W-1:0]  sample_out,
    output wire                      sample_valid
);

    reg  [PHASE_W-1:0] phase_inc_reg;
    reg  [PHASE_W-1:0] phase_offset_reg;
    reg                cfg_loaded;
    reg  [1:0]         valid_pipe;

    wire [ADDR_W-1:0]         phase_addr_i;
    wire signed [DATA_W-1:0]  sine_sample;
    wire signed [DATA_W-1:0]  shape_sample;
    wire signed [DATA_W-1:0]  bram_sample;
    wire signed [DATA_W-1:0]  mux_sample;
    wire [PHASE_W-1:0]        phase_inc_drive;

    //--------------------------------------------------------------------------
    // 控制字寄存
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_inc_reg    <= {PHASE_W{1'b0}};
            phase_offset_reg <= {PHASE_W{1'b0}};
            cfg_loaded       <= 1'b0;
            valid_pipe       <= 2'b00;
        end else begin
            valid_pipe <= {valid_pipe[0], 1'b1};
            if (freq_load) begin
                phase_inc_reg    <= phase_inc;
                phase_offset_reg <= phase_offset;
                cfg_loaded       <= 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    // DDS 相位地址
    //--------------------------------------------------------------------------
    sweep_engine #(
        .PHASE_W     (PHASE_W),
        .DWELL_TICKS (SWEEP_DWELL_TICKS),
        .START_INC   (SWEEP_START_INC),
        .STOP_INC    (SWEEP_STOP_INC),
        .STEP_INC    (SWEEP_STEP_INC)
    ) u_sweep_engine (
        .clk              (clk),
        .rst_n            (rst_n),
        .enable           (wave_mode == 3'd6),
        .manual_phase_inc (phase_inc_reg),
        .phase_inc_out    (phase_inc_drive),
        .sweep_active     ()
    );

    dds_nco #(
        .PHASE_W (PHASE_W),
        .ADDR_W  (ADDR_W)
    ) u_dds_nco (
        .clk          (clk),
        .rst_n        (rst_n),
        .freq_load    (1'b0),
        .phase_inc    (phase_inc_drive),
        .phase_offset (phase_offset_reg),
        .phase_addr   (phase_addr_i),
        .addr_valid   ()
    );

    //--------------------------------------------------------------------------
    // 波形生成
    //--------------------------------------------------------------------------
    sine_lut #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .DEPTH  (4096)
    ) u_sine_lut (
        .clk  (clk),
        .addr (phase_addr_i),
        .data (sine_sample)
    );

    wave_shape_gen #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) u_wave_shape (
        .addr     (phase_addr_i),
        .mode     (wave_mode),
        .wave_out (shape_sample)
    );

    bram_wave_player #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) u_bram_wave_player (
        .clk        (clk),
        .addr       (phase_addr_i),
        .sample_out (bram_sample)
    );

    sample_mux #(
        .DATA_W (DATA_W)
    ) u_sample_mux (
        .mode         (wave_mode),
        .sine_sample  (sine_sample),
        .shape_sample (shape_sample),
        .bram_sample  (bram_sample),
        .test_sample  (test_sample),
        .sample_out   (mux_sample)
    );

    amp_offset_scale #(
        .DATA_W (DATA_W)
    ) u_amp_offset_scale (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_in  (mux_sample),
        .amplitude  (amplitude),
        .offset     (offset),
        .sample_out (sample_out)
    );

    assign phase_addr   = phase_addr_i;
    assign phase_inc_active = phase_inc_drive;
    assign sample_raw   = mux_sample;
    assign sample_valid = cfg_loaded & valid_pipe[1];

endmodule
