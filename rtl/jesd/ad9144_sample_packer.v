// Packs four signed 16-bit DAC samples into the 128-bit JESD TX data order
// used by the vendor AD9144 demo design.

module ad9144_sample_packer (
    input  wire signed [15:0] sample0,
    input  wire signed [15:0] sample1,
    input  wire signed [15:0] sample2,
    input  wire signed [15:0] sample3,
    output wire        [127:0] tx_tdata
);

assign tx_tdata = {
    sample3[7:0],  sample2[7:0],  sample1[7:0],  sample0[7:0],
    sample3[15:8], sample2[15:8], sample1[15:8], sample0[15:8],
    sample3[7:0],  sample2[7:0],  sample1[7:0],  sample0[7:0],
    sample3[15:8], sample2[15:8], sample1[15:8], sample0[15:8]
};

endmodule
