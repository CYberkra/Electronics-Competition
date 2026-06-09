// Testbench: KEY0/KEY1 + LED on sys_clk_bufg (100MHz sys_clk)
// No dependency on FMC/LMK/JESD - pure board-level test
`timescale 1ns / 1ps

module tb_key_led;
    reg clk_100m, rst_n;
    reg key0, key1;
    wire [1:0] led;

    // Clock: 100MHz = 10ns period
    initial clk_100m = 0;
    always #5 clk_100m = ~clk_100m;

    // DUT: key control + LED status (same as in awg_top)
    wire [47:0] key_phase_inc;
    wire [47:0] key_phase_offset;
    wire [2:0]  key_wave_mode_3b;
    wire [15:0] key_amplitude;
    wire signed [15:0] key_offset;
    wire [1:0]  key_ui_mode;
    wire        key_freq_load;

    awg_key_ui_ctrl #(
        .DEBOUNCE_TICKS (32'd10),       // shortened for sim
        .CHORD_TICKS    (32'd100),       // shortened
        .PHASE_W        (48),
        .DATA_W         (16)
    ) u_key_ctrl (
        .clk          (clk_100m),
        .rst_n        (rst_n),
        .key0         (key0),
        .key1         (key1),
        .freq_load    (key_freq_load),
        .phase_inc    (key_phase_inc),
        .phase_offset (key_phase_offset),
        .wave_mode    (key_wave_mode_3b),
        .amplitude    (key_amplitude),
        .offset       (key_offset),
        .test_sample  (),
        .ui_mode      (key_ui_mode)
    );

    reg [1:0] wave_led;
    always @(posedge clk_100m) begin
        wave_led[0] <= 1'b0;  // No DDS running in this test
        wave_led[1] <= 1'b0;
    end

    awg_led_status #(
        .STATUS_TICKS (32'd50)
    ) u_led_status (
        .clk       (clk_100m),
        .rst_n     (rst_n),
        .ui_mode   (key_ui_mode),
        .wave_mode (key_wave_mode_3b),
        .phase_inc (key_phase_inc),
        .amplitude (key_amplitude),
        .offset    (key_offset),
        .wave_led  (wave_led),
        .led       (led)
    );

    integer step;

    initial begin
        $display("========================================");
        $display("TB: KEY/LED Basic Test");
        $display("========================================");
        rst_n = 0; key0 = 1; key1 = 1; step = 0;
        #100 rst_n = 1;
        #200;

        // Step 1: Default state
        step = 1;
        $display("Step 1: freq_sel=%d wave=%d amp=%d offset=%d",
            key_phase_inc, key_wave_mode_3b, key_amplitude, key_offset);
        #500;

        // Step 2: Press KEY0 (frequency up)
        step = 2;
        $display("Step 2: Press KEY0");
        key0 = 0;
        #200 key0 = 1;
        #2000;
        $display("  freq_sel=%d wave=%d amp=%d offset=%d ui_mode=%d",
            key_phase_inc, key_wave_mode_3b, key_amplitude, key_offset, key_ui_mode);

        // Step 3: Press KEY0 3 more times
        step = 3;
        key0 = 0; #200 key0 = 1; #2000;
        key0 = 0; #200 key0 = 1; #2000;
        key0 = 0; #200 key0 = 1; #2000;
        $display("Step 3: freq_sel=%d", key_phase_inc);
        $display("  (expect: changed 4 steps from default 1Hz)");

        // Step 4: Long press to change parameter group
        step = 4;
        $display("Step 4: Long press KEY0 (switch to wave mode)");
        key0 = 0;
        #3000 key0 = 1;  // > CHORD_TICKS=100*10ns=1000ns? Actually 3000ns > 1000ns
        #2000;
        $display("  ui_mode=%d wave_mode=%d (expect ui_mode=1, wave cycling)", key_ui_mode, key_wave_mode_3b);

        // Step 5: Press KEY0 to cycle wave modes
        step = 5;
        key0 = 0; #200 key0 = 1; #2000;
        key0 = 0; #200 key0 = 1; #2000;
        key0 = 0; #200 key0 = 1; #2000;
        $display("Step 5: wave_mode=%d (expect: 1->2->3)", key_wave_mode_3b);

        $display("========================================");
        $display("TB COMPLETE");
        $display("========================================");
        #500 $finish;
    end

    // Watchdog timeout
    initial #100000 begin
        $display("TIMEOUT");
        $finish;
    end
endmodule
