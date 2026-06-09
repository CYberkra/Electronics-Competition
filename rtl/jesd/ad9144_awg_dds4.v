// Four-sample-per-beat DDS source for the AD9144 JESD TX path.
// phase_inc is expressed per DAC sample.  The accumulator advances by
// four samples on each tx_core_clk cycle.
//
// NOTE: amplitude_q15 may receive calibrated amplitude from ad9144_awg_cal
// module when digital calibration is enabled.  The calibration logic is
// intentionally kept outside this module to preserve clean waveform
// generation and ease independent verification.

module ad9144_awg_dds4 #(
    parameter INIT_FILE = "../dds/ad9144_sine_4096.hex"
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire        [47:0] phase_inc,
    input  wire        [47:0] phase_offset,
    input  wire         [1:0] wave_mode,
    input  wire        [15:0] amplitude_q15,
    input  wire signed [15:0] offset,
    output reg  signed [15:0] sample0,
    output reg  signed [15:0] sample1,
    output reg  signed [15:0] sample2,
    output reg  signed [15:0] sample3,
    output reg         [11:0] phase_addr0,
    output reg         [11:0] phase_addr1,
    output reg         [11:0] phase_addr2,
    output reg         [11:0] phase_addr3,
    output reg                sample_valid
);

(* rom_style = "block" *) reg signed [15:0] sine_rom0 [0:4095];
(* rom_style = "block" *) reg signed [15:0] sine_rom1 [0:4095];
(* rom_style = "block" *) reg signed [15:0] sine_rom2 [0:4095];
(* rom_style = "block" *) reg signed [15:0] sine_rom3 [0:4095];

initial begin
    $readmemh(INIT_FILE, sine_rom0);
    $readmemh(INIT_FILE, sine_rom1);
    $readmemh(INIT_FILE, sine_rom2);
    $readmemh(INIT_FILE, sine_rom3);
end

