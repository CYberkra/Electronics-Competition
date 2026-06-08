//------------------------------------------------------------------------------
// Testbench for ad9144_awg_cal
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_awg_cal;

    reg         clk;
    reg         rst_n;
    reg         cal_enable;
    reg  [1:0]  range_sel;
    reg  [47:0] phase_inc;
    reg  [15:0] amplitude_q15_in;
    wire [15:0] amplitude_q15_out;
    reg         cal_wr_en;
    reg  [3:0]  cal_wr_addr;
    reg  [31:0] cal_wr_data;
    reg         cal_rd_en;
    reg  [3:0]  cal_rd_addr;
    wire [31:0] cal_rd_data;
    integer     errors;

    ad9144_awg_cal uut (
        .clk               (clk),
        .rst_n             (rst_n),
        .cal_enable        (cal_enable),
        .range_sel         (range_sel),
        .phase_inc         (phase_inc),
        .amplitude_q15_in  (amplitude_q15_in),
        .amplitude_q15_out (amplitude_q15_out),
        .cal_wr_en         (cal_wr_en),
        .cal_wr_addr       (cal_wr_addr),
        .cal_wr_data       (cal_wr_data),
        .cal_rd_en         (cal_rd_en),
        .cal_rd_addr       (cal_rd_addr),
        .cal_rd_data       (cal_rd_data)
    );

    // 100MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper: write calibration coefficient
    task write_cal_entry;
        input [3:0]  addr;
        input [15:0] gain;
        input [15:0] offset;
        begin
            @(posedge clk);
            cal_wr_en   <= 1'b1;
            cal_wr_addr <= addr;
            cal_wr_data <= {offset, gain};
            @(posedge clk);
            cal_wr_en   <= 1'b0;
        end
    endtask

    // Helper: read calibration coefficient
    task read_cal_entry;
        input [3:0] addr;
        begin
            @(posedge clk);
            cal_rd_en   <= 1'b1;
            cal_rd_addr <= addr;
            @(posedge clk);
            cal_rd_en   <= 1'b0;
            @(posedge clk); // wait for data
        end
    endtask

    // Test sequence
    initial begin
        $display("========================================");
        $display("TB: ad9144_awg_cal started");
        $display("========================================");

        // Initialize
        errors            = 0;
        rst_n            <= 1'b0;
        cal_enable       <= 1'b0;
        range_sel        <= 2'd0;
        phase_inc        <= 48'd0;
        amplitude_q15_in <= 16'h6000;
        cal_wr_en        <= 1'b0;
        cal_rd_en        <= 1'b0;

        // Reset
        #100;
        rst_n <= 1'b1;
        #20;

        //--------------------------------------------------
        // Test 1: Default passthrough (cal_enable = 0)
        //--------------------------------------------------
        $display("[TEST 1] Passthrough mode (cal_enable=0)");
        amplitude_q15_in <= 16'h6000;
        phase_inc        <= 48'h0CCCCCCCCCCD; // 50 MHz
        @(posedge clk);
        @(posedge clk);
        #1;
        if (amplitude_q15_out === 16'h6000)
            $display("  PASS: output = 0x%04X (expected 0x6000)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x6000)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 2: Write calibration coefficients
        //--------------------------------------------------
        $display("[TEST 2] Write calibration coefficients");

        // Entry 0 (freq bin 0): gain = 0.5 (0x4000), offset = 100 (0x0064)
        write_cal_entry(4'd0, 16'h4000, 16'h0064);

        // Entry 1 (freq bin 1): gain ~= 2.0 (unsigned Q1.15 0xFFFF), offset = -50 (0xFFCE)
        write_cal_entry(4'd1, 16'hFFFF, 16'hFFCE);

        // Entry 2 (freq bin 2): gain = 1.0 (unsigned Q1.15 0x8000), offset = 0
        write_cal_entry(4'd2, 16'h8000, 16'h0000);

        // Verify write via readback
        read_cal_entry(4'd0);
        #1;
        if (cal_rd_data === {16'h0064, 16'h4000})
            $display("  PASS: cal_table[0] = 0x%08X", cal_rd_data);
        else begin
            $display("  FAIL: cal_table[0] = 0x%08X", cal_rd_data);
            errors = errors + 1;
        end

        read_cal_entry(4'd1);
        #1;
        if (cal_rd_data === {16'hFFCE, 16'hFFFF})
            $display("  PASS: cal_table[1] = 0x%08X", cal_rd_data);
        else begin
            $display("  FAIL: cal_table[1] = 0x%08X", cal_rd_data);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 3: Calibration enabled with unity gain
        //--------------------------------------------------
        $display("[TEST 3] Cal enabled, unity gain (bin 2)");
        phase_inc        <= {4'd2, 44'd0}; // freq_idx = 2
        amplitude_q15_in <= 16'h6000;
        cal_enable       <= 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        // 0x6000 * 0x8000 >> 15 = 0x6000
        if (amplitude_q15_out === 16'h6000)
            $display("  PASS: output = 0x%04X (expected 0x6000)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x6000)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 4: Calibration with gain = 0.5 (bin 0)
        //--------------------------------------------------
        $display("[TEST 4] Cal enabled, gain=0.5 (bin 0)");
        phase_inc        <= {4'd0, 44'd0}; // freq_idx = 0
        amplitude_q15_in <= 16'h6000;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        // 0x6000 * 0x4000 >> 15 = 0x3000, + offset 0x64 = 0x3064
        if (amplitude_q15_out === 16'h3064)
            $display("  PASS: output = 0x%04X (expected 0x3064)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x3064)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 5: Calibration with gain ~= 2.0 (bin 1)
        //--------------------------------------------------
        $display("[TEST 5] Cal enabled, gain~=2.0 (bin 1)");
        phase_inc        <= {4'd1, 44'd0}; // freq_idx = 1
        amplitude_q15_in <= 16'h2000;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        // 0x2000 * 0xFFFF >> 15 = 0x3FFF, + offset (-50) = 0x3FCD
        if (amplitude_q15_out === 16'h3FCD)
            $display("  PASS: output = 0x%04X (expected 0x3FCD)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x3FCD)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 6: Saturation test (gain too high)
        //--------------------------------------------------
        $display("[TEST 6] Saturation test");
        phase_inc        <= {4'd1, 44'd0}; // freq_idx = 1 (gain~=2.0)
        amplitude_q15_in <= 16'h7FFF;       // max input
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        // Should saturate to 0x7FFF
        if (amplitude_q15_out === 16'h7FFF)
            $display("  PASS: output = 0x%04X (saturated to max)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x7FFF)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Test 7: Disable calibration, verify passthrough resumes
        //--------------------------------------------------
        $display("[TEST 7] Disable calibration");
        cal_enable       <= 1'b0;
        amplitude_q15_in <= 16'h1234;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        if (amplitude_q15_out === 16'h1234)
            $display("  PASS: output = 0x%04X (expected 0x1234)", amplitude_q15_out);
        else begin
            $display("  FAIL: output = 0x%04X (expected 0x1234)", amplitude_q15_out);
            errors = errors + 1;
        end

        //--------------------------------------------------
        // Done
        //--------------------------------------------------
        $display("========================================");
        if (errors == 0)
            $display("TB: ad9144_awg_cal completed with 0 errors");
        else begin
            $display("TB: ad9144_awg_cal completed with %0d errors", errors);
            $fatal(1);
        end
        $display("========================================");
        #100;
        $finish;
    end

endmodule
