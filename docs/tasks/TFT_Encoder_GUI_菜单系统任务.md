# TFT + 旋转编码器 GUI 菜单系统

> 负责人：待分配 | 预计工期：1-2天 | 可配合 Claude Code/Codex 开发
> 硬件：ST7789 1.69" LCD (240×280) + EC11 旋转编码器 (已焊接)
> 管脚表：`kicad/模块管脚分配表.csv` 或 `CLAUDE.md` §Expansion Module

## 方案选择

### 为什么不推荐 LVGL

LVGL 需要 CPU (MicroBlaze/RISC-V) + 几十KB RAM + frame buffer (~135KB RGB565)，K325T 资源够但：
- MicroBlaze 软核引入工具链复杂度
- LVGL 移植和调试周期远超竞赛准备时间
- 240×280 分辨率下纯文字菜单已经够用

### 推荐：Tile-based 字符菜单系统

**核心思路**：将屏幕视为 30×17 字符网格 (8×16 字体)，FPGA 只存 510 字节字符码 + 2KB 字模 ROM，纯硬件渲染。

```
┌──────────────────────────────────────┐
│  AWG 任意波形信号发生器              │  ← 标题栏 (1行)
├──────────────────────────────────────┤
│                                     │
│   ▶ 频率:  50.000 000 MHz           │  ← 菜单项 (每项1行)
│     波形:  Sine                     │
│     幅度:  75%                      │
│     偏置:  0 mV                     │
│                                     │
│     扫频设置                        │
│     系统信息                        │
│                                     │
├──────────────────────────────────────┤
│  ↻旋转选择   ●按下确认              │  ← 状态栏 (1行)
└──────────────────────────────────────┘
```

## 系统架构

```
awg_top.v
  └── gui_top.v (新增顶层)
        ├── ec11_decoder.v     # 正交解码 + 消抖 + 按键检测
        ├── menu_controller.v  # 菜单状态机 + 字符帧缓存写入
        ├── char_rom.v         # 8×16 ASCII 字模 ROM (BRAM)
        ├── tile_renderer.v    # 字符码 → 像素数据 (实时扫描)
        └── st7789_driver.v    # SPI 时序 + 初始化序列
```

### 各模块说明

#### 1. ec11_decoder.v — 旋转编码器解码

```verilog
module ec11_decoder (
    input  clk,          // 建议用 clk_25m (SPI 时钟域)
    input  rst_n,
    input  ec11_a,       // A 相
    input  ec11_b,       // B 相
    input  ec11_btn,     // 按键 (带外部上拉)
    output reg signed [7:0] rotation,  // +1 或 -1 脉冲
    output reg btn_short,              // 短按 (单次脉冲)
    output reg btn_long                // 长按 (>1s)
);
```

**EC11 时序**：
```
顺时针 (CW):  A ──┐   ┌──┐   相位 A 领先 B 90°
              B ──┼──┐│┌─┼──  当 A↓ 且 B=1 → CW
逆时针 (CCW): A ──┐   ┌──┐   相位 B 领先 A 90°
              B ─┐┼──┘│└─┼─  当 A↓ 且 B=0 → CCW
```

**实现要点**：
- 用 25MHz 时钟过采样 A/B (机械编码器最高 ~10kHz)
- 2 级同步器消除亚稳态
- 状态机检测 A/B 边沿 → 输出 ±1 脉冲
- 按键消抖 ~20ms，长按判断 ~1s

#### 2. menu_controller.v — 菜单状态机

**菜单树结构**：

```
主菜单
├── 频率设置
│   ├── 粗调: 1MHz 步进
│   ├── 中调: 10kHz 步进
│   └── 细调: 1Hz 步进
├── 波形选择
│   ├── Sine / Square / Triangle / Saw / Arbitrary
├── 幅度设置
│   ├── 粗调 / 细调
├── 偏置设置
├── 扫频控制
│   ├── 起始频率 / 终止频率 / 步进 / 驻留时间
│   └── 启动 / 停止
├── 输出控制
│   └── 输出使能 ON/OFF
└── 系统信息
    ├── 设备 ID / 固件版本
    └── JESD 链路状态
```

**状态编码**：

```verilog
localparam MENU_MAIN       = 4'd0;
localparam MENU_FREQ       = 4'd1;
localparam MENU_WAVE       = 4'd2;
localparam MENU_AMP        = 4'd3;
localparam MENU_OFFSET     = 4'd4;
localparam MENU_SWEEP      = 4'd5;
localparam MENU_OUTPUT     = 4'd6;
localparam MENU_INFO       = 4'd7;

// 子状态
localparam SUB_SELECT      = 2'd0;  // 选择菜单项
localparam SUB_EDIT        = 2'd1;  // 编辑参数值
```

**与 awg_reg_bank 接口**：
- `menu_controller` 通过 UART 桥相同的寄存器接口写入 `awg_reg_bank`
- 频率/幅度/波形修改后触发 APPLY (写 0x2C)

#### 3. char_rom.v — 字模 ROM

```verilog
module char_rom (
    input  [7:0] char_code,   // ASCII 码 (0x20-0x7F)
    input  [3:0] row,          // 字符内行号 (0-15)
    output [7:0] bitmap        // 8 像素位图
);
```

