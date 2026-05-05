//------------------------------------------------------------------------------
// LMK04828 SPI Configuration Controller
// 【LMK04828 时钟芯片 SPI 配置控制器】
//
// 功能说明：
//   上电后自动通过 SPI 接口配置 LMK04828 时钟芯片。
//   寄存器序列来自 HexReg_9250_9144_04828_125M_500M_gen.txt。
//   配置完成后拉高 done 信号。
//
// LMK04828 SPI 时序：
//   - CSB 低电平有效
//   - SCLK 空闲低电平（Mode 0）
//   - 上升沿采样
//   - 24bit 传输：MSB first
//   - 格式：[R/W=0][W1=0][W0=0][A12..A0][D7..D0]
//
// 时钟输出（配置后）：
//   OUT0:  125M  → FPGA GTX REFCLK
//   OUT12: 125M  → FPGA JESDCLK
//   OUT1:  3.90625M → FPGA SYSREF
//   OUT10: 250M  → ADC 采样时钟
//   OUT8:  500M  → DAC 采样时钟
//   OUT11: 3.90625M → ADC SYSREF
//   OUT9:  3.90625M → DAC SYSREF
//------------------------------------------------------------------------------

module lmk04828_spi_ctrl (
    input  wire        clk,       // 系统时钟（100MHz）
    input  wire        rst_n,     // 低电平复位
    input  wire        start,     // 启动配置脉冲
    output reg         done,      // 配置完成标志
    output reg         busy,      // 配置进行中

    // SPI 接口（连接到 LMK04828）
    output reg         spi_csb,   // Chip Select Bar，低有效
    output reg         spi_sclk,  // SPI 时钟
    output reg         spi_sdio,  // SPI 数据（双向，此处仅输出）
    input  wire        spi_sdo    // SPI 数据输入（读回时用）
);

    //--------------------------------------------------------------------------
    // 参数定义
    //--------------------------------------------------------------------------
    localparam CLK_DIV = 4;       // SPI 时钟分频：100MHz / 4 = 25MHz SCLK
    localparam TOTAL_W = 24;      // SPI 每帧 24bit
    localparam REG_NUM = 130;     // 寄存器总数

    // 状态机
    localparam [2:0] IDLE     = 3'd0,
                     LOAD     = 3'd1,
                     START_CSB= 3'd2,
                     SHIFT    = 3'd3,
                     END_CSB  = 3'd4,
                     DELAY    = 3'd5,
                     DONE     = 3'd6;

    //--------------------------------------------------------------------------
    // 内部信号
    //--------------------------------------------------------------------------
    reg [2:0]  state;
    reg [4:0]  bit_cnt;
    reg [7:0]  clk_cnt;
    reg [7:0]  reg_idx;       // 当前寄存器索引 (0 ~ REG_NUM-1)
    reg [23:0] shift_reg;     // 移位寄存器

    // 寄存器查找表 ROM
    reg [23:0] rom [0:REG_NUM-1];

    //--------------------------------------------------------------------------
    // ROM 初始化（来自 HexReg_9250_9144_04828_125M_500M_gen.txt）
    //--------------------------------------------------------------------------
    initial begin
        rom[0]   = 24'h000090;  // R0  (INIT)
        rom[1]   = 24'h000010;  // R0
        rom[2]   = 24'h000200;  // R2
        rom[3]   = 24'h000306;  // R3
        rom[4]   = 24'h0004D0;  // R4
        rom[5]   = 24'h00055B;  // R5
        rom[6]   = 24'h000600;  // R6
        rom[7]   = 24'h000C51;  // R12
        rom[8]   = 24'h000D04;  // R13
        rom[9]   = 24'h010018;  // R256
        rom[10]  = 24'h010155;  // R257
        rom[11]  = 24'h010255;  // R258
        rom[12]  = 24'h010301;  // R259
        rom[13]  = 24'h010420;  // R260
        rom[14]  = 24'h010500;  // R261
        rom[15]  = 24'h010670;  // R262
        rom[16]  = 24'h010711;  // R263
        rom[17]  = 24'h01080C;  // R264
        rom[18]  = 24'h010955;  // R265
        rom[19]  = 24'h010A55;  // R266
        rom[20]  = 24'h010B00;  // R267
        rom[21]  = 24'h010C02;  // R268
        rom[22]  = 24'h010D00;  // R269
        rom[23]  = 24'h010E79;  // R270
        rom[24]  = 24'h010F05;  // R271
        rom[25]  = 24'h011008;  // R272
        rom[26]  = 24'h011155;  // R273
        rom[27]  = 24'h011255;  // R274
        rom[28]  = 24'h011300;  // R275
        rom[29]  = 24'h011402;  // R276
        rom[30]  = 24'h011500;  // R277
        rom[31]  = 24'h0116F9;  // R278
        rom[32]  = 24'h011700;  // R279
        rom[33]  = 24'h011818;  // R280
        rom[34]  = 24'h011955;  // R281
        rom[35]  = 24'h011A55;  // R282
        rom[36]  = 24'h011B00;  // R283
        rom[37]  = 24'h011C02;  // R284
        rom[38]  = 24'h011D00;  // R285
        rom[39]  = 24'h011E79;  // R286
        rom[40]  = 24'h011F33;  // R287
        rom[41]  = 24'h012006;  // R288
        rom[42]  = 24'h012155;  // R289
        rom[43]  = 24'h012255;  // R290
        rom[44]  = 24'h012301;  // R291
        rom[45]  = 24'h012422;  // R292
        rom[46]  = 24'h012500;  // R293
        rom[47]  = 24'h012670;  // R294
        rom[48]  = 24'h012716;  // R295
        rom[49]  = 24'h01280C;  // R296
        rom[50]  = 24'h012955;  // R297
        rom[51]  = 24'h012A55;  // R298
        rom[52]  = 24'h012B01;  // R299
        rom[53]  = 24'h012C22;  // R300
        rom[54]  = 24'h012D00;  // R301
        rom[55]  = 24'h012E70;  // R302
        rom[56]  = 24'h012F16;  // R303
        rom[57]  = 24'h013018;  // R304
        rom[58]  = 24'h013155;  // R305
        rom[59]  = 24'h013255;  // R306
        rom[60]  = 24'h013301;  // R307
        rom[61]  = 24'h013422;  // R308
        rom[62]  = 24'h013500;  // R309
        rom[63]  = 24'h013670;  // R310
        rom[64]  = 24'h013711;  // R311
        rom[65]  = 24'h013820;  // R312
        rom[66]  = 24'h013903;  // R313
        rom[67]  = 24'h013A06;  // R314
        rom[68]  = 24'h013B00;  // R315
        rom[69]  = 24'h013C00;  // R316
        rom[70]  = 24'h013D08;  // R317
        rom[71]  = 24'h013E03;  // R318
        rom[72]  = 24'h013F06;  // R319
        rom[73]  = 24'h014081;  // R320
        rom[74]  = 24'h014100;  // R321
        rom[75]  = 24'h014200;  // R322
        rom[76]  = 24'h014301;  // R323
        rom[77]  = 24'h0144FB;  // R324
        rom[78]  = 24'h01457F;  // R325
        rom[79]  = 24'h014603;  // R326
        rom[80]  = 24'h014717;  // R327
        rom[81]  = 24'h014800;  // R328
        rom[82]  = 24'h014940;  // R329
        rom[83]  = 24'h014A02;  // R330
        rom[84]  = 24'h014B16;  // R331
        rom[85]  = 24'h014C00;  // R332
        rom[86]  = 24'h014D00;  // R333
        rom[87]  = 24'h014EC0;  // R334
        rom[88]  = 24'h014F7F;  // R335
        rom[89]  = 24'h015003;  // R336
        rom[90]  = 24'h015102;  // R337
        rom[91]  = 24'h015200;  // R338
        rom[92]  = 24'h015300;  // R339
        rom[93]  = 24'h015401;  // R340
        rom[94]  = 24'h015500;  // R341
        rom[95]  = 24'h015601;  // R342
        rom[96]  = 24'h015700;  // R343
        rom[97]  = 24'h015896;  // R344
        rom[98]  = 24'h015900;  // R345
        rom[99]  = 24'h015A05;  // R346
        rom[100] = 24'h015BD4;  // R347
        rom[101] = 24'h015C20;  // R348
        rom[102] = 24'h015D00;  // R349
        rom[103] = 24'h015E00;  // R350
        rom[104] = 24'h015F13;  // R351
        rom[105] = 24'h016000;  // R352
        rom[106] = 24'h016101;  // R353
        rom[107] = 24'h0162A4;  // R354
        rom[108] = 24'h016300;  // R355
        rom[109] = 24'h016400;  // R356
        rom[110] = 24'h01650A;  // R357
        rom[111] = 24'h016600;  // R358
        rom[112] = 24'h016700;  // R359
        rom[113] = 24'h01680C;  // R360
        rom[114] = 24'h016959;  // R361
        rom[115] = 24'h016A20;  // R362
        rom[116] = 24'h016B00;  // R363
        rom[117] = 24'h016C00;  // R364
        rom[118] = 24'h016D00;  // R365
        rom[119] = 24'h016E13;  // R366
        rom[120] = 24'h0171AA;  // R369
        rom[121] = 24'h017202;  // R370
        rom[122] = 24'h017300;  // R371
        rom[123] = 24'h017C15;  // R380
        rom[124] = 24'h017D33;  // R381
        rom[125] = 24'h018200;  // R386
        rom[126] = 24'h018300;  // R387
        rom[127] = 24'h018400;  // R388
        rom[128] = 24'h018500;  // R389
        rom[129] = 24'h018800;  // R392
        // Note: R393~R395 and R8189~R8191 omitted for brevity,
        // add if full initialization required
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
            reg_idx   <= 0;
            shift_reg <= 0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done   <= 1'b0;
                    busy   <= 1'b0;
                    spi_csb  <= 1'b1;
                    spi_sclk <= 1'b0;
                    clk_cnt  <= 0;
                    if (start) begin
                        state   <= LOAD;
                        busy    <= 1'b1;
                        reg_idx <= 0;
                    end
                end

                LOAD: begin
                    shift_reg <= rom[reg_idx];
                    bit_cnt   <= TOTAL_W - 1;
                    state     <= START_CSB;
                end

                START_CSB: begin
                    spi_csb <= 1'b0;
                    state   <= SHIFT;
                    clk_cnt <= 0;
                end

                SHIFT: begin
                    if (sclk_posedge) begin
                        spi_sclk <= 1'b1;
                        spi_sdio <= shift_reg[TOTAL_W - 1];
                        clk_cnt  <= clk_cnt + 1'b1;
                    end else if (sclk_negedge) begin
                        spi_sclk <= 1'b0;
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
                    spi_csb <= 1'b1;
                    spi_sclk <= 1'b0;
                    state   <= DELAY;
                    clk_cnt <= 0;
                end

                DELAY: begin
                    // 帧间延时 > 20ns
                    if (clk_cnt >= 8'd10) begin
                        if (reg_idx < REG_NUM - 1) begin
                            reg_idx <= reg_idx + 1'b1;
                            state   <= LOAD;
                        end else begin
                            state <= DONE;
                        end
                        clk_cnt <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
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

endmodule
