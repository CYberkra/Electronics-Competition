//------------------------------------------------------------------------------
// AWG Menu Controller — 菜单状态机 + 字符帧缓存
// 【AWG 显示屏菜单系统 — 管理菜单状态 + 写入字符帧缓存】
//
// 菜单树:
//   主菜单 → 频率设置 / 波形选择 / 幅度设置 / 偏置设置 / 扫频控制 / 输出控制 / 系统信息
//
// 帧缓存: 510 字节 (30列×17行), 双端口 BRAM
//   Port A: 本模块写入 (菜单更新时)
//   Port B: tile_renderer 读取 (连续扫描)
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module awg_menu_controller #(
    parameter COLS = 30,
    parameter ROWS = 17
) (
    input  wire        clk,
    input  wire        rst_n,

    // EC11 编码器输入
    input  wire signed [7:0] rotation,    // +1 CW, -1 CCW, 0 idle
    input  wire        btn_short,         // 短按: 进入/确认
    input  wire        btn_long,          // 长按: 返回

    // AWG 参数 (从 reg_bank 读取)
    input  wire [47:0] phase_inc,         // 当前频率控制字
    input  wire [1:0]  wave_mode,         // 当前波形
    input  wire [15:0] amplitude_q15,     // 当前幅度
    input  wire        output_enable,     // 输出使能
    input  wire        jesd_sync,         // JESD 链路状态
    input  wire [3:0]  init_state,        // 初始化状态

    // AWG 参数写入 (到 reg_bank)
    output reg         param_wr_en,
    output reg  [7:0]  param_addr,
    output reg  [31:0] param_wdata,
    output reg         param_apply,       // 触发 APPLY

    // 字符帧缓存写端口
    output reg         grid_wr_en,
    output reg  [8:0]  grid_addr,         // 0-509
    output reg  [7:0]  grid_data,

    // 光标位置 (给 tile_renderer)
    output reg  [4:0]  cursor_row,
    output reg  [4:0]  cursor_col
);

    //--------------------------------------------------------------------------
    // 菜单状态
    //--------------------------------------------------------------------------
    localparam MENU_MAIN    = 3'd0;
    localparam MENU_FREQ    = 3'd1;
    localparam MENU_WAVE    = 3'd2;
    localparam MENU_AMP     = 3'd3;
    localparam MENU_OFFSET  = 3'd4;
    localparam MENU_SWEEP   = 3'd5;
    localparam MENU_OUTPUT  = 3'd6;
    localparam MENU_INFO    = 3'd7;

    localparam SUB_SELECT   = 1'b0;  // 浏览菜单项
    localparam SUB_EDIT     = 1'b1;  // 编辑参数

    reg [2:0]  menu_state;
    reg        sub_state;
    reg [2:0]  menu_item;      // 当前菜单中选中的项
    reg [2:0]  menu_item_count; // 当前菜单的总项数

    // 频率编辑步进
    reg [3:0]  freq_step_idx;  // 0=1Hz, 1=10Hz, ... 7=10MHz
    reg [47:0] freq_current;

    //--------------------------------------------------------------------------
    // 旋转脉冲累计
    //--------------------------------------------------------------------------
    reg signed [7:0] rot_acc;
    wire rot_cw  = (rot_acc >=  8'sd4);  // 4 脉冲触发一次
    wire rot_ccw = (rot_acc <= -8'sd4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rot_acc <= 8'sd0;
        end else begin
            if (rotation != 8'sd0) begin
                rot_acc <= rot_acc + rotation;
            end else if (rot_cw || rot_ccw) begin
                rot_acc <= 8'sd0;  // 触发后清零
            end
        end
    end

    //--------------------------------------------------------------------------
    // 菜单状态机
    //--------------------------------------------------------------------------
    reg btn_short_d, btn_long_d;
    reg rot_cw_d, rot_ccw_d;
    reg init_render;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            menu_state    <= MENU_MAIN;
            sub_state     <= SUB_SELECT;
            menu_item     <= 3'd0;
            menu_item_count <= 3'd5;  // 主菜单 5 项
            freq_step_idx <= 4'd3;    // 默认 1kHz 步进
            freq_current  <= 48'd0;
            param_wr_en   <= 1'b0;
            param_addr    <= 8'd0;
            param_wdata   <= 32'd0;
            param_apply   <= 1'b0;
            grid_wr_en    <= 1'b0;
            grid_addr     <= 9'd0;
            grid_data     <= 8'd0;
            cursor_row    <= 5'd1;
            cursor_col    <= 5'd0;
            btn_short_d   <= 1'b0;
            btn_long_d    <= 1'b0;
            rot_cw_d      <= 1'b0;
            rot_ccw_d     <= 1'b0;
            init_render   <= 1'b0;
        end else begin
            // 边沿检测
            btn_short_d <= btn_short;
            btn_long_d  <= btn_long;
            rot_cw_d    <= rot_cw;
            rot_ccw_d   <= rot_ccw;

            param_wr_en <= 1'b0;
            param_apply <= 1'b0;
            grid_wr_en  <= 1'b0;

            // 短按: 进入子菜单 或 确认编辑
            if (btn_short && !btn_short_d) begin
                if (sub_state == SUB_SELECT) begin
                    case (menu_state)
                        MENU_MAIN: begin
                            case (menu_item)
                                3'd0: begin menu_state <= MENU_FREQ;   menu_item <= 3'd0; end
                                3'd1: begin menu_state <= MENU_WAVE;   menu_item <= 3'd0; end
                                3'd2: begin menu_state <= MENU_AMP;    menu_item <= 3'd0; end
                                3'd3: begin menu_state <= MENU_SWEEP;  menu_item <= 3'd0; end
                                3'd4: begin menu_state <= MENU_INFO;   menu_item <= 3'd0; end
                            endcase
                        end
                        MENU_FREQ: begin
                            sub_state <= SUB_EDIT;
                            freq_current <= phase_inc;
                        end
                        MENU_WAVE: begin
                            // 直接切换波形
                            if (wave_mode < 2'd3)
                                param_wdata <= {30'd0, wave_mode + 2'd1};
                            else
                                param_wdata <= {30'd0, 2'd0};
                            param_addr  <= 8'h28;  // WAVE_MODE
                            param_wr_en  <= 1'b1;
                            param_apply  <= 1'b1;
                        end
                        MENU_AMP: begin
                            sub_state <= SUB_EDIT;
                        end
                        default: ;
                    endcase
                    init_render <= 1'b1;
                end else begin
                    // SUB_EDIT: 确认并返回
                    sub_state <= SUB_SELECT;
                    param_apply <= 1'b1;
                    init_render <= 1'b1;
                end
            end

            // 长按: 返回上级
            if (btn_long && !btn_long_d) begin
                if (sub_state == SUB_EDIT) begin
                    sub_state <= SUB_SELECT;
                end else begin
                    menu_state <= MENU_MAIN;
                    menu_item  <= 3'd0;
                end
                init_render <= 1'b1;
            end

            // 旋转: 浏览菜单项 或 编辑参数
            if (rot_cw && !rot_cw_d) begin
                if (sub_state == SUB_SELECT) begin
                    if (menu_item < (menu_item_count - 1'b1))
                        menu_item <= menu_item + 1'b1;
                end else begin
                    // 编辑频率
                    case (freq_step_idx)
                        4'd0: freq_current <= freq_current + 48'd1;
                        4'd1: freq_current <= freq_current + 48'd10;
                        4'd2: freq_current <= freq_current + 48'd100;
                        4'd3: freq_current <= freq_current + 48'd1000;
                        default: freq_current <= freq_current + 48'd1000000;
                    endcase
                    // 写频率寄存器
                    param_wr_en  <= 1'b1;
                    param_addr   <= 8'h10;  // PHASE_INC_LO
                    param_wdata  <= freq_current[31:0];
                    // 高16位下一次写
                end
                cursor_row <= 5'd1 + {2'd0, menu_item};
                init_render <= 1'b1;
            end

            if (rot_ccw && !rot_ccw_d) begin
                if (sub_state == SUB_SELECT) begin
                    if (menu_item > 3'd0)
                        menu_item <= menu_item - 1'b1;
                end else begin
                    case (freq_step_idx)
                        4'd0: freq_current <= freq_current - 48'd1;
                        4'd1: freq_current <= freq_current - 48'd10;
                        4'd2: freq_current <= freq_current - 48'd100;
                        4'd3: freq_current <= freq_current - 48'd1000;
                        default: freq_current <= freq_current - 48'd1000000;
                    endcase
                    param_wr_en  <= 1'b1;
                    param_addr   <= 8'h10;
                    param_wdata  <= freq_current[31:0];
                end
                cursor_row <= 5'd1 + {2'd0, menu_item};
                init_render <= 1'b1;
            end

            //--------------------------------------------------------------------------
            // 字符帧缓存渲染 (简化版 — 在菜单切换时全屏刷新)
            //--------------------------------------------------------------------------
            if (init_render) begin
                init_render <= 1'b0;
                grid_wr_en <= 1'b1;

                // 简化: 只渲染标题栏和状态栏，菜单项在切换时更新
                // 标题栏 (Row 0): "  AWG Generator  "
                case (grid_addr)
                    // Row 0: Title
                    9'd0:  grid_data <= 8'h20; // ' '
                    9'd1:  grid_data <= 8'h41; // 'A'
                    9'd2:  grid_data <= 8'h57; // 'W'
                    9'd3:  grid_data <= 8'h47; // 'G'
                    9'd4:  grid_data <= 8'h20; // ' '
                    9'd5:  grid_data <= 8'h47; // 'G'
                    9'd6:  grid_data <= 8'h65; // 'e'
                    9'd7:  grid_data <= 8'h6E; // 'n'
                    9'd8:  grid_data <= 8'h65; // 'e'
                    9'd9:  grid_data <= 8'h72; // 'r'
                    9'd10: grid_data <= 8'h61; // 'a'
                    9'd11: grid_data <= 8'h74; // 't'
                    9'd12: grid_data <= 8'h6F; // 'o'
                    9'd13: grid_data <= 8'h72; // 'r'
                    // ... fill remaining cols with spaces
                    default: begin
                        if (grid_addr < 9'd30)
                            grid_data <= 8'h20; // spaces for title bar
                        else if (grid_addr >= 9'd480) begin
                            // Row 16: Status bar
                            case (grid_addr - 9'd480)
                                9'd0:  grid_data <= output_enable ? 8'h4F : 8'h58; // O/X
                                9'd1:  grid_data <= 8'h4B; // 'K'
                                9'd2:  grid_data <= 8'h20;
                                9'd3:  grid_data <= jesd_sync ? 8'h4C : 8'h21; // L/!
                                9'd4:  grid_data <= 8'h4B; // 'K'
                                default: grid_data <= 8'h20;
                            endcase
                        end else begin
                            grid_data <= 8'h20; // 空白
                        end
                    end
                endcase

                if (grid_addr < 9'd509)
                    grid_addr <= grid_addr + 1'b1;
                else begin
                    grid_addr  <= 9'd0;
                    grid_wr_en <= 1'b0;
                end
            end
        end
    end

endmodule
