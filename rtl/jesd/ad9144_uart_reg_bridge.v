// ASCII UART to AD9144 AWG register bridge.
//
// Supported line commands:
//   W aa dddddddd
//   R aa
// Responses:
//   OK
//   D dddddddd
//   ERR

module ad9144_uart_reg_bridge #(
    parameter integer CLK_HZ = 250000000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       uart_rxd,
    output wire       uart_txd,

    output reg        cfg_wr_en,
    output reg        cfg_rd_en,
    output reg  [7:0] cfg_addr,
    output reg [31:0] cfg_wdata,
    input  wire [31:0] cfg_rdata,

    output reg        activity_toggle
);

localparam [4:0] ST_IDLE         = 5'd0;
localparam [4:0] ST_W_ADDR       = 5'd1;
localparam [4:0] ST_W_DATA       = 5'd2;
localparam [4:0] ST_W_EOL        = 5'd3;
localparam [4:0] ST_R_ADDR       = 5'd4;
localparam [4:0] ST_R_EOL        = 5'd5;
localparam [4:0] ST_RD_PULSE     = 5'd6;
localparam [4:0] ST_RD_WAIT      = 5'd7;
localparam [4:0] ST_DRAIN_ERR    = 5'd8;
localparam [4:0] ST_SEND         = 5'd9;
localparam [4:0] ST_SEND_BUSY    = 5'd10;
localparam [4:0] ST_SEND_IDLE    = 5'd11;
localparam [4:0] ST_RD_CAPTURE   = 5'd12;
localparam [4:0] ST_RD_WAIT2     = 5'd13;

localparam [1:0] SEND_OK   = 2'd0;
localparam [1:0] SEND_ERR  = 2'd1;
localparam [1:0] SEND_DATA = 2'd2;

wire [7:0] rx_data;
wire rx_valid;
reg [7:0] tx_data;
reg tx_start;
wire tx_busy;

reg [4:0] state;
reg [1:0] send_type;
reg [3:0] send_index;
reg [7:0] addr_shift;
reg [1:0] addr_count;
reg [31:0] data_shift;
reg [3:0] data_count;
reg [31:0] read_latched;

uart_rx #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) u_uart_rx (
    .clk(clk),
    .rst_n(rst_n),
    .rxd(uart_rxd),
    .data(rx_data),
    .data_valid(rx_valid)
);

uart_tx #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
) u_uart_tx (
    .clk(clk),
    .rst_n(rst_n),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .txd(uart_txd),
    .tx_busy(tx_busy)
);

function is_space;
    input [7:0] ch;
    begin
        is_space = (ch == 8'h20) || (ch == 8'h09);
    end
endfunction

function is_eol;
    input [7:0] ch;
    begin
        is_eol = (ch == 8'h0A) || (ch == 8'h0D);
    end
endfunction

function is_hex;
    input [7:0] ch;
    begin
        is_hex = ((ch >= "0") && (ch <= "9")) ||
                 ((ch >= "a") && (ch <= "f")) ||
                 ((ch >= "A") && (ch <= "F"));
    end
endfunction

function [3:0] hex_value;
    input [7:0] ch;
    begin
        if ((ch >= "0") && (ch <= "9"))
            hex_value = ch[3:0];
        else if ((ch >= "a") && (ch <= "f"))
            hex_value = ch - "a" + 4'd10;
        else
            hex_value = ch - "A" + 4'd10;
    end
endfunction

