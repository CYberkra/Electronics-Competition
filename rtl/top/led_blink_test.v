// Absolute minimum test: blink LED0 at 1Hz using board 100MHz clock
// No STARTUPE2, no MMCM, no IP cores. Just sys_clk -> IBUFDS -> BUFG -> counter -> LED
module led_blink_test (
    input  wire  sys_clk_p,
    input  wire  sys_clk_n,
    input  wire  sys_rst_n,
    output wire  led0,
    output wire  led1
);
    wire clk;
    IBUFDS #(.DIFF_TERM("TRUE"), .IOSTANDARD("DIFF_SSTL15")) u_ibuf (
        .I(sys_clk_p), .IB(sys_clk_n), .O(clk)
    );

    reg [26:0] cnt;  // 27 bits, 100MHz/2^27 = 0.75Hz
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) cnt <= 0;
        else cnt <= cnt + 1;
    end

    assign led0 = cnt[26];           // blink ~0.75Hz
    assign led1 = cnt[25];           // blink ~1.5Hz
endmodule
