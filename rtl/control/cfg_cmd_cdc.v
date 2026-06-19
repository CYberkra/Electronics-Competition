//------------------------------------------------------------------------------
// Single-command CDC bridge for slow register writes.
// Source command bus is held stable until destination accepts and acknowledges.
//------------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module cfg_cmd_cdc (
    input  wire        src_clk,
    input  wire        src_rst_n,
    input  wire        src_wr_en,
    input  wire [7:0]  src_addr,
    input  wire [31:0] src_data,
    output wire        src_ready,
    output wire        src_busy_out,

    input  wire        dst_clk,
    input  wire        dst_rst_n,
    input  wire        dst_ready,
    output reg         dst_wr_en,
    output reg  [7:0]  dst_addr,
    output reg  [31:0] dst_data
);

    reg [7:0]  hold_addr;
    reg [31:0] hold_data;
    reg        req_toggle;
    reg        src_busy;

    (* ASYNC_REG = "TRUE" *) reg ack_sync0;
    (* ASYNC_REG = "TRUE" *) reg ack_sync1;
    reg ack_toggle_dst;

    // Deassert ready immediately while src_wr_en is high.
    // Without this, a source FSM can emit the next command one clk too early,
    // before src_busy has been registered, causing consecutive writes to be dropped.
    assign src_ready    = !src_busy && !src_wr_en;
    assign src_busy_out = src_busy || src_wr_en;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            hold_addr  <= 8'd0;
            hold_data  <= 32'd0;
            req_toggle <= 1'b0;
            src_busy   <= 1'b0;
            ack_sync0  <= 1'b0;
            ack_sync1  <= 1'b0;
        end else begin
            ack_sync0 <= ack_toggle_dst;
            ack_sync1 <= ack_sync0;

            if (src_busy && (ack_sync1 == req_toggle)) begin
                src_busy <= 1'b0;
            end

            if (src_wr_en && !src_busy) begin
                hold_addr  <= src_addr;
                hold_data  <= src_data;
                req_toggle <= ~req_toggle;
                src_busy   <= 1'b1;
            end
        end
    end

    (* ASYNC_REG = "TRUE" *) reg req_sync0;
    (* ASYNC_REG = "TRUE" *) reg req_sync1;
    reg req_seen;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_sync0      <= 1'b0;
            req_sync1      <= 1'b0;
            req_seen       <= 1'b0;
            ack_toggle_dst <= 1'b0;
            dst_wr_en      <= 1'b0;
            dst_addr       <= 8'd0;
            dst_data       <= 32'd0;
        end else begin
            dst_wr_en <= 1'b0;
            req_sync0 <= req_toggle;
            req_sync1 <= req_sync0;

            // Do not acknowledge until the destination-side bus arbiter can accept.
            if ((req_sync1 != req_seen) && dst_ready) begin
                dst_addr       <= hold_addr;
                dst_data       <= hold_data;
                dst_wr_en      <= 1'b1;
                req_seen       <= req_sync1;
                ack_toggle_dst <= req_sync1;
            end
        end
    end

endmodule

`default_nettype wire
