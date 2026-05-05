//------------------------------------------------------------------------------
// AD9144 SPI Configuration Controller
// 【AD9144 DAC SPI 配置控制器】
//
// 功能说明：
//   通过 SPI 接口对 AD9144 进行上电初始化配置。
//   支持标准的 4 线 SPI（CSB/SCLK/SDIO），16bit 地址 + 8bit 数据。
//   上电后自动按预定序列写入配置寄存器，完成后拉高 done 信号。
//
// AD9144 SPI 时序：
//   - CSB 低电平有效
//   - SCLK 空闲低电平（Mode 0）
//   - 上升沿采样
//   - 默认 MSB first（可通过寄存器 0x00 改为 LSB first）
//
// 关键寄存器（基于 AD9144 Rev. B datasheet）：
//   0x000  SPI_CONFIG      : 0x3C = LSB first, SDO active, soft reset
//   0x001  CHIP_TYPE       : Read-only, expect 0x04 (DAC)
//   0x002  PROD_ID_L       : Read-only, expect 0x44
//   0x003  PROD_ID_H       : Read-only, expect 0x91
//   0x011  JESD_CTRL1      : 链路数、插值、模式设置
//   0x012  JESD_CTRL2      : Subclass 1, SCR, LID
//   0x080  DAC_CTRL        : DAC 使能
//------------------------------------------------------------------------------

