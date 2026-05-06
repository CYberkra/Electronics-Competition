// Register-control skeleton for the AD9144 AWG datapath.
// The current button demo ties the write interface idle and keeps
// use_reg_control=0, so board behavior stays controlled by KEY0/KEY1.

module ad9144_awg_reg_bank (
    input  wire               clk,
    input  wire               rst_n,

    input  wire               cfg_wr_en,
    input  wire        [7:0]  cfg_addr,
    input  wire        [31:0] cfg_wdata,
    input  wire               cfg_rd_en,
    output reg         [31:0] cfg_rdata,

    output wire               output_enable,
    output wire               use_reg_control,
    output reg         [47:0] phase_inc,
    output reg         [47:0] phase_offset,
    output reg         [15:0] amplitude_q15,
    output reg  signed [15:0] offset,
    output reg          [1:0] wave_mode,
    output reg                update_toggle,

    input  wire         [1:0] button_ui_mode,
    input  wire         [2:0] button_freq_sel,
    input  wire         [2:0] button_amp_sel,
    input  wire         [2:0] button_phase_sel,
    input  wire         [1:0] button_wave_sel,
    input  wire               tx_ready,
    input  wire               tx_sync,
    input  wire               sysref_seen,
    input  wire               sample_valid
);

localparam [7:0] ADDR_ID              = 8'h00;
localparam [7:0] ADDR_VERSION         = 8'h04;
localparam [7:0] ADDR_CONTROL         = 8'h08;
localparam [7:0] ADDR_STATUS          = 8'h0C;
localparam [7:0] ADDR_PHASE_INC_LO    = 8'h10;
localparam [7:0] ADDR_PHASE_INC_HI    = 8'h14;
localparam [7:0] ADDR_PHASE_OFFSET_LO = 8'h18;
localparam [7:0] ADDR_PHASE_OFFSET_HI = 8'h1C;
localparam [7:0] ADDR_AMPLITUDE       = 8'h20;
localparam [7:0] ADDR_OFFSET          = 8'h24;
localparam [7:0] ADDR_WAVE_MODE       = 8'h28;
localparam [7:0] ADDR_APPLY           = 8'h2C;
localparam [7:0] ADDR_BUTTON_STATE    = 8'h30;

localparam [31:0] CORE_ID      = 32'h41574731; // "AWG1"
localparam [31:0] CORE_VERSION = 32'h20260507;

reg [31:0] control_reg;

assign output_enable = control_reg[0];
assign use_reg_control = control_reg[1];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        control_reg   <= 32'h00000001;
        phase_inc     <= 48'h0CCCCCCCCCCD;
        phase_offset  <= 48'h000000000000;
        amplitude_q15 <= 16'h6000;
        offset        <= 16'sd0;
        wave_mode     <= 2'd0;
        update_toggle <= 1'b0;
    end else if (cfg_wr_en) begin
        case (cfg_addr)
            ADDR_CONTROL: begin
                control_reg <= cfg_wdata;
            end
            ADDR_PHASE_INC_LO: begin
                phase_inc[31:0] <= cfg_wdata;
            end
            ADDR_PHASE_INC_HI: begin
                phase_inc[47:32] <= cfg_wdata[15:0];
            end
            ADDR_PHASE_OFFSET_LO: begin
                phase_offset[31:0] <= cfg_wdata;
            end
            ADDR_PHASE_OFFSET_HI: begin
                phase_offset[47:32] <= cfg_wdata[15:0];
            end
            ADDR_AMPLITUDE: begin
                amplitude_q15 <= cfg_wdata[15:0];
            end
            ADDR_OFFSET: begin
                offset <= cfg_wdata[15:0];
            end
            ADDR_WAVE_MODE: begin
                wave_mode <= cfg_wdata[1:0];
            end
            ADDR_APPLY: begin
                update_toggle <= ~update_toggle;
            end
            default: begin
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cfg_rdata <= 32'd0;
    end else if (cfg_rd_en) begin
        case (cfg_addr)
            ADDR_ID: begin
                cfg_rdata <= CORE_ID;
            end
            ADDR_VERSION: begin
                cfg_rdata <= CORE_VERSION;
            end
            ADDR_CONTROL: begin
                cfg_rdata <= control_reg;
            end
            ADDR_STATUS: begin
                cfg_rdata <= {
                    25'd0,
                    update_toggle,
                    sample_valid,
                    sysref_seen,
                    tx_sync,
                    tx_ready,
                    use_reg_control,
                    output_enable
                };
            end
            ADDR_PHASE_INC_LO: begin
                cfg_rdata <= phase_inc[31:0];
            end
            ADDR_PHASE_INC_HI: begin
                cfg_rdata <= {16'd0, phase_inc[47:32]};
            end
            ADDR_PHASE_OFFSET_LO: begin
                cfg_rdata <= phase_offset[31:0];
            end
            ADDR_PHASE_OFFSET_HI: begin
                cfg_rdata <= {16'd0, phase_offset[47:32]};
            end
            ADDR_AMPLITUDE: begin
                cfg_rdata <= {16'd0, amplitude_q15};
            end
            ADDR_OFFSET: begin
                cfg_rdata <= {{16{offset[15]}}, offset};
            end
            ADDR_WAVE_MODE: begin
                cfg_rdata <= {30'd0, wave_mode};
            end
            ADDR_BUTTON_STATE: begin
                cfg_rdata <= {
                    14'd0,
                    button_ui_mode,
                    1'd0, button_freq_sel,
                    1'd0, button_amp_sel,
                    1'd0, button_phase_sel,
                    2'd0, button_wave_sel
                };
            end
            default: begin
                cfg_rdata <= 32'd0;
            end
        endcase
    end
end

endmodule
