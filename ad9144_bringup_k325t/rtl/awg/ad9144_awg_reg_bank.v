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

    // New calibration / range control outputs
    output reg          [1:0] range_sel,
    output reg                output_en,
    output reg                cal_enable,
    output reg                cal_wr_en,
    output reg          [3:0] cal_wr_addr,
    output reg         [31:0] cal_wr_data,
    output reg                cal_rd_en,
    output reg          [3:0] cal_rd_addr,
    input  wire        [31:0] cal_rd_data,

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
localparam [7:0] ADDR_RANGE_SEL       = 8'h34;
localparam [7:0] ADDR_OUTPUT_EN       = 8'h38;
localparam [7:0] ADDR_CAL_ENABLE      = 8'h3C;
localparam [7:0] ADDR_CAL_TABLE_BASE  = 8'h40;

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
        range_sel     <= 2'd0;
        output_en     <= 1'b1;
        cal_enable    <= 1'b0;
        cal_wr_en     <= 1'b0;
        cal_rd_en     <= 1'b0;
    end else begin
        cal_wr_en <= 1'b0;
        cal_rd_en <= 1'b0;
        if (cfg_wr_en) begin
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
                ADDR_RANGE_SEL: begin
                    range_sel <= cfg_wdata[1:0];
                end
                ADDR_OUTPUT_EN: begin
                    output_en <= cfg_wdata[0];
                end
                ADDR_CAL_ENABLE: begin
                    cal_enable <= cfg_wdata[0];
                end
                default: begin
                    if (cfg_addr >= ADDR_CAL_TABLE_BASE && cfg_addr < ADDR_CAL_TABLE_BASE + 8'h40) begin
                        cal_wr_en   <= 1'b1;
                        cal_wr_addr <= cfg_addr[5:2];
                        cal_wr_data <= cfg_wdata;
                    end
                end
            endcase
        end
    end
end

// ---------------------------------------------------------------------------
// Read logic with 2-cycle delay to support Block RAM readback
// Cycle 0: cfg_rd_en + address captured
// Cycle 1: BRAM read issued (for cal_table), normal decode delayed
// Cycle 2: cfg_rdata driven from captured address / BRAM data
// ---------------------------------------------------------------------------

reg        rd_en_d;
reg [7:0]  rd_addr_d;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_en_d   <= 1'b0;
        rd_addr_d <= 8'd0;
    end else begin
        rd_en_d   <= cfg_rd_en;
        rd_addr_d <= cfg_addr;
    end
end

// Issue cal_table read request in first cycle
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cal_rd_en <= 1'b0;
    end else begin
        cal_rd_en <= cfg_rd_en && (cfg_addr >= ADDR_CAL_TABLE_BASE && cfg_addr < ADDR_CAL_TABLE_BASE + 8'h40);
        cal_rd_addr <= cfg_addr[5:2];
    end
end

// Output data in second cycle
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cfg_rdata <= 32'd0;
    end else if (rd_en_d) begin
        case (rd_addr_d)
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
                    21'd0,
                    cal_enable,
                    range_sel,
                    output_en,
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
            ADDR_RANGE_SEL: begin
                cfg_rdata <= {30'd0, range_sel};
            end
            ADDR_OUTPUT_EN: begin
                cfg_rdata <= {31'd0, output_en};
            end
            ADDR_CAL_ENABLE: begin
                cfg_rdata <= {31'd0, cal_enable};
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
                if (rd_addr_d >= ADDR_CAL_TABLE_BASE && rd_addr_d < ADDR_CAL_TABLE_BASE + 8'h40)
                    cfg_rdata <= cal_rd_data;
                else
                    cfg_rdata <= 32'd0;
            end
        endcase
    end
end

endmodule