module ad9144_spi_ctrl (
    input  wire        clk,       // 系统时钟（100MHz）
    input  wire        rst_n,     // 低电平复位
    input  wire        start,     // 启动配置脉冲
    output reg         done,      // 配置完成标志
    output reg         busy,      // 配置进行中

    // SPI 接口（连接到 AD9144）
    output reg         spi_csb,   // Chip Select Bar，低有效
    output reg         spi_sclk,  // SPI 时钟
    output reg         spi_sdio,  // SPI 数据（双向，此处仅输出）
    input  wire        spi_sdo,   // SPI 数据输入（读回时用）

    // 状态指示
    output reg         init_ok,   // 初始化成功（Chip ID 匹配）
    output reg [7:0]  chip_id_l, // 读回的 Chip ID 低字节
    output reg [7:0]  chip_id_h  // 读回的 Chip ID 高字节
);

    //--------------------------------------------------------------------------
    // 参数定义
    //--------------------------------------------------------------------------
    localparam CLK_DIV = 4;       // SPI 时钟分频：100MHz / 4 = 25MHz SCLK
    localparam ADDR_W  = 16;      // SPI 地址宽度
    localparam DATA_W  = 8;       // SPI 数据宽度
    localparam TOTAL_W = ADDR_W + DATA_W; // 每帧总位数

    // 配置表项数
    localparam CFG_NUM = 8;

    // 状态机状态
    localparam [3:0] IDLE     = 4'd0,
                     WAIT     = 4'd1,
                     START_CSB= 4'd2,
                     SHIFT    = 4'd3,
                     END_CSB  = 4'd4,
                     DELAY    = 4'd5,
                     READ_ID  = 4'd6,
                     CHECK_ID = 4'd7,
                     DONE     = 4'd8;

    //--------------------------------------------------------------------------
    // 内部信号
    //--------------------------------------------------------------------------
    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [7:0]  clk_cnt;
    reg [4:0]  cfg_idx;       // 当前配置表索引
    reg [23:0] shift_reg;     // 移位寄存器（16bit addr + 8bit data）
    reg [7:0]  read_reg;      // 读回数据移位寄存器

    // 配置查找表：{16bit address, 8bit data}
    // 注意：以下为典型值，需根据实际 JESD 模式调整
    reg [23:0] cfg_table [0:CFG_NUM-1];

    //--------------------------------------------------------------------------
    // 配置表初始化
    //--------------------------------------------------------------------------
    initial begin
        // 0: SPI 配置 — LSB first, SDO active, soft reset
        cfg_table[0] = {16'h0000, 8'h3C};
        // 1: 软件复位释放
        cfg_table[1] = {16'h0000, 8'h3D};
        // 2: JESD 控制1 — 4 lanes, Mode 0, interpolation x1
        cfg_table[2] = {16'h0011, 8'h00};
        // 3: JESD 控制2 — Subclass 1, SCR enable, LID=0
        cfg_table[3] = {16'h0012, 8'h01};
        // 4: 链路配置 — K=32, F=1, M=4, L=4
        cfg_table[4] = {16'h0013, 8'h20};
        // 5: DAC 控制 — 使能所有 4 个 DAC 通道
        cfg_table[5] = {16'h0080, 8'h0F};
        // 6: 仅启用 DAC0（单路输出模式）
        cfg_table[6] = {16'h0081, 8'h01};
        // 7: 数据格式 — 二进制补码, 16bit
        cfg_table[7] = {16'h0082, 8'h00};
    end

    //--------------------------------------------------------------------------
    // SPI 时钟生成（100MHz / CLK_DIV = 25MHz）
    //--------------------------------------------------------------------------
    wire sclk_en = (state == SHIFT);
    wire sclk_posedge = (clk_cnt == CLK_DIV - 1);
    wire sclk_negedge = (clk_cnt == CLK_DIV/2 - 1);

    //--------------------------------------------------------------------------
    // 主状态机
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            spi_csb   <= 1'b1;
            spi_sclk  <= 1'b0;
            spi_sdio  <= 1'b0;
            bit_cnt   <= 0;
            clk_cnt   <= 0;
            cfg_idx   <= 0;
            shift_reg <= 0;
            read_reg  <= 0;
            done      <= 1'b0;
            busy      <= 1'b0;
            init_ok   <= 1'b0;
            chip_id_l <= 0;
            chip_id_h <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done   <= 1'b0;
                    busy   <= 1'b0;
                    spi_csb  <= 1'b1;
                    spi_sclk <= 1'b0;
                    clk_cnt  <= 0;
                    if (start) begin
                        state   <= START_CSB;
                        busy    <= 1'b1;
                        cfg_idx <= 0;
                    end
                end

                START_CSB: begin
                    // 加载当前配置字
                    shift_reg <= cfg_table[cfg_idx];
                    bit_cnt   <= TOTAL_W - 1;
                    spi_csb   <= 1'b0;  // 拉低 CSB
                    state     <= SHIFT;
                    clk_cnt   <= 0;
                end

                SHIFT: begin
                    if (sclk_posedge) begin
                        spi_sclk <= 1'b1;
                        // 上升沿：AD9144 采样 SDIO（发送最高位）
                        spi_sdio <= shift_reg[TOTAL_W - 1];
                        clk_cnt  <= clk_cnt + 1'b1;
                    end else if (sclk_negedge) begin
                        spi_sclk <= 1'b0;
                        // 下降沿：移位，准备下一位
                        shift_reg <= {shift_reg[TOTAL_W-2:0], 1'b0};
                        if (bit_cnt == 0) begin
                            state <= END_CSB;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                END_CSB: begin
                    spi_csb <= 1'b1;   // 拉高 CSB，结束一帧
                    spi_sclk <= 1'b0;
                    state <= DELAY;
                    clk_cnt <= 0;
                end

                DELAY: begin
                    // 帧间延时（> 20ns setup/hold）
                    if (clk_cnt >= 8'd10) begin
                        if (cfg_idx < CFG_NUM - 1) begin
                            cfg_idx <= cfg_idx + 1'b1;
                            state   <= START_CSB;
                        end else begin
                            state <= READ_ID;
                        end
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                READ_ID: begin
                    // 读回 CHIP_ID_L (0x02) 验证通信
                    shift_reg <= {16'h0002, 8'h00}; // 读命令，地址=0x02
                    bit_cnt   <= TOTAL_W - 1;
                    spi_csb   <= 1'b0;
                    state     <= SHIFT;
                    clk_cnt   <= 0;
                end

                CHECK_ID: begin
                    chip_id_l <= read_reg;
                    // 检查 ID 是否匹配（AD9144 的 CHIP_ID = 0x9144）
                    if (chip_id_l == 8'h44) begin
                        init_ok <= 1'b1;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // 读回数据移位（在 SHIFT 状态时采样 spi_sdo）
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_reg <= 0;
        end else if (state == SHIFT && sclk_posedge) begin
            read_reg <= {read_reg[6:0], spi_sdo};
        end
    end

endmodule
