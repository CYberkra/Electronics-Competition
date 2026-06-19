`timescale 1ns / 1ps
`default_nettype none

//------------------------------------------------------------------------------
// AWG Display Update — clean, responsive TFT status/menu writer
//
// Character grid: 30 columns x 17 rows. This version uses a row/column UI
// character function instead of a long per-character case table, making the
// layout easier to maintain while still rewriting the full visible text area in
// about 20us at 25MHz. It clears implicitly by writing spaces for unspecified
// cells, so stale characters cannot remain after shorter status strings.
//------------------------------------------------------------------------------

module awg_display_update (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        init_done,

    input  wire [13:0] freq_tenth_mhz,  // MHz x10, e.g. 50.0MHz = 500
    input  wire [1:0]  wave_mode,
    input  wire [15:0] amplitude_q15,
    input  wire [15:0] offset,
    input  wire        output_enable,
    input  wire        sweep_active,
    input  wire        jesd_sync,
    input  wire [3:0]  init_state,
    input  wire [1:0]  param_page,      // 0=FREQ 1=WAVE 2=AMP
    input  wire        ec11_write_busy,
    input  wire        ec11_write_timeout,

    output reg         grid_wr_en,
    output reg  [8:0]  grid_wr_addr,
    output reg  [7:0]  grid_wr_data
);

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_WRITE = 2'd1;
    localparam [1:0] S_DONE  = 2'd2;

    localparam [8:0]  GRID_LAST     = 9'd509;
    localparam [23:0] REFRESH_TICKS = 24'd12_500_000; // 500ms @ 25MHz

    reg [1:0]  state;
    reg [8:0]  wr_addr;
    reg [4:0]  row;
    reg [4:0]  col;
    reg [23:0] timer;

    // Snapshot registers let the display refresh immediately on UI-relevant changes.
    reg [13:0] freq_tenth_mhz_d;
    reg [1:0]  wave_mode_d;
    reg [15:0] amplitude_q15_d;
    reg        output_enable_d;
    reg        sweep_active_d;
    reg        jesd_sync_d;
    reg [3:0]  init_state_d;
    reg [1:0]  param_page_d;
    reg        ec11_write_busy_d;
    reg        ec11_write_timeout_d;

    wire ui_dirty = (freq_tenth_mhz       != freq_tenth_mhz_d)       ||
                    (wave_mode            != wave_mode_d)            ||
                    (amplitude_q15        != amplitude_q15_d)        ||
                    (output_enable        != output_enable_d)        ||
                    (sweep_active         != sweep_active_d)         ||
                    (jesd_sync            != jesd_sync_d)            ||
                    (init_state           != init_state_d)           ||
                    (param_page           != param_page_d)           ||
                    (ec11_write_busy      != ec11_write_busy_d)      ||
                    (ec11_write_timeout   != ec11_write_timeout_d);

    // Exact UI display value comes from EC11 bridge shadow in MHz x10.
    wire [3:0] freq_hund = (freq_tenth_mhz / 14'd1000) % 10;
    wire [3:0] freq_tens = (freq_tenth_mhz / 14'd100)  % 10;
    wire [3:0] freq_ones = (freq_tenth_mhz / 14'd10)   % 10;
    wire [3:0] freq_frac =  freq_tenth_mhz              % 10;

    task latch_ui_snapshot;
    begin
        freq_tenth_mhz_d     <= freq_tenth_mhz;
        wave_mode_d          <= wave_mode;
        amplitude_q15_d      <= amplitude_q15;
        output_enable_d      <= output_enable;
        sweep_active_d       <= sweep_active;
        jesd_sync_d          <= jesd_sync;
        init_state_d         <= init_state;
        param_page_d         <= param_page;
        ec11_write_busy_d    <= ec11_write_busy;
        ec11_write_timeout_d <= ec11_write_timeout;
    end
    endtask

    task start_refresh;
    begin
        wr_addr <= 9'd0;
        row     <= 5'd0;
        col     <= 5'd0;
        timer   <= 24'd0;
        state   <= S_WRITE;
        latch_ui_snapshot();
    end
    endtask

    function [7:0] asc_digit;
        input [3:0] d;
        begin
            asc_digit = 8'h30 + d;
        end
    endfunction

    function [7:0] hex_digit;
        input [3:0] d;
        begin
            hex_digit = (d < 4'd10) ? (8'h30 + d) : (8'h41 + (d - 4'd10));
        end
    endfunction

    function [7:0] wave_char;
        input [1:0] mode;
        input [1:0] pos;
        begin
            case (mode)
                2'd0: begin // SINE
                    case (pos)
                        2'd0: wave_char = 8'h53;
                        2'd1: wave_char = 8'h49;
                        2'd2: wave_char = 8'h4E;
                        default: wave_char = 8'h45;
                    endcase
                end
                2'd1: begin // TRI
                    case (pos)
                        2'd0: wave_char = 8'h54;
                        2'd1: wave_char = 8'h52;
                        2'd2: wave_char = 8'h49;
                        default: wave_char = 8'h20;
                    endcase
                end
                2'd2: begin // SQR
                    case (pos)
                        2'd0: wave_char = 8'h53;
                        2'd1: wave_char = 8'h51;
                        2'd2: wave_char = 8'h52;
                        default: wave_char = 8'h20;
                    endcase
                end
                default: begin // SAW
                    case (pos)
                        2'd0: wave_char = 8'h53;
                        2'd1: wave_char = 8'h41;
                        2'd2: wave_char = 8'h57;
                        default: wave_char = 8'h20;
                    endcase
                end
            endcase
        end
    endfunction

    function [7:0] status_char;
        input       busy;
        input       timeout;
        input [3:0] pos;
        begin
            if (timeout) begin // WR TIMEOUT
                case (pos)
                    4'd0: status_char = 8'h57;
                    4'd1: status_char = 8'h52;
                    4'd2: status_char = 8'h20;
                    4'd3: status_char = 8'h54;
                    4'd4: status_char = 8'h49;
                    4'd5: status_char = 8'h4D;
                    4'd6: status_char = 8'h45;
                    4'd7: status_char = 8'h4F;
                    4'd8: status_char = 8'h55;
                    default: status_char = 8'h54;
                endcase
            end else if (busy) begin // WR BUSY
                case (pos)
                    4'd0: status_char = 8'h57;
                    4'd1: status_char = 8'h52;
                    4'd2: status_char = 8'h20;
                    4'd3: status_char = 8'h42;
                    4'd4: status_char = 8'h55;
                    4'd5: status_char = 8'h53;
                    4'd6: status_char = 8'h59;
                    default: status_char = 8'h20;
                endcase
            end else begin // EC11 OK
                case (pos)
                    4'd0: status_char = 8'h45;
                    4'd1: status_char = 8'h43;
                    4'd2: status_char = 8'h31;
                    4'd3: status_char = 8'h31;
                    4'd4: status_char = 8'h20;
                    4'd5: status_char = 8'h4F;
                    4'd6: status_char = 8'h4B;
                    default: status_char = 8'h20;
                endcase
            end
        end
    endfunction

    function [7:0] ui_char;
        input [4:0] row_i;
        input [4:0] col_i;
        begin
            ui_char = 8'h20;
            case (row_i)
                5'd0: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h20;
                        5'd3: ui_char = 8'h20;
                        5'd4: ui_char = 8'h20;
                        5'd5: ui_char = 8'h20;
                        5'd6: ui_char = 8'h20;
                        5'd7: ui_char = 8'h20;
                        5'd8: ui_char = 8'h4B; // K
                        5'd9: ui_char = 8'h33; // 3
                        5'd10: ui_char = 8'h32; // 2
                        5'd11: ui_char = 8'h35; // 5
                        5'd12: ui_char = 8'h54; // T
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h41; // A
                        5'd15: ui_char = 8'h57; // W
                        5'd16: ui_char = 8'h47; // G
                        5'd17: ui_char = 8'h20;
                        5'd18: ui_char = 8'h4D; // M
                        5'd19: ui_char = 8'h45; // E
                        5'd20: ui_char = 8'h4E; // N
                        5'd21: ui_char = 8'h55; // U
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd28: ui_char = 8'h20;
                        5'd29: ui_char = 8'h20;
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd1: begin
                    case (col_i)
                        5'd0: ui_char = 8'h2D; // -
                        5'd1: ui_char = 8'h2D; // -
                        5'd2: ui_char = 8'h2D; // -
                        5'd3: ui_char = 8'h2D; // -
                        5'd4: ui_char = 8'h2D; // -
                        5'd5: ui_char = 8'h2D; // -
                        5'd6: ui_char = 8'h2D; // -
                        5'd7: ui_char = 8'h2D; // -
                        5'd8: ui_char = 8'h2D; // -
                        5'd9: ui_char = 8'h2D; // -
                        5'd10: ui_char = 8'h2D; // -
                        5'd11: ui_char = 8'h2D; // -
                        5'd12: ui_char = 8'h2D; // -
                        5'd13: ui_char = 8'h2D; // -
                        5'd14: ui_char = 8'h2D; // -
                        5'd15: ui_char = 8'h2D; // -
                        5'd16: ui_char = 8'h2D; // -
                        5'd17: ui_char = 8'h2D; // -
                        5'd18: ui_char = 8'h2D; // -
                        5'd19: ui_char = 8'h2D; // -
                        5'd20: ui_char = 8'h2D; // -
                        5'd21: ui_char = 8'h2D; // -
                        5'd22: ui_char = 8'h2D; // -
                        5'd23: ui_char = 8'h2D; // -
                        5'd24: ui_char = 8'h2D; // -
                        5'd25: ui_char = 8'h2D; // -
                        5'd26: ui_char = 8'h2D; // -
                        5'd27: ui_char = 8'h2D; // -
                        5'd28: ui_char = 8'h2D; // -
                        5'd29: ui_char = 8'h2D; // -
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd3: begin
                    case (col_i)
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h46; // F
                        5'd3: ui_char = 8'h52; // R
                        5'd4: ui_char = 8'h45; // E
                        5'd5: ui_char = 8'h51; // Q
                        5'd6: ui_char = 8'h20;
                        5'd7: ui_char = 8'h20;
                        5'd8: ui_char = 8'h20;
                        5'd14: ui_char = 8'h20;
                        5'd15: ui_char = 8'h4D; // M
                        5'd16: ui_char = 8'h48; // H
                        5'd17: ui_char = 8'h7A; // z
                        5'd18: ui_char = 8'h20;
                        5'd19: ui_char = 8'h20;
                        5'd20: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd0:  ui_char = (param_page == 2'd0) ? 8'h3E : 8'h20; // >
                        5'd9:  ui_char = asc_digit(freq_hund);
                        5'd10: ui_char = asc_digit(freq_tens);
                        5'd11: ui_char = asc_digit(freq_ones);
                        5'd12: ui_char = 8'h2E; // .
                        5'd13: ui_char = asc_digit(freq_frac);
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd5: begin
                    case (col_i)
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h57; // W
                        5'd3: ui_char = 8'h41; // A
                        5'd4: ui_char = 8'h56; // V
                        5'd5: ui_char = 8'h45; // E
                        5'd6: ui_char = 8'h20;
                        5'd7: ui_char = 8'h20;
                        5'd8: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h20;
                        5'd15: ui_char = 8'h20;
                        5'd16: ui_char = 8'h20;
                        5'd17: ui_char = 8'h20;
                        5'd18: ui_char = 8'h20;
                        5'd19: ui_char = 8'h20;
                        5'd20: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd0:  ui_char = (param_page == 2'd1) ? 8'h3E : 8'h20; // >
                        5'd9:  ui_char = wave_char(wave_mode, 2'd0);
                        5'd10: ui_char = wave_char(wave_mode, 2'd1);
                        5'd11: ui_char = wave_char(wave_mode, 2'd2);
                        5'd12: ui_char = wave_char(wave_mode, 2'd3);
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd7: begin
                    case (col_i)
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h41; // A
                        5'd3: ui_char = 8'h4D; // M
                        5'd4: ui_char = 8'h50; // P
                        5'd5: ui_char = 8'h20;
                        5'd6: ui_char = 8'h20;
                        5'd7: ui_char = 8'h20;
                        5'd8: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h20;
                        5'd15: ui_char = 8'h20;
                        5'd16: ui_char = 8'h20;
                        5'd17: ui_char = 8'h20;
                        5'd18: ui_char = 8'h20;
                        5'd19: ui_char = 8'h20;
                        5'd20: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd0:  ui_char = (param_page == 2'd2) ? 8'h3E : 8'h20; // >
                        5'd9:  ui_char = hex_digit(amplitude_q15[15:12]);
                        5'd10: ui_char = hex_digit(amplitude_q15[11:8]);
                        5'd11: ui_char = hex_digit(amplitude_q15[7:4]);
                        5'd12: ui_char = hex_digit(amplitude_q15[3:0]);
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd9: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h4F; // O
                        5'd3: ui_char = 8'h55; // U
                        5'd4: ui_char = 8'h54; // T
                        5'd5: ui_char = 8'h20;
                        5'd9: ui_char = 8'h20;
                        5'd10: ui_char = 8'h20;
                        5'd11: ui_char = 8'h20;
                        5'd12: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h53; // S
                        5'd15: ui_char = 8'h57; // W
                        5'd16: ui_char = 8'h50; // P
                        5'd17: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd6:  ui_char = 8'h4F; // O
                        5'd7:  ui_char = output_enable ? 8'h4E : 8'h46; // N/F
                        5'd8:  ui_char = output_enable ? 8'h20 : 8'h46; // space/F
                        5'd18: ui_char = 8'h4F; // O
                        5'd19: ui_char = sweep_active ? 8'h4E : 8'h46; // N/F
                        5'd20: ui_char = sweep_active ? 8'h20 : 8'h46; // space/F
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd11: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h4A; // J
                        5'd3: ui_char = 8'h45; // E
                        5'd4: ui_char = 8'h53; // S
                        5'd5: ui_char = 8'h44; // D
                        5'd6: ui_char = 8'h20;
                        5'd9: ui_char = 8'h20;
                        5'd10: ui_char = 8'h20;
                        5'd11: ui_char = 8'h20;
                        5'd12: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h49; // I
                        5'd15: ui_char = 8'h4E; // N
                        5'd16: ui_char = 8'h49; // I
                        5'd17: ui_char = 8'h54; // T
                        5'd18: ui_char = 8'h20;
                        5'd20: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd7:  ui_char = jesd_sync ? 8'h4F : 8'h21; // O/!
                        5'd8:  ui_char = jesd_sync ? 8'h4B : 8'h21; // K/!
                        5'd19: ui_char = hex_digit(init_state);
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd13: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h53; // S
                        5'd3: ui_char = 8'h54; // T
                        5'd4: ui_char = 8'h45; // E
                        5'd5: ui_char = 8'h50; // P
                        5'd6: ui_char = 8'h20;
                        5'd7: ui_char = 8'h31; // 1
                        5'd8: ui_char = 8'h30; // 0
                        5'd9: ui_char = 8'h30; // 0
                        5'd10: ui_char = 8'h4B; // K
                        5'd11: ui_char = 8'h20;
                        5'd12: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h20;
                        5'd15: ui_char = 8'h4C; // L
                        5'd16: ui_char = 8'h4F; // O
                        5'd17: ui_char = 8'h4E; // N
                        5'd18: ui_char = 8'h47; // G
                        5'd19: ui_char = 8'h3A; // :
                        5'd20: ui_char = 8'h53; // S
                        5'd21: ui_char = 8'h59; // Y
                        5'd22: ui_char = 8'h4E; // N
                        5'd23: ui_char = 8'h43; // C
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd15: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h20;
                        5'd2: ui_char = 8'h50; // P
                        5'd3: ui_char = 8'h52; // R
                        5'd4: ui_char = 8'h45; // E
                        5'd5: ui_char = 8'h53; // S
                        5'd6: ui_char = 8'h53; // S
                        5'd7: ui_char = 8'h3A; // :
                        5'd8: ui_char = 8'h50; // P
                        5'd9: ui_char = 8'h41; // A
                        5'd10: ui_char = 8'h47; // G
                        5'd11: ui_char = 8'h45; // E
                        5'd12: ui_char = 8'h20;
                        5'd13: ui_char = 8'h20;
                        5'd14: ui_char = 8'h20;
                        5'd15: ui_char = 8'h54; // T
                        5'd16: ui_char = 8'h55; // U
                        5'd17: ui_char = 8'h52; // R
                        5'd18: ui_char = 8'h4E; // N
                        5'd19: ui_char = 8'h3A; // :
                        5'd20: ui_char = 8'h41; // A
                        5'd21: ui_char = 8'h44; // D
                        5'd22: ui_char = 8'h4A; // J
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        default: ui_char = 8'h20;
                    endcase
                end
                5'd16: begin
                    case (col_i)
                        5'd0: ui_char = 8'h20;
                        5'd1: ui_char = 8'h53; // S
                        5'd2: ui_char = 8'h54; // T
                        5'd3: ui_char = 8'h41; // A
                        5'd4: ui_char = 8'h54; // T
                        5'd5: ui_char = 8'h55; // U
                        5'd6: ui_char = 8'h53; // S
                        5'd7: ui_char = 8'h3A; // :
                        5'd8: ui_char = 8'h20;
                        5'd19: ui_char = 8'h20;
                        5'd20: ui_char = 8'h20;
                        5'd21: ui_char = 8'h20;
                        5'd22: ui_char = 8'h20;
                        5'd23: ui_char = 8'h20;
                        5'd24: ui_char = 8'h20;
                        5'd25: ui_char = 8'h20;
                        5'd26: ui_char = 8'h20;
                        5'd27: ui_char = 8'h20;
                        5'd9: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd0);
                        5'd10: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd1);
                        5'd11: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd2);
                        5'd12: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd3);
                        5'd13: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd4);
                        5'd14: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd5);
                        5'd15: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd6);
                        5'd16: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd7);
                        5'd17: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd8);
                        5'd18: ui_char = status_char(ec11_write_busy, ec11_write_timeout, 4'd9);
                        default: ui_char = 8'h20;
                    endcase
                end
                default: ui_char = 8'h20;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= S_IDLE;
            wr_addr               <= 9'd0;
            row                   <= 5'd0;
            col                   <= 5'd0;
            timer                 <= 24'd0;
            grid_wr_en            <= 1'b0;
            grid_wr_addr          <= 9'd0;
            grid_wr_data          <= 8'h20;
            freq_tenth_mhz_d      <= 14'd0;
            wave_mode_d           <= 2'd0;
            amplitude_q15_d       <= 16'd0;
            output_enable_d       <= 1'b0;
            sweep_active_d        <= 1'b0;
            jesd_sync_d           <= 1'b0;
            init_state_d          <= 4'd0;
            param_page_d          <= 2'd0;
            ec11_write_busy_d     <= 1'b0;
            ec11_write_timeout_d  <= 1'b0;
        end else begin
            grid_wr_en <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (init_done) begin
                        start_refresh();
                    end
                end

                S_WRITE: begin
                    grid_wr_en   <= 1'b1;
                    grid_wr_addr <= wr_addr;
                    grid_wr_data <= ui_char(row, col);

                    if (wr_addr == GRID_LAST) begin
                        wr_addr <= 9'd0;
                        row     <= 5'd0;
                        col     <= 5'd0;
                        timer   <= 24'd0;
                        state   <= S_DONE;
                    end else begin
                        wr_addr <= wr_addr + 1'b1;
                        if (col == 5'd29) begin
                            col <= 5'd0;
                            row <= row + 1'b1;
                        end else begin
                            col <= col + 1'b1;
                        end
                    end
                end

                S_DONE: begin
                    if (ui_dirty || (timer >= REFRESH_TICKS)) begin
                        start_refresh();
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
