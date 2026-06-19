//------------------------------------------------------------------------------
// EC11 -> AWG Register Bridge (v6)
// - Register-control enable and full current-shadow sync after reset/long press
// - User edits never force a default re-initialization after timeout
// - Timeout recovery keeps TFT UI alive and preserves UI shadow values
// - Correct DDS FCW step constants for 1GS/s effective sample rate
// - Auto-applies after every parameter edit
//------------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module ec11_awg_bridge #(
    parameter integer CLK_HZ             = 25_000_000,
    parameter integer WR_TIMEOUT_MS      = 1000,
    parameter integer DEFAULT_STEP_INDEX = 5           // 5 = 100kHz/detent
) (
    input  wire              clk,
    input  wire              rst_n,

    input  wire signed [7:0] rotation,                 // +1/-1 one-clock detent pulse
    input  wire              btn_short,
    input  wire              btn_long,

    input  wire              wr_ready,
    output reg               wr_en,
    output reg  [7:0]        wr_addr,
    output reg  [31:0]       wr_data,
    output reg               apply_trig,

    output reg  [1:0]        param_page,
    output reg               activity,
    output wire              write_busy,
    output reg               write_timeout,

    // 25MHz-domain UI shadow values for display/debug.
    output wire [47:0]       freq_shadow,
    output wire [13:0]       freq_tenth_mhz_shadow,    // MHz x10, e.g. 50.0MHz = 500
    output wire [1:0]        wave_shadow,
    output wire [15:0]       amp_shadow
);

    localparam [1:0] PAGE_FREQ = 2'd0;
    localparam [1:0] PAGE_WAVE = 2'd1;
    localparam [1:0] PAGE_AMP  = 2'd2;

    // phase_inc = f_out * 2^48 / 1e9, assuming 4 samples/clk at 250MHz = 1GS/s.
    localparam [47:0] STEP_1HZ    = 48'h000000044B83;
    localparam [47:0] STEP_10HZ   = 48'h0000002AF31E;
    localparam [47:0] STEP_100HZ  = 48'h000001AD7F2A;
    localparam [47:0] STEP_1KHZ   = 48'h000010C6F7A1;
    localparam [47:0] STEP_10KHZ  = 48'h0000A7C5AC47;
    localparam [47:0] STEP_100KHZ = 48'h00068DB8BAC7;
    localparam [47:0] STEP_1MHZ   = 48'h004189374BC7;
    localparam [47:0] STEP_10MHZ  = 48'h028F5C28F5C3;

    localparam [47:0] DEFAULT_FREQ = 48'h0CCCCCCCCCCD; // 50 MHz @ 1GS/s
    localparam [47:0] FREQ_MIN     = 48'h000010C6F7A1; // 1 kHz
    localparam [47:0] FREQ_MAX     = 48'h666666666666; // 400 MHz

    localparam [13:0] DEFAULT_FREQ_TENTH_MHZ = 14'd500;  // 50.0 MHz
    localparam [13:0] FREQ_MIN_TENTH_MHZ     = 14'd0;
    localparam [13:0] FREQ_MAX_TENTH_MHZ     = 14'd4000; // 400.0 MHz

    localparam [15:0] DEFAULT_AMP  = 16'h6000;
    localparam [15:0] AMP_MIN      = 16'h0400;
    localparam [15:0] AMP_MAX      = 16'h7F00;
    localparam [15:0] AMP_STEP     = 16'h0400;

    localparam [7:0] ADDR_CONTROL      = 8'h08;
    localparam [7:0] ADDR_PHASE_INC_LO = 8'h10;
    localparam [7:0] ADDR_PHASE_INC_HI = 8'h14;
    localparam [7:0] ADDR_AMPLITUDE    = 8'h20;
    localparam [7:0] ADDR_WAVE_MODE    = 8'h28;
    localparam [7:0] ADDR_APPLY        = 8'h2C;

    localparam [31:0] CONTROL_ENABLE_REG = 32'h00000003;
    localparam integer WR_TIMEOUT_TICKS = (CLK_HZ / 1000) * WR_TIMEOUT_MS;

    localparam [3:0] S_IDLE        = 4'd0;
    localparam [3:0] S_SYNC_CTRL   = 4'd1;
    localparam [3:0] S_SYNC_FREQ_LO= 4'd2;
    localparam [3:0] S_SYNC_FREQ_HI= 4'd3;
    localparam [3:0] S_SYNC_AMP    = 4'd4;
    localparam [3:0] S_SYNC_WAVE   = 4'd5;
    localparam [3:0] S_SYNC_APPLY  = 4'd6;
    localparam [3:0] S_FREQ_LO     = 4'd7;
    localparam [3:0] S_FREQ_HI     = 4'd8;
    localparam [3:0] S_WAVE        = 4'd9;
    localparam [3:0] S_AMP         = 4'd10;
    localparam [3:0] S_APPLY       = 4'd11;

    reg [3:0]  st;
    reg        sync_pending;       // retry full current-shadow sync when tx clock/bus becomes available
    reg [31:0] wait_cnt;

    reg [1:0]  page;
    reg [47:0] freq_phase_inc;
    reg [47:0] pending_freq;
    reg [13:0] freq_tenth_mhz;
    reg [3:0]  freq_step_idx;
    reg [1:0]  wave_sel;
    reg [1:0]  pending_wave;
    reg [15:0] amp_val;
    reg [15:0] pending_amp;

    reg btn_short_d, btn_long_d;

    assign write_busy            = (st != S_IDLE);
    assign freq_shadow           = freq_phase_inc;
    assign freq_tenth_mhz_shadow = freq_tenth_mhz;
    assign wave_shadow           = wave_sel;
    assign amp_shadow            = amp_val;

    function [47:0] freq_step;
        input [3:0] idx;
        begin
            case (idx)
                4'd0: freq_step = STEP_1HZ;
                4'd1: freq_step = STEP_10HZ;
                4'd2: freq_step = STEP_100HZ;
                4'd3: freq_step = STEP_1KHZ;
                4'd4: freq_step = STEP_10KHZ;
                4'd5: freq_step = STEP_100KHZ;
                4'd6: freq_step = STEP_1MHZ;
                4'd7: freq_step = STEP_10MHZ;
                default: freq_step = STEP_100KHZ;
            endcase
        end
    endfunction

    function [13:0] freq_step_tenth_mhz;
        input [3:0] idx;
        begin
            case (idx)
                4'd5: freq_step_tenth_mhz = 14'd1;    // 100kHz = 0.1MHz
                4'd6: freq_step_tenth_mhz = 14'd10;   // 1MHz
                4'd7: freq_step_tenth_mhz = 14'd100;  // 10MHz
                default: freq_step_tenth_mhz = 14'd0;
            endcase
        end
    endfunction

    function [47:0] freq_next_clamped;
        input [47:0] cur;
        input [47:0] step;
        input        inc;
        begin
            if (inc)
                freq_next_clamped = (cur >= (FREQ_MAX - step)) ? FREQ_MAX : (cur + step);
            else
                freq_next_clamped = (cur <= (FREQ_MIN + step)) ? FREQ_MIN : (cur - step);
        end
    endfunction

    function [13:0] tenth_next_clamped;
        input [13:0] cur;
        input [13:0] step;
        input        inc;
        begin
            if (inc)
                tenth_next_clamped = (cur >= (FREQ_MAX_TENTH_MHZ - step)) ? FREQ_MAX_TENTH_MHZ : (cur + step);
            else
                tenth_next_clamped = (cur <= (FREQ_MIN_TENTH_MHZ + step)) ? FREQ_MIN_TENTH_MHZ : (cur - step);
        end
    endfunction

    wire rot_cw  = (rotation > 8'sd0);
    wire rot_ccw = (rotation < 8'sd0);
    wire [47:0] step_now = freq_step(freq_step_idx);
    wire [13:0] step_tenth_now = freq_step_tenth_mhz(freq_step_idx);
    wire [47:0] next_freq_wire = freq_next_clamped(freq_phase_inc, step_now, rot_cw);
    wire [13:0] next_tenth_wire = tenth_next_clamped(freq_tenth_mhz, step_tenth_now, rot_cw);
    wire [1:0] next_wave_wire = rot_cw ? ((wave_sel == 2'd3) ? 2'd0 : wave_sel + 1'b1)
                                       : ((wave_sel == 2'd0) ? 2'd3 : wave_sel - 1'b1);
    wire [15:0] next_amp_wire = rot_cw ? ((amp_val >= (AMP_MAX - AMP_STEP)) ? AMP_MAX : amp_val + AMP_STEP)
                                       : ((amp_val <= (AMP_MIN + AMP_STEP)) ? AMP_MIN : amp_val - AMP_STEP);

    task issue_write;
        input [7:0]  a;
        input [31:0] d;
        begin
            wr_en    <= 1'b1;
            wr_addr  <= a;
            wr_data  <= d;
            wait_cnt <= 32'd0;
        end
    endtask

    task handle_timeout;
        input retry_sync;
        begin
            if (wait_cnt >= WR_TIMEOUT_TICKS) begin
                st <= S_IDLE;
                sync_pending <= retry_sync;
                write_timeout <= 1'b1;
                wait_cnt <= 32'd0;
            end else begin
                wait_cnt <= wait_cnt + 1'b1;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st                     <= S_IDLE;
            sync_pending           <= 1'b1;
            wait_cnt               <= 32'd0;
            page                   <= PAGE_FREQ;
            param_page             <= PAGE_FREQ;
            freq_phase_inc         <= DEFAULT_FREQ;
            pending_freq           <= DEFAULT_FREQ;
            freq_tenth_mhz         <= DEFAULT_FREQ_TENTH_MHZ;
            freq_step_idx          <= DEFAULT_STEP_INDEX;
            wave_sel               <= 2'd0;
            pending_wave           <= 2'd0;
            amp_val                <= DEFAULT_AMP;
            pending_amp            <= DEFAULT_AMP;
            btn_short_d            <= 1'b0;
            btn_long_d             <= 1'b0;
            wr_en                  <= 1'b0;
            wr_addr                <= 8'd0;
            wr_data                <= 32'd0;
            apply_trig             <= 1'b0;
            activity               <= 1'b0;
            write_timeout          <= 1'b0;
        end else begin
            wr_en       <= 1'b0;
            apply_trig  <= 1'b0;
            activity    <= 1'b0;
            btn_short_d <= btn_short;
            btn_long_d  <= btn_long;

            case (st)
                S_IDLE: begin
                    wait_cnt <= 32'd0;
                    if (sync_pending && wr_ready) begin
                        st <= S_SYNC_CTRL;
                    end else if (btn_short && !btn_short_d) begin
                        if (page == PAGE_AMP) begin
                            page       <= PAGE_FREQ;
                            param_page <= PAGE_FREQ;
                        end else begin
                            page       <= page + 1'b1;
                            param_page <= page + 1'b1;
                        end
                        activity <= 1'b1;
                    end else if (btn_long && !btn_long_d) begin
                        // Long press retries full current-shadow sync, not a default reset.
                        sync_pending <= 1'b1;
                        st <= wr_ready ? S_SYNC_CTRL : S_IDLE;
                        activity <= 1'b1;
                    end else if (rot_cw || rot_ccw) begin
                        activity <= 1'b1;
                        case (page)
                            PAGE_FREQ: begin
                                pending_freq           <= next_freq_wire;
                                freq_phase_inc         <= next_freq_wire;
                                freq_tenth_mhz         <= next_tenth_wire;
                                st <= S_FREQ_LO;
                            end
                            PAGE_WAVE: begin
                                pending_wave <= next_wave_wire;
                                wave_sel     <= next_wave_wire;
                                st <= S_WAVE;
                            end
                            PAGE_AMP: begin
                                pending_amp <= next_amp_wire;
                                amp_val     <= next_amp_wire;
                                st <= S_AMP;
                            end
                            default: st <= S_IDLE;
                        endcase
                    end
                end

                // Full sync writes current shadow values. It is used at reset and on long press.
                S_SYNC_CTRL: begin
                    if (wr_ready) begin
                        issue_write(ADDR_CONTROL, CONTROL_ENABLE_REG);
                        st <= S_SYNC_FREQ_LO;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_SYNC_FREQ_LO: begin
                    if (wr_ready) begin
                        issue_write(ADDR_PHASE_INC_LO, freq_phase_inc[31:0]);
                        st <= S_SYNC_FREQ_HI;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_SYNC_FREQ_HI: begin
                    if (wr_ready) begin
                        issue_write(ADDR_PHASE_INC_HI, {16'd0, freq_phase_inc[47:32]});
                        st <= S_SYNC_AMP;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_SYNC_AMP: begin
                    if (wr_ready) begin
                        issue_write(ADDR_AMPLITUDE, {16'd0, amp_val});
                        st <= S_SYNC_WAVE;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_SYNC_WAVE: begin
                    if (wr_ready) begin
                        issue_write(ADDR_WAVE_MODE, {30'd0, wave_sel});
                        st <= S_SYNC_APPLY;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_SYNC_APPLY: begin
                    if (wr_ready) begin
                        issue_write(ADDR_APPLY, 32'd1);
                        apply_trig <= 1'b1;
                        sync_pending <= 1'b0;
                        write_timeout <= 1'b0;
                        st <= S_IDLE;
                    end else begin
                        handle_timeout(1'b1);
                    end
                end

                S_FREQ_LO: begin
                    if (wr_ready) begin
                        issue_write(ADDR_PHASE_INC_LO, pending_freq[31:0]);
                        st <= S_FREQ_HI;
                    end else begin
                        handle_timeout(1'b0);
                    end
                end

                S_FREQ_HI: begin
                    if (wr_ready) begin
                        issue_write(ADDR_PHASE_INC_HI, {16'd0, pending_freq[47:32]});
                        st <= S_APPLY;
                    end else begin
                        handle_timeout(1'b0);
                    end
                end

                S_WAVE: begin
                    if (wr_ready) begin
                        issue_write(ADDR_WAVE_MODE, {30'd0, pending_wave});
                        st <= S_APPLY;
                    end else begin
                        handle_timeout(1'b0);
                    end
                end

                S_AMP: begin
                    if (wr_ready) begin
                        issue_write(ADDR_AMPLITUDE, {16'd0, pending_amp});
                        st <= S_APPLY;
                    end else begin
                        handle_timeout(1'b0);
                    end
                end

                S_APPLY: begin
                    if (wr_ready) begin
                        issue_write(ADDR_APPLY, 32'd1);
                        apply_trig <= 1'b1;
                        write_timeout <= 1'b0;
                        st <= S_IDLE;
                    end else begin
                        handle_timeout(1'b0);
                    end
                end

                default: begin
                    st <= S_IDLE;
                    sync_pending <= 1'b1;
                    wait_cnt <= 32'd0;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
