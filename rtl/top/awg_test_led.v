// Minimal KEY->LED test, no FMC/JESD dependency
// Uses: 100MHz sys_clk, KEY0/KEY1, LED[0]/LED[1]
module awg_test_led (
    input  wire       sys_clk_p,
    input  wire       sys_clk_n,
    input  wire       sys_rst_n,
    input  wire       key0,
    input  wire       key1,
    output wire [1:0] led
);
    wire clk;
    IBUFDS ibufds (.I(sys_clk_p), .IB(sys_clk_n), .O(clk));
    wire rst = ~sys_rst_n;

    reg [26:0] counter;
    reg [1:0] led_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            led_state <= 2'b01;
        end else begin
            counter <= counter + 1;
            if (counter == 100_000_000) begin
                counter <= 0;
                if (key0 == 1'b0)
                    led_state <= {led_state[0], led_state[1]};  // rotate
                else if (key1 == 1'b0)
                    led_state <= ~led_state;                     // invert
            end
        end
    end
    assign led = led_state;
endmodule
