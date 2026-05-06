//------------------------------------------------------------------------------
// Sweep Engine
//
// Generates a programmable phase increment ramp for DDS-based output.
// When disabled, the module transparently forwards the manual increment.
// When enabled, it performs a simple linear sweep between the configured
// bounds and then repeats.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module sweep_engine #(
    parameter PHASE_W = 48,
    parameter [31:0] DWELL_TICKS = 32'd5_000_000,
    parameter [PHASE_W-1:0] START_INC = 48'h004189374BC7,   // 100 kHz @ 100 MHz
    parameter [PHASE_W-1:0] STOP_INC  = 48'h028F5C28F5C3,   // 1 MHz @ 100 MHz
    parameter [PHASE_W-1:0] STEP_INC  = 48'h004189374BC7    // 100 kHz step
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,
    input  wire [PHASE_W-1:0]    manual_phase_inc,
    output reg  [PHASE_W-1:0]    phase_inc_out,
    output reg                   sweep_active
);

    reg [31:0] dwell_cnt;
    reg [PHASE_W-1:0] sweep_inc;
    reg sweep_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dwell_cnt      <= 32'd0;
            sweep_inc      <= START_INC;
            sweep_dir      <= 1'b0;
            phase_inc_out  <= {PHASE_W{1'b0}};
            sweep_active   <= 1'b0;
        end else begin
            if (!enable) begin
                dwell_cnt     <= 32'd0;
                sweep_inc     <= START_INC;
                sweep_dir     <= 1'b0;
                phase_inc_out <= manual_phase_inc;
                sweep_active  <= 1'b0;
            end else begin
                sweep_active <= 1'b1;
                if (dwell_cnt < DWELL_TICKS) begin
                    dwell_cnt <= dwell_cnt + 1'b1;
                end else begin
                    dwell_cnt <= 32'd0;
                    if (!sweep_dir) begin
                        if (sweep_inc + STEP_INC >= STOP_INC) begin
                            sweep_inc <= STOP_INC;
                            sweep_dir <= 1'b1;
                        end else begin
                            sweep_inc <= sweep_inc + STEP_INC;
                        end
                    end else begin
                        if (sweep_inc <= START_INC + STEP_INC) begin
                            sweep_inc <= START_INC;
                            sweep_dir <= 1'b0;
                        end else begin
                            sweep_inc <= sweep_inc - STEP_INC;
                        end
                    end
                end
                phase_inc_out <= sweep_inc;
            end
        end
    end

endmodule
