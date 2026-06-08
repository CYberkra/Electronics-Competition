// Minimal 8N1 UART receiver.

module uart_rx #(
    parameter integer CLK_HZ = 250000000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rxd,
    output reg  [7:0] data,
    output reg        data_valid
);

localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
localparam [2:0] ST_IDLE  = 3'd0;
localparam [2:0] ST_START = 3'd1;
localparam [2:0] ST_DATA  = 3'd2;
localparam [2:0] ST_STOP  = 3'd3;

reg [2:0] state;
reg [31:0] clk_count;
reg [2:0] bit_index;
reg [7:0] rx_shift;
reg rx_meta;
reg rx_sync;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_meta <= 1'b1;
        rx_sync <= 1'b1;
    end else begin
        rx_meta <= rxd;
        rx_sync <= rx_meta;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= ST_IDLE;
        clk_count  <= 32'd0;
        bit_index  <= 3'd0;
        rx_shift   <= 8'd0;
        data       <= 8'd0;
        data_valid <= 1'b0;
    end else begin
        data_valid <= 1'b0;

        case (state)
            ST_IDLE: begin
                clk_count <= 32'd0;
                bit_index <= 3'd0;
                if (!rx_sync)
                    state <= ST_START;
            end

            ST_START: begin
                if (clk_count == (CLKS_PER_BIT / 2)) begin
                    if (!rx_sync) begin
                        clk_count <= 32'd0;
                        state <= ST_DATA;
                    end else begin
                        state <= ST_IDLE;
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end

            ST_DATA: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 32'd0;
                    rx_shift[bit_index] <= rx_sync;
                    if (bit_index == 3'd7) begin
                        bit_index <= 3'd0;
                        state <= ST_STOP;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end

            ST_STOP: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    data <= rx_shift;
                    data_valid <= rx_sync;
                    clk_count <= 32'd0;
                    state <= ST_IDLE;
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