reg [47:0] phase_acc;
wire [47:0] phase_base = phase_acc + phase_offset;
wire [47:0] phase_inc2 = {phase_inc[46:0], 1'b0};
wire [47:0] phase_inc3 = phase_inc2 + phase_inc;
wire [47:0] phase_inc4 = {phase_inc[45:0], 2'b00};

wire [47:0] phase0 = phase_base;
wire [47:0] phase1 = phase_base + phase_inc;
wire [47:0] phase2 = phase_base + phase_inc2;
wire [47:0] phase3 = phase_base + phase_inc3;

reg [11:0] addr0_s0, addr1_s0, addr2_s0, addr3_s0;
reg [11:0] addr0_s1, addr1_s1, addr2_s1, addr3_s1;
reg [11:0] addr0_s2, addr1_s2, addr2_s2, addr3_s2;

reg signed [15:0] sine0_s1, sine1_s1, sine2_s1, sine3_s1;
reg signed [15:0] shape0_s1, shape1_s1, shape2_s1, shape3_s1;
reg signed [15:0] raw0_s1b, raw1_s1b, raw2_s1b, raw3_s1b;
reg signed [32:0] product0_s2, product1_s2, product2_s2, product3_s2;
reg [15:0] amp_s0, amp_s1, amp_s1b;
reg signed [15:0] offset_s0, offset_s1, offset_s2;
reg [1:0] wave_mode_s0, wave_mode_s1;
reg [3:0] valid_pipe;

function signed [15:0] shape_from_addr;
    input [1:0] mode;
    input [11:0] addr;
    reg [10:0] half_addr;
    reg [10:0] tri_unsigned;
    reg signed [12:0] tri_centered;
    reg signed [13:0] saw_centered;
    begin
        half_addr = addr[10:0];
        case (mode)
            2'd1: shape_from_addr = addr[11] ? -16'sd32768 : 16'sd32767;
            2'd2: begin
                tri_unsigned = addr[11] ? (11'd2047 - half_addr) : half_addr;
                tri_centered = $signed({1'b0, tri_unsigned}) - 13'sd1024;
                shape_from_addr = tri_centered <<< 5;
            end
            2'd3: begin
                saw_centered = $signed({1'b0, addr}) - 14'sd2048;
                shape_from_addr = saw_centered <<< 4;
            end
            default: shape_from_addr = 16'sd0;
        endcase
    end
endfunction

function signed [15:0] select_raw_sample;
    input [1:0] mode;
    input signed [15:0] sine_value;
    input signed [15:0] shape_value;
    begin
        select_raw_sample = (mode == 2'd0) ? sine_value : shape_value;
    end
endfunction

function signed [15:0] scale_and_saturate;
    input signed [32:0] product;
    input signed [15:0] offset_value;
    reg signed [33:0] shifted;
    reg signed [33:0] summed;
    begin
        shifted = product >>> 15;
        summed = shifted + offset_value;
        if (summed > 34'sd32767)
            scale_and_saturate = 16'sh7fff;
        else if (summed < -34'sd32768)
            scale_and_saturate = -16'sd32768;
        else
            scale_and_saturate = summed[15:0];
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phase_acc    <= 48'd0;
        addr0_s0     <= 12'd0;
        addr1_s0     <= 12'd0;
        addr2_s0     <= 12'd0;
        addr3_s0     <= 12'd0;
        addr0_s1     <= 12'd0;
        addr1_s1     <= 12'd0;
        addr2_s1     <= 12'd0;
        addr3_s1     <= 12'd0;
        addr0_s2     <= 12'd0;
        addr1_s2     <= 12'd0;
        addr2_s2     <= 12'd0;
        addr3_s2     <= 12'd0;
        sine0_s1     <= 16'sd0;
        sine1_s1     <= 16'sd0;
        sine2_s1     <= 16'sd0;
        sine3_s1     <= 16'sd0;
        shape0_s1    <= 16'sd0;
        shape1_s1    <= 16'sd0;
        shape2_s1    <= 16'sd0;
        shape3_s1    <= 16'sd0;
        product0_s2  <= 33'sd0;
        product1_s2  <= 33'sd0;
        product2_s2  <= 33'sd0;
        product3_s2  <= 33'sd0;
        amp_s0       <= 16'd0;
        amp_s1       <= 16'd0;
        offset_s0    <= 16'sd0;
        offset_s1    <= 16'sd0;
        offset_s2    <= 16'sd0;
        wave_mode_s0 <= 2'd0;
        wave_mode_s1 <= 2'd0;
        sample0      <= 16'sd0;
        sample1      <= 16'sd0;
        sample2      <= 16'sd0;
        sample3      <= 16'sd0;
        phase_addr0  <= 12'd0;
        phase_addr1  <= 12'd0;
        phase_addr2  <= 12'd0;
        phase_addr3  <= 12'd0;
        valid_pipe   <= 4'b0000;
        sample_valid <= 1'b0;
    end else begin
        phase_acc <= phase_acc + phase_inc4;

        addr0_s0 <= phase0[47:36];
        addr1_s0 <= phase1[47:36];
        addr2_s0 <= phase2[47:36];
        addr3_s0 <= phase3[47:36];
        amp_s0   <= amplitude_q15;
        offset_s0 <= offset;
        wave_mode_s0 <= wave_mode;

        sine0_s1 <= sine_rom0[addr0_s0];
        sine1_s1 <= sine_rom1[addr1_s0];
        sine2_s1 <= sine_rom2[addr2_s0];
        sine3_s1 <= sine_rom3[addr3_s0];
        shape0_s1 <= shape_from_addr(wave_mode_s0, addr0_s0);
        shape1_s1 <= shape_from_addr(wave_mode_s0, addr1_s0);
        shape2_s1 <= shape_from_addr(wave_mode_s0, addr2_s0);
        shape3_s1 <= shape_from_addr(wave_mode_s0, addr3_s0);
        addr0_s1 <= addr0_s0;
        addr1_s1 <= addr1_s0;
        addr2_s1 <= addr2_s0;
        addr3_s1 <= addr3_s0;
        amp_s1   <= amp_s0;
        offset_s1 <= offset_s0;
        wave_mode_s1 <= wave_mode_s0;

        raw0_s1b   <= select_raw_sample(wave_mode_s1, sine0_s1, shape0_s1);
        raw1_s1b   <= select_raw_sample(wave_mode_s1, sine1_s1, shape1_s1);
        raw2_s1b   <= select_raw_sample(wave_mode_s1, sine2_s1, shape2_s1);
        raw3_s1b   <= select_raw_sample(wave_mode_s1, sine3_s1, shape3_s1);
        amp_s1b    <= amp_s1;

        product0_s2 <= raw0_s1b * $signed({1'b0, amp_s1b});
        product1_s2 <= raw1_s1b * $signed({1'b0, amp_s1b});
        product2_s2 <= raw2_s1b * $signed({1'b0, amp_s1b});
        product3_s2 <= raw3_s1b * $signed({1'b0, amp_s1b});
        addr0_s2    <= addr0_s1;
        addr1_s2    <= addr1_s1;
        addr2_s2    <= addr2_s1;
        addr3_s2    <= addr3_s1;
        offset_s2   <= offset_s1;

        sample0     <= scale_and_saturate(product0_s2, offset_s2);
        sample1     <= scale_and_saturate(product1_s2, offset_s2);
        sample2     <= scale_and_saturate(product2_s2, offset_s2);
        sample3     <= scale_and_saturate(product3_s2, offset_s2);
        phase_addr0 <= addr0_s2;
        phase_addr1 <= addr1_s2;
        phase_addr2 <= addr2_s2;
        phase_addr3 <= addr3_s2;

        valid_pipe   <= {valid_pipe[2:0], 1'b1};
        sample_valid <= valid_pipe[3];
    end
end

endmodule