function [7:0] hex_char;
    input [3:0] value;
    begin
        if (value < 4'd10)
            hex_char = "0" + value;
        else
            hex_char = "A" + (value - 4'd10);
    end
endfunction

function [3:0] send_len;
    input [1:0] typ;
    begin
        case (typ)
            SEND_OK:   send_len = 4'd4;
            SEND_ERR:  send_len = 4'd5;
            SEND_DATA: send_len = 4'd12;
            default:   send_len = 4'd0;
        endcase
    end
endfunction

function [7:0] send_byte;
    input [1:0] typ;
    input [3:0] idx;
    input [31:0] data_word;
    begin
        case (typ)
            SEND_OK: begin
                case (idx)
                    4'd0: send_byte = "O";
                    4'd1: send_byte = "K";
                    4'd2: send_byte = 8'h0D;
                    default: send_byte = 8'h0A;
                endcase
            end
            SEND_ERR: begin
                case (idx)
                    4'd0: send_byte = "E";
                    4'd1: send_byte = "R";
                    4'd2: send_byte = "R";
                    4'd3: send_byte = 8'h0D;
                    default: send_byte = 8'h0A;
                endcase
            end
            SEND_DATA: begin
                case (idx)
                    4'd0: send_byte = "D";
                    4'd1: send_byte = " ";
                    4'd2: send_byte = hex_char(data_word[31:28]);
                    4'd3: send_byte = hex_char(data_word[27:24]);
                    4'd4: send_byte = hex_char(data_word[23:20]);
                    4'd5: send_byte = hex_char(data_word[19:16]);
                    4'd6: send_byte = hex_char(data_word[15:12]);
                    4'd7: send_byte = hex_char(data_word[11:8]);
                    4'd8: send_byte = hex_char(data_word[7:4]);
                    4'd9: send_byte = hex_char(data_word[3:0]);
                    4'd10: send_byte = 8'h0D;
                    default: send_byte = 8'h0A;
                endcase
            end
            default: begin
                send_byte = 8'h0A;
            end
        endcase
    end
endfunction

task start_send;
    input [1:0] typ;
    begin
        send_type <= typ;
        send_index <= 4'd0;
        state <= ST_SEND;
        activity_toggle <= ~activity_toggle;
    end
endtask

task start_error_drain;
    begin
        state <= ST_DRAIN_ERR;
        activity_toggle <= ~activity_toggle;
    end
endtask

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= ST_IDLE;
        send_type       <= SEND_OK;
        send_index      <= 4'd0;
        addr_shift      <= 8'd0;
        addr_count      <= 2'd0;
        data_shift      <= 32'd0;
        data_count      <= 4'd0;
        read_latched    <= 32'd0;
        cfg_wr_en       <= 1'b0;
        cfg_rd_en       <= 1'b0;
        cfg_addr        <= 8'd0;
        cfg_wdata       <= 32'd0;
        tx_data         <= 8'd0;
        tx_start        <= 1'b0;
        activity_toggle <= 1'b0;
    end else begin
        cfg_wr_en <= 1'b0;
        cfg_rd_en <= 1'b0;
        tx_start  <= 1'b0;

        case (state)
            ST_IDLE: begin
                addr_shift <= 8'd0;
                addr_count <= 2'd0;
                data_shift <= 32'd0;
                data_count <= 4'd0;
                if (rx_valid) begin
                    if (is_space(rx_data) || is_eol(rx_data)) begin
                        state <= ST_IDLE;
                    end else if ((rx_data == "W") || (rx_data == "w")) begin
                        state <= ST_W_ADDR;
                    end else if ((rx_data == "R") || (rx_data == "r")) begin
                        state <= ST_R_ADDR;
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_W_ADDR: begin
                if (rx_valid) begin
                    if (is_space(rx_data) && (addr_count == 2'd0)) begin
                        state <= ST_W_ADDR;
                    end else if (is_hex(rx_data)) begin
                        addr_shift <= {addr_shift[3:0], hex_value(rx_data)};
                        if (addr_count == 2'd1) begin
                            addr_count <= 2'd0;
                            state <= ST_W_DATA;
                        end else begin
                            addr_count <= addr_count + 1'b1;
                        end
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_W_DATA: begin
                if (rx_valid) begin
                    if (is_space(rx_data) && (data_count == 4'd0)) begin
                        state <= ST_W_DATA;
                    end else if (is_hex(rx_data)) begin
                        data_shift <= {data_shift[27:0], hex_value(rx_data)};
                        if (data_count == 4'd7) begin
                            data_count <= 4'd0;
                            state <= ST_W_EOL;
                        end else begin
                            data_count <= data_count + 1'b1;
                        end
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_W_EOL: begin
                if (rx_valid) begin
                    if (is_space(rx_data)) begin
                        state <= ST_W_EOL;
                    end else if (is_eol(rx_data)) begin
                        cfg_addr <= addr_shift;
                        cfg_wdata <= data_shift;
                        cfg_wr_en <= 1'b1;
                        start_send(SEND_OK);
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_R_ADDR: begin
                if (rx_valid) begin
                    if (is_space(rx_data) && (addr_count == 2'd0)) begin
                        state <= ST_R_ADDR;
                    end else if (is_hex(rx_data)) begin
                        addr_shift <= {addr_shift[3:0], hex_value(rx_data)};
                        if (addr_count == 2'd1) begin
                            addr_count <= 2'd0;
                            state <= ST_R_EOL;
                        end else begin
                            addr_count <= addr_count + 1'b1;
                        end
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_R_EOL: begin
                if (rx_valid) begin
                    if (is_space(rx_data)) begin
                        state <= ST_R_EOL;
                    end else if (is_eol(rx_data)) begin
                        cfg_addr <= addr_shift;
                        state <= ST_RD_PULSE;
                    end else begin
                        start_error_drain();
                    end
                end
            end

            ST_RD_PULSE: begin
                cfg_rd_en <= 1'b1;
                state <= ST_RD_WAIT;
            end

            ST_RD_WAIT: begin
                state <= ST_RD_WAIT2;
            end

            ST_RD_WAIT2: begin
                state <= ST_RD_CAPTURE;
            end

            ST_RD_CAPTURE: begin
                read_latched <= cfg_rdata;
                start_send(SEND_DATA);
            end

            ST_DRAIN_ERR: begin
                if (rx_valid && is_eol(rx_data))
                    start_send(SEND_ERR);
            end

            ST_SEND: begin
                if (!tx_busy) begin
                    if (send_index < send_len(send_type)) begin
                        tx_data <= send_byte(send_type, send_index, read_latched);
                        tx_start <= 1'b1;
                        send_index <= send_index + 1'b1;
                        state <= ST_SEND_BUSY;
                    end else begin
                        state <= ST_IDLE;
                    end
                end
            end

            ST_SEND_BUSY: begin
                if (tx_busy)
                    state <= ST_SEND_IDLE;
            end

            ST_SEND_IDLE: begin
                if (!tx_busy)
                    state <= ST_SEND;
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
