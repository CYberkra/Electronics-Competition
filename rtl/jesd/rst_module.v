
module rst_module(
                        input      i_sys_clk,
                        input      i_sys_rst_async,
                        output reg o_mod1_rstn = 0,
                        output reg o_mod2_rstn = 0
);
reg r_sys_rst1, r_sys_rst2;
reg[31:0] rst_cnt;
always @(posedge i_sys_clk or negedge i_sys_rst_async) begin
    if(!i_sys_rst_async) begin
        rst_cnt <= 16'd0;
        r_sys_rst1 <= 1'b0;
        r_sys_rst2 <= 1'b0;
        end
    else if(rst_cnt <= 32'd10000) begin
        r_sys_rst1 <= 1'b0;
        r_sys_rst2 <= 1'b0;
        rst_cnt <= rst_cnt + 1'd1;
        end
    else if(rst_cnt <= 32'd20000)begin
        r_sys_rst1 <= 1'b1;
        r_sys_rst2 <= 1'b0;
        rst_cnt <= rst_cnt + 1'd1;
        end
    else begin
        r_sys_rst1 <= 1'b1;
        r_sys_rst2 <= 1'b1;
        rst_cnt <= rst_cnt;
        end

end

always @ (posedge i_sys_clk) begin
    o_mod1_rstn <= r_sys_rst1;
    o_mod2_rstn <= r_sys_rst2;
end

endmodule
