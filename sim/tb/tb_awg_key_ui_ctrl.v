//------------------------------------------------------------------------------
// AWG Key UI Control Testbench
// 【AWG 按键控制层测试平台】
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_awg_key_ui_ctrl;

    localparam CLK_PERIOD = 10;   // 100MHz
    localparam PHASE_W    = 48;
    localparam DATA_W     = 16;

    reg clk;
    reg rst_n;
    reg key0;
    reg key1;

    wire                freq_load;
    wire [PHASE_W-1:0]  phase_inc;
    wire [PHASE_W-1:0]  phase_offset;
    wire [2:0]          wave_mode;
    wire [DATA_W-1:0]   amplitude;
    wire signed [DATA_W-1:0] offset;
    wire signed [DATA_W-1:0] test_sample;
    wire [1:0]          ui_mode;

    integer error_cnt;
    integer freq_load_pulses;

    awg_key_ui_ctrl #(
        .DEBOUNCE_TICKS (32'd3),
        .CHORD_TICKS    (32'd8),
        .PHASE_W        (PHASE_W),
        .DATA_W         (DATA_W)
    ) u_dut (
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

    always #(CLK_PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (freq_load) begin
            freq_load_pulses = freq_load_pulses + 1;
        end
    end

    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
            #1;
        end
    endtask

    task press_key0;
        input integer low_cycles;
        begin
            key0 = 1'b0;
            wait_cycles(low_cycles);
            key0 = 1'b1;
            wait_cycles(10);
        end
    endtask

    task press_key1;
        input integer low_cycles;
        begin
            key1 = 1'b0;
            wait_cycles(low_cycles);
            key1 = 1'b1;
            wait_cycles(10);
        end
    endtask

    task press_both;
        input integer low_cycles;
        begin
            key0 = 1'b0;
            key1 = 1'b0;
            wait_cycles(low_cycles);
            key0 = 1'b1;
            key1 = 1'b1;
            wait_cycles(10);
        end
    endtask

    task check_cond;
        input condition;
        input [1023:0] msg;
        begin
            if (!condition) begin
                $display("  [FAIL] %s", msg);
                error_cnt = error_cnt + 1;
            end else begin
                $display("  [PASS] %s", msg);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        key0 = 1'b1;
        key1 = 1'b1;
        error_cnt = 0;
        freq_load_pulses = 0;

        $display("============================================================");
        $display("AWG Key UI Control TB Start");
        $display("============================================================");

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(10);

        $display("\n[TEST 1] Reset defaults");
        check_cond(ui_mode == 2'd0, "ui_mode == 0");
        check_cond(wave_mode == 3'd0, "wave_mode == sine");
        check_cond(amplitude == 16'h4000, "amplitude default == 0x4000");
        check_cond(offset == 16'sd0, "offset default == 0");
        check_cond(test_sample == offset, "test_sample follows offset");
        check_cond(phase_offset == 48'd0, "phase_offset == 0");
        check_cond(phase_inc == 48'h0000000002AF31E, "phase_inc default == 1Hz");
        check_cond(freq_load_pulses >= 1, "initial freq_load pulse seen");

        $display("\n[TEST 2] KEY0 short press increments frequency");
        press_key0(6);
        check_cond(phase_inc == 48'h000000001AD7F2A, "phase_inc == 10Hz after KEY0");
        check_cond(freq_load_pulses >= 2, "freq_load pulse incremented");

        $display("\n[TEST 3] Dual-key long press switches to wave mode");
        press_both(10);
        check_cond(ui_mode == 2'd1, "ui_mode == 1");

        $display("\n[TEST 4] KEY0 in wave mode selects next waveform");
        press_key0(6);
        check_cond(wave_mode == 3'd1, "wave_mode == square");

        $display("\n[TEST 5] Dual-key long press switches to amplitude mode");
        press_both(10);
        check_cond(ui_mode == 2'd2, "ui_mode == 2");

        $display("\n[TEST 6] KEY0 in amplitude mode steps amplitude");
        press_key0(6);
        check_cond(amplitude == 16'h6000, "amplitude == 0x6000");

        $display("\n[TEST 7] Dual-key long press switches to offset mode");
        press_both(10);
        check_cond(ui_mode == 2'd3, "ui_mode == 3");

        $display("\n[TEST 8] KEY1 in offset mode steps offset down");
        press_key1(6);
        check_cond(offset == -16'sd6000, "offset == -6000");
        check_cond(test_sample == offset, "test_sample follows offset");

        $display("\n[TEST 9] Wrap back to frequency mode");
        press_both(10);
        check_cond(ui_mode == 2'd0, "ui_mode wraps back to 0");

        if (error_cnt == 0) begin
            $display("\n============================================================");
            $display("[PASS] All AWG key UI control tests passed!");
            $display("============================================================");
        end else begin
            $display("\n============================================================");
            $display("[FAIL] %0d error(s) detected!", error_cnt);
            $display("============================================================");
        end

        #20;
        $finish;
    end

endmodule