- 覆盖 ASCII 32-127 (96 可打印字符)
- 每个字符 8×16 像素 → 96×16 = 1536 字节
- 使用 8×16 终端字体（如 Terminus, IBM VGA）
- BRAM 初始化用 `$readmemh`

**字体生成方法**：
```python
# Python 脚本：从 BDF/PCF 字体文件生成 .hex ROM 初始化文件
# 或直接硬编码 8×16 等宽字体
```

#### 4. tile_renderer.v — 字符渲染器

```verilog
module tile_renderer (
    input  clk,
    input  rst_n,
    // 连接到 ST7789
    output reg        tft_dc,    // 命令/数据
    output reg [7:0]  tft_data,  // SPI 数据
    output reg        tft_start  // 传输触发
);
```

- 每帧从 (0,0) 扫描到 (239,279)
- 每个像素：确定所在 tile (col, row) → 查字符码 → 查字模 → 输出颜色
- 行/场同步以匹配 ST7789 刷新率 (~60Hz)

**优化**：由于 ST7789 每次传输一个像素需要 ~20 SPI 时钟周期，30×17 字符 × 16 行 = 8160 次字模查找/帧。在 25MHz SPI 下，每像素约 0.8μs，全屏 ~53ms，可接受。

#### 5. st7789_driver.v — LCD 驱动

```verilog
module st7789_driver (
    input  clk,           // 25MHz (SPI 时钟)
    input  rst_n,
    // SPI 接口
    output reg  tft_scl,
    output reg  tft_sda,
    output reg  tft_cs,
    output reg  tft_dc,
    output reg  tft_res,
    output reg  tft_blk,
    // 像素输入
    input  [7:0] pixel_r,
    input  [7:0] pixel_g,
    input  [7:0] pixel_b,
    input        pixel_valid,
    output       pixel_ready
);
```

**初始化序列**（参考 ST7789 数据手册）：
```
复位 → SWRESET → SLPOUT → COLMOD(0x55=16bit) → MADCTL → 
INVON → NORON → DISPON
```

**像素写入流程**：
1. CASET (0x2A) — 设置列地址范围
2. RASET (0x2B) — 设置行地址范围
3. RAMWR (0x2C) — 连续写入像素数据

## 开发步骤 (1-2天)

### Day 1: EC11 编码器 (MVP)

| 步骤 | 任务 | 验证 |
|------|------|------|
| 1 | `ec11_decoder.v` — 正交解码 + 消抖 | LED 指示旋转方向 / ILA |
| 2 | EC11 → UART 命令桥 (CW=波形+, CCW=频率-, BTN=APPLY) | 示波器波形随旋钮变化 |
| 3 | 约束使能 (awg_k325t.xdc §14 取消注释) | 综合通过 |

**Day 1 即可交付**：旋钮控制 AWG 参数（脱离 PC）。

### Day 2: TFT 显示 (可选增强)

| 步骤 | 任务 | 验证 |
|------|------|------|
| 4 | `st7789_driver.v` — SPI 时序 + 初始化 + 纯色测试 | 屏亮 |
| 5 | `char_rom.v` + 单行文字显示 "AWG 50.0MHz Sine" | 屏显 |
| 6 | EC11 调参数时刷新显示 | 旋钮调→屏变 |

**备选极简方案**：EC11 直接发 UART 命令（字符终端），一天搞定。

## 与 Claude Code 协作提示

### 提示词模板

```
我需要为 FPGA 项目实现 ST7789 LCD 的 SPI 驱动。
请帮我写一个 Verilog 模块 st7789_driver.v：
- 25MHz SPI 时钟
- 3 线 SPI (SCL, SDA, CS) + DC (命令/数据切换) + RES + BLK
- 包含完整的初始化序列 (参考 ST7789V 数据手册)
- 支持连续写像素 (CASET + RASET + RAMWR)
- 像素输入接口: 8bit RGB + valid/ready 握手
```

```
帮我实现 EC11 旋转编码器的正交解码 Verilog 模块：
- 2 级同步器消抖
- 检测 CW/CCW 旋转 → 输出 ±1 脉冲
- 按键消抖 (20ms) + 长按检测 (1s)
```

### 参考资源

| 资源 | 用途 |
|------|------|
| ST7789V datasheet | 初始化序列、命令表、时序 |
| EC11 datasheet | 机械参数、电气特性 |
| `constraints/awg_k325t.xdc` §14 | 管脚约束（注释状态，取消注释即可用） |
| `rtl/jesd/spi_wr_rd_single.v` | 现有 SPI 控制器参考 |
| `rtl/control/awg_key_ui_ctrl.v` | 现有按键消抖逻辑参考 |

## 备选：极简 ASCII 终端方案

如果时间不够，可以用更简单的方式：EC11 只发 UART 命令，电脑上串口终端显示菜单。

```verilog
// EC11 转 UART 命令
// CW → 发送 "W 28 01\n" (切方波)
// CCW → 发送 "W 28 00\n" (切正弦)
// BTN → 发送 "W 2C 01\n" (APPLY)
```

此方案当天可完成，可用作 MVP 验证编码器硬件正常。
