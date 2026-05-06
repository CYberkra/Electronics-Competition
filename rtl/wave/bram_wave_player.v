//------------------------------------------------------------------------------
// BRAM Wave Player
//
// Plays back a small arbitrary waveform from an inferred ROM.
// The address source is external so this block can be reused for
// direct playback, DDS-indexed playback, or later DMA-fed waveforms.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module bram_wave_player #(
    parameter ADDR_W = 12,
    parameter DATA_W = 16
) (
    input  wire                      clk,
    input  wire [ADDR_W-1:0]         addr,
    output reg  signed [DATA_W-1:0]  sample_out
);

    reg signed [DATA_W-1:0] rom [0:(1 << ADDR_W)-1];
    integer i;

    function automatic signed [DATA_W-1:0] make_sample(
        input [ADDR_W-1:0] addr_i
    );
        reg signed [DATA_W-1:0] step;
        begin
            step = $signed({1'b0, addr_i[ADDR_W-3:0], 5'b0});
            case (addr_i[ADDR_W-1:ADDR_W-2])
                2'b00: make_sample = $signed(16'sh8000 + step);
                2'b01: make_sample = 16'sh7fff;
                2'b10: make_sample = $signed(16'sh7fff - step);
                default: make_sample = 16'sh8000;
            endcase
        end
    endfunction

    initial begin
        for (i = 0; i < (1 << ADDR_W); i = i + 1) begin
            rom[i] = make_sample(i[ADDR_W-1:0]);
        end
    end

    always @(posedge clk) begin
        sample_out <= rom[addr];
    end

endmodule
