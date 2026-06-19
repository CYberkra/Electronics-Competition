//------------------------------------------------------------------------------
// EC11 Rotary Encoder Decoder (normalized v5)
// - 2-flop synchronizers for A/B/BTN
// - 2-bit AB debounce, not independent A/B debounce
// - Quadrature transition table with illegal-transition rejection
// - Accumulates valid quarter-steps to one detent pulse
// - Button debounce with short/long press pulses
//------------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module ec11_decoder #(
    parameter integer CLK_HZ           = 25_000_000,
    parameter integer QUAD_DEBOUNCE_US = 500,       // 0.5ms
    parameter integer BTN_DEBOUNCE_MS  = 5,
    parameter integer LONG_PRESS_MS    = 1000,
    parameter integer EDGES_PER_DETENT = 4,         // change to 2 if your EC11 has 2 edges/detent
    parameter         REVERSE_DIR      = 1'b0
) (
    input  wire              clk,
    input  wire              rst_n,

    input  wire              ec11_a,
    input  wire              ec11_b,
    input  wire              ec11_btn,       // active-low button

    output reg  signed [7:0] rotation,       // +1 / -1 one-clock pulse per detent
    output reg               btn_short,      // one-clock pulse on short-release
    output reg               btn_long        // one-clock pulse when long threshold reached
);

    localparam integer QUAD_DEBOUNCE_TICKS = (CLK_HZ / 1_000_000) * QUAD_DEBOUNCE_US;
    localparam integer BTN_DEBOUNCE_TICKS  = (CLK_HZ / 1000) * BTN_DEBOUNCE_MS;
    localparam integer LONG_PRESS_TICKS    = (CLK_HZ / 1000) * LONG_PRESS_MS;

    // -------------------------------------------------------------------------
    // Input synchronizers
    // -------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg a_s0, a_s1;
    (* ASYNC_REG = "TRUE" *) reg b_s0, b_s1;
    (* ASYNC_REG = "TRUE" *) reg btn_s0, btn_s1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_s0 <= 1'b1; a_s1 <= 1'b1;
            b_s0 <= 1'b1; b_s1 <= 1'b1;
            btn_s0 <= 1'b1; btn_s1 <= 1'b1;
        end else begin
            a_s0 <= ec11_a;   a_s1 <= a_s0;
            b_s0 <= ec11_b;   b_s1 <= b_s0;
            btn_s0 <= ec11_btn; btn_s1 <= btn_s0;
        end
    end

    // -------------------------------------------------------------------------
    // Debounce AB as a 2-bit state. This avoids artificial illegal states caused
    // by independently debouncing A and B.
    // -------------------------------------------------------------------------
    wire [1:0] ab_sync = {a_s1, b_s1};

    reg [1:0] ab_candidate;
    reg [1:0] ab_stable;
    reg [31:0] ab_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ab_candidate <= 2'b11;
            ab_stable    <= 2'b11;
            ab_cnt       <= 32'd0;
        end else begin
            if (ab_sync != ab_candidate) begin
                ab_candidate <= ab_sync;
                ab_cnt <= 32'd0;
            end else if (ab_stable != ab_candidate) begin
                if (ab_cnt >= QUAD_DEBOUNCE_TICKS) begin
                    ab_stable <= ab_candidate;
                    ab_cnt <= 32'd0;
                end else begin
                    ab_cnt <= ab_cnt + 1'b1;
                end
            end else begin
                ab_cnt <= 32'd0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Quadrature transition table.
    // +1 sequence: 00->01->11->10->00
    // -1 sequence: 00->10->11->01->00
    // If physical direction is reversed, set REVERSE_DIR=1.
    // -------------------------------------------------------------------------
    localparam signed [4:0] DETENT_POS = EDGES_PER_DETENT;
    localparam signed [4:0] DETENT_NEG = -EDGES_PER_DETENT;

    reg [1:0] ab_prev;
    reg signed [3:0] edge_acc;
    reg signed [1:0] edge_dir;
    reg signed [1:0] edge_dir_final;
    wire signed [4:0] edge_acc_next = $signed({edge_acc[3], edge_acc}) + $signed({{3{edge_dir_final[1]}}, edge_dir_final});

    always @(*) begin
        edge_dir = 2'sd0;
        case ({ab_prev, ab_stable})
            4'b0001,
            4'b0111,
            4'b1110,
            4'b1000: edge_dir = 2'sd1;

            4'b0010,
            4'b1011,
            4'b1101,
            4'b0100: edge_dir = -2'sd1;

            default: edge_dir = 2'sd0;
        endcase

        edge_dir_final = REVERSE_DIR ? -edge_dir : edge_dir;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ab_prev  <= 2'b11;
            edge_acc <= 4'sd0;
            rotation <= 8'sd0;
        end else begin
            rotation <= 8'sd0;

            if (ab_stable != ab_prev) begin
                ab_prev <= ab_stable;

                if (edge_dir_final == 2'sd0) begin
                    edge_acc <= 4'sd0;  // reject bounce/illegal jump
                end else begin
                    if (edge_acc_next >= DETENT_POS) begin
                        rotation <= 8'sd1;
                        edge_acc <= 4'sd0;
                    end else if (edge_acc_next <= DETENT_NEG) begin
                        rotation <= -8'sd1;
                        edge_acc <= 4'sd0;
                    end else begin
                        edge_acc <= edge_acc_next[3:0];
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Button debounce and short/long press
    // -------------------------------------------------------------------------
    reg        btn_candidate;
    reg        btn_stable;
    reg [31:0] btn_cnt;
    reg        btn_was_down;
    reg [31:0] hold_cnt;
    reg        long_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_candidate <= 1'b1;
            btn_stable    <= 1'b1;
            btn_cnt       <= 32'd0;
            btn_was_down  <= 1'b0;
            hold_cnt      <= 32'd0;
            long_latched  <= 1'b0;
            btn_short     <= 1'b0;
            btn_long      <= 1'b0;
        end else begin
            btn_short <= 1'b0;
            btn_long  <= 1'b0;

            if (btn_s1 != btn_candidate) begin
                btn_candidate <= btn_s1;
                btn_cnt <= 32'd0;
            end else if (btn_stable != btn_candidate) begin
                if (btn_cnt >= BTN_DEBOUNCE_TICKS) begin
                    btn_stable <= btn_candidate;
                    btn_cnt <= 32'd0;
                end else begin
                    btn_cnt <= btn_cnt + 1'b1;
                end
            end else begin
                btn_cnt <= 32'd0;
            end

            if (!btn_stable) begin
                btn_was_down <= 1'b1;
                if (hold_cnt < LONG_PRESS_TICKS) begin
                    hold_cnt <= hold_cnt + 1'b1;
                end else if (!long_latched) begin
                    btn_long <= 1'b1;
                    long_latched <= 1'b1;
                end
            end else begin
                if (btn_was_down) begin
                    if (!long_latched) begin
                        btn_short <= 1'b1;
                    end
                    btn_was_down <= 1'b0;
                    hold_cnt <= 32'd0;
                    long_latched <= 1'b0;
                end
            end
        end
    end

endmodule

`default_nettype wire
