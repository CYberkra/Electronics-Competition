//------------------------------------------------------------------------------
// Digital Calibration Module for AD9144 AWG
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

// Function: Automatic amplitude compensation based on frequency, range, and
//           calibration coefficient table stored in Block RAM.
//
// Calibration formula (1-stage pipeline):
//   amplitude_out = (amplitude_in * gain_coef) >> 15 + offset
//
// Coefficient table: 16 frequency bins x 32-bit entry
//   [31:16] = signed 16-bit offset
//   [15:0]  = unsigned Q1.15 gain coefficient
//             0x4000 = 0.5, 0x8000 = 1.0, 0xFFFF ~= 2.0
//------------------------------------------------------------------------------

module ad9144_awg_cal (
    input  wire        clk,
    input  wire        rst_n,

    // Control interface
    input  wire        cal_enable,
    input  wire [1:0]  range_sel,
    input  wire [47:0] phase_inc,

    // Amplitude in / out
    input  wire [15:0] amplitude_q15_in,
    output reg  [15:0] amplitude_q15_out,

    // Calibration table write port (from register bank)
    input  wire        cal_wr_en,
    input  wire [3:0]  cal_wr_addr,
    input  wire [31:0] cal_wr_data,

    // Calibration table read port (for debug / register readback)
    input  wire        cal_rd_en,
    input  wire [3:0]  cal_rd_addr,
    output reg  [31:0] cal_rd_data
);

//------------------------------------------------------------------------------
// Block RAM: Calibration Coefficient Table
//------------------------------------------------------------------------------
// 16 entries, each 32-bit: {offset[15:0], gain_coef[15:0]}
// Default: unity gain (0x8000), zero offset (0x0000)
//------------------------------------------------------------------------------

(* ram_style = "block" *) reg [31:0] cal_table [0:15];

integer init_i;
initial begin
    for (init_i = 0; init_i < 16; init_i = init_i + 1)
        cal_table[init_i] = {16'sd0, 16'h8000};
end

//------------------------------------------------------------------------------
// Frequency Index: upper 4 bits of phase_inc
//------------------------------------------------------------------------------
wire [3:0] freq_idx = phase_inc[47:44];

//------------------------------------------------------------------------------
// BRAM Write Port (synchronous)
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (cal_wr_en)
        cal_table[cal_wr_addr] <= cal_wr_data;
end

//------------------------------------------------------------------------------
// BRAM Read Port for Compensation (1-cycle latency)
//------------------------------------------------------------------------------
reg [31:0] cal_entry;
reg        cal_enable_d;
reg [15:0] amplitude_d;

always @(posedge clk) begin
    cal_entry      <= cal_table[freq_idx];
    cal_enable_d   <= cal_enable;
    amplitude_d    <= amplitude_q15_in;
end

//------------------------------------------------------------------------------
// BRAM Read Port for Debug (1-cycle latency)
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (cal_rd_en)
        cal_rd_data <= cal_table[cal_rd_addr];
end

//------------------------------------------------------------------------------
// Amplitude Compensation (combinational, registered output)
//------------------------------------------------------------------------------
wire        [15:0] gain_coef  = cal_entry[15:0];
wire signed [15:0] offset_val = $signed(cal_entry[31:16]);

wire        [31:0] product = amplitude_d * gain_coef;
wire        [17:0] shifted = product[31:15];
wire signed [32:0] summed  = $signed({15'd0, shifted}) + {{17{offset_val[15]}}, offset_val};

wire [15:0] compensated = (summed > 32767) ? 16'h7FFF :
                          (summed < 0)     ? 16'h0000 : summed[15:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        amplitude_q15_out <= 16'h6000;
    else if (cal_enable_d)
        amplitude_q15_out <= compensated;
    else
        amplitude_q15_out <= amplitude_d;
end

endmodule
