//------------------------------------------------------------------------------
// AWG Core Unified Testbench
// 【AWG 核心模块统一测试平台】
//
// 测试范围：
//   1. dds_nco     : 64bit 相位累加器 + 地址输出
//   2. sine_lut    : 正弦查表 ROM
//   3. wave_shape_gen : 方波 / 三角波 / 锯齿波
//   4. sample_mux  : 波形选择
//   5. amp_offset_scale : 幅度缩放 + 偏置 + 饱和限幅
//
// 仿真参数：
//   时钟：100MHz（10ns 周期）
//   DDS 频率：phase_inc = 2^56 → 256 拍/周期 → 390.625 kHz
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_awg_core;

    //----------------------------------------------------------------------
    // 参数
    //----------------------------------------------------------------------
    localparam CLK_PERIOD = 10;                              // 100MHz
    localparam PHASE_W    = 64;
    localparam ADDR_W     = 12;
    localparam DATA_W     = 16;
    // phase_inc = 2^56 → 256 个时钟周期走完 4096 点 LUT
    localparam PHASE_INC  = 64'h0100_0000_0000_0000;

    //----------------------------------------------------------------------
    // 信号声明
    //----------------------------------------------------------------------
    reg              clk;
    reg              rst_n;
    reg              freq_load;
    reg  [PHASE_W-1:0] phase_inc_val;
    reg  [PHASE_W-1:0] phase_offset;
    reg  [2:0]       wave_mode;
    reg  [DATA_W-1:0] amplitude;
    reg  signed [DATA_W-1:0] offset;
    
    wire [ADDR_W-1:0] phase_addr;
    wire              addr_valid;
    wire signed [DATA_W-1:0] sine_sample;
    wire signed [DATA_W-1:0] shape_sample;
    wire signed [DATA_W-1:0] sample_mux_out;
    wire signed [DATA_W-1:0] final_sample;
    wire [ADDR_W-1:0] core_phase_addr;
    wire signed [DATA_W-1:0] core_sample_raw;
    wire signed [DATA_W-1:0] core_sample_out;
    wire              core_sample_valid;
    
    // 测试码型：简单的斜坡，用于 mode=4
    wire signed [DATA_W-1:0] test_ramp;
    assign test_ramp = {1'b0, phase_addr[ADDR_W-2:0], 3'b000} - 16'sd8192;

    integer error_cnt;
    integer sample_cnt;
    reg signed [DATA_W-1:0] peak_max;
    reg signed [DATA_W-1:0] peak_min;

    //----------------------------------------------------------------------
    // 时钟产生
    //----------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //----------------------------------------------------------------------
    // 复位产生
    //----------------------------------------------------------------------
    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
    end

    //----------------------------------------------------------------------
    // 被测模块实例化
    //----------------------------------------------------------------------
    dds_nco #(.PHASE_W(PHASE_W), .ADDR_W(ADDR_W)) u_dds_nco (
        .clk          (clk),
        .rst_n        (rst_n),
        .freq_load    (freq_load),
        .phase_inc    (phase_inc_val),
        .phase_offset (phase_offset),
        .phase_addr   (phase_addr),
        .addr_valid   (addr_valid)
    );

    sine_lut #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(4096)) u_sine_lut (
        .clk  (clk),
        .addr (phase_addr),
        .data (sine_sample)
    );

    wave_shape_gen #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_wave_shape (
        .addr      (phase_addr),
        .mode      (wave_mode),
        .wave_out  (shape_sample)
    );

    sample_mux #(.DATA_W(DATA_W)) u_mux (
        .mode          (wave_mode),
        .sine_sample   (sine_sample),
        .shape_sample  (shape_sample),
        .test_sample   (test_ramp),
        .sample_out    (sample_mux_out)
    );

    amp_offset_scale #(.DATA_W(DATA_W)) u_amp (
        .clk        (clk),
        .rst_n      (rst_n),
        .sample_in  (sample_mux_out),
        .amplitude  (amplitude),
        .offset     (offset),
        .sample_out (final_sample)
    );

    awg_core #(
        .PHASE_W (PHASE_W),
        .ADDR_W  (ADDR_W),
        .DATA_W  (DATA_W)
    ) u_awg_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .freq_load    (freq_load),
        .phase_inc    (phase_inc_val),
        .phase_offset (phase_offset),
        .wave_mode    (wave_mode),
        .amplitude    (amplitude),
        .offset       (offset),
        .test_sample  (test_ramp),
        .phase_addr   (core_phase_addr),
        .sample_raw   (core_sample_raw),
        .sample_out   (core_sample_out),
        .sample_valid (core_sample_valid)
    );

    //----------------------------------------------------------------------
    // 主测试流程
    //----------------------------------------------------------------------
    initial begin
        error_cnt = 0;
        sample_cnt = 0;
        peak_max = -32768;
        peak_min = 32767;
        
        // 初始化控制信号
        freq_load     = 1'b0;
        phase_inc_val = {PHASE_W{1'b0}};
        phase_offset  = {PHASE_W{1'b0}};
        wave_mode     = 3'd0;
        amplitude     = 16'h7FFF;   // 接近满幅
        offset        = 16'sd0;

        $display("============================================================");
        $display("AWG Core Unified Testbench Start");
        $display("============================================================");

        // 等待复位释放
        @(posedge rst_n);
        #(CLK_PERIOD * 2);

        //==================================================================
        // TEST 1: 正弦波（Sine）
        //==================================================================
        $display("\n[TEST 1] Sine wave output");
        phase_inc_val = PHASE_INC;
        freq_load     = 1'b1;
        @(posedge clk);
        freq_load     = 1'b0;
        wave_mode     = 3'd0;   // sine
        amplitude     = 16'h7FFF;
        offset        = 16'sd0;

        // 收集 512 个样本，观察峰峰值
        peak_max = -32768;
        peak_min = 32767;
        repeat (512) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid) begin
                if (core_sample_out !== final_sample) begin
                    $display("  [FAIL] Core wrapper mismatch in sine test: ref=%0d dut=%0d",
                             final_sample, core_sample_out);
                    error_cnt = error_cnt + 1;
                end
                if (core_sample_raw !== sample_mux_out) begin
                    $display("  [FAIL] Core raw mismatch in sine test: ref=%0d dut=%0d",
                             sample_mux_out, core_sample_raw);
                    error_cnt = error_cnt + 1;
                end
            end
        end
        $display("  Peak max = %d  Peak min = %d  (expect ~32767 / ~-32768)",
                 peak_max, peak_min);
        if (peak_max < 30000 || peak_min > -30000) begin
            $display("  [FAIL] Sine amplitude too small!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] Sine amplitude OK");
        end

        //==================================================================
        // TEST 2: 方波（Square）
        //==================================================================
        $display("\n[TEST 2] Square wave output");
        wave_mode = 3'd1;
        #100;   // 等待流水线刷新
        peak_max = -32768;
        peak_min = 32767;
        repeat (300) begin  // 必须 >256 拍，确保覆盖正负半周
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in square test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d  (expect ~32766 / ~-32767)",
                 peak_max, peak_min);
        // Note: amplitude=0x7FFF = 32767/32768, so max level is 32766 not 32767
        if (peak_max < 32760 || peak_min > -32760) begin
            $display("  [FAIL] Square levels incorrect!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] Square levels OK");
        end

        //==================================================================
        // TEST 3: 三角波（Triangle）
        //==================================================================
        $display("\n[TEST 3] Triangle wave output");
        wave_mode = 3'd2;
        #100;
        peak_max = -32768;
        peak_min = 32767;
        repeat (256) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in triangle test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d", peak_max, peak_min);
        if (peak_max < 30000 || peak_min > -30000) begin
            $display("  [FAIL] Triangle amplitude too small!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] Triangle amplitude OK");
        end

        //==================================================================
        // TEST 4: 锯齿波（Sawtooth）
        //==================================================================
        $display("\n[TEST 4] Sawtooth wave output");
        wave_mode = 3'd3;
        #100;
        peak_max = -32768;
        peak_min = 32767;
        repeat (256) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in saw test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d", peak_max, peak_min);
        if (peak_max < 30000 || peak_min > -30000) begin
            $display("  [FAIL] Sawtooth amplitude too small!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] Sawtooth amplitude OK");
        end

        //==================================================================
        // TEST 5: 幅度缩放（Amplitude = 50%）
        //==================================================================
        $display("\n[TEST 5] Amplitude scaling (50%%)");
        wave_mode     = 3'd0;       // sine
        amplitude     = 16'h4000;   // 0.5
        offset        = 16'sd0;
        #100;
        peak_max = -32768;
        peak_min = 32767;
        repeat (256) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in amp test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d  (expect ~16383 / ~-16384)",
                 peak_max, peak_min);
        if (peak_max < 15000 || peak_max > 17000 || peak_min > -15000 || peak_min < -17000) begin
            $display("  [FAIL] 50 pct amplitude scaling incorrect!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] 50 pct amplitude scaling OK");
        end

        //==================================================================
        // TEST 6: 偏置叠加（Offset = +10000）
        //==================================================================
        $display("\n[TEST 6] DC offset (+10000)");
        amplitude = 16'h4000;   // 保持 50%
        offset    = 16'sd10000;
        #100;
        peak_max = -32768;
        peak_min = 32767;
        repeat (256) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in offset test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d  (expect ~+26383 / ~-6384)",
                 peak_max, peak_min);
        if (peak_max < 25000 || peak_max > 27000 || peak_min > -5000 || peak_min < -7000) begin
            $display("  [FAIL] DC offset incorrect!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] DC offset OK");
        end

        //==================================================================
        // TEST 7: 饱和限幅（大偏置导致削顶）
        //==================================================================
        $display("\n[TEST 7] Saturation test (large offset)");
        amplitude = 16'h7FFF;   // 满幅
        offset    = 16'sd20000; // 大偏置，应该削顶
        #100;
        peak_max = -32768;
        peak_min = 32767;
        repeat (256) begin
            @(posedge clk);
            #1;
            if (final_sample > peak_max) peak_max = final_sample;
            if (final_sample < peak_min) peak_min = final_sample;
            if (core_sample_valid && core_sample_out !== final_sample) begin
                $display("  [FAIL] Core wrapper mismatch in saturation test: ref=%0d dut=%0d",
                         final_sample, core_sample_out);
                error_cnt = error_cnt + 1;
            end
        end
        $display("  Peak max = %d  Peak min = %d  (expect 32767 / >0)",
                 peak_max, peak_min);
        if (peak_max != 32767) begin
            $display("  [FAIL] Positive saturation not working!");
            error_cnt = error_cnt + 1;
        end else begin
            $display("  [PASS] Saturation limiter OK");
        end

        //==================================================================
        // 结果汇总
        //==================================================================
        $display("\n============================================================");
        if (error_cnt == 0)
            $display("[PASS] All AWG core tests passed! (0 errors)");
        else
            $display("[FAIL] %0d error(s) detected!", error_cnt);
        $display("============================================================");
        
        $finish;
    end

    //----------------------------------------------------------------------
    // 超时看门狗
    //----------------------------------------------------------------------
    initial begin
        #50000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

    //----------------------------------------------------------------------
    // VCD 波形输出
    //----------------------------------------------------------------------
    initial begin
        $dumpfile("awg_core_tb.vcd");
        $dumpvars(0, tb_awg_core);
    end

endmodule
