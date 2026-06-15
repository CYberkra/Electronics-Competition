# SFCW / FMCW 波形生成任务

> 负责人：待分配 | 预计工期：1-2天 | 前置依赖：DDS + sweep_engine 已验证

## 背景

赛题要求支持扫频功能。当前已实现线性扫频 (`sweep_engine.v`)，SFCW/FMCW 是在此基础上的扩展。

## 技术方案

### SFCW (Stepped Frequency Continuous Wave)

**原理**：在每个频点驻留固定时间，然后跳变到下一个频点。本质就是现在的线性扫频。

**实现**：
- 现有 `sweep_engine.v` 已支持线性步进扫频（固定 Δf step，固定驻留时间）
- 需要做的：把 `sweep_engine` 参数做成 UART 可编程寄存器
- 寄存器映射建议：

| 地址 | 寄存器 | 位宽 | 说明 |
|------|--------|------|------|
| 0x50 | SWEEP_START_LO | 32 | 起始频率 phase_inc 低32位 |
| 0x54 | SWEEP_START_HI | 16 | 起始频率 phase_inc 高16位 |
| 0x58 | SWEEP_STOP_LO | 32 | 终止频率 |
| 0x5C | SWEEP_STOP_HI | 16 | |
| 0x60 | SWEEP_STEP_LO | 32 | 频率步进 |
| 0x64 | SWEEP_STEP_HI | 16 | |
| 0x68 | SWEEP_DWELL | 32 | 每步驻留时间 (tx_core_clk 周期数) |
| 0x6C | SWEEP_CTRL | 4 | bit0: 启动, bit1: 方向, bit2: 模式(0=线性/1=对数) |

**FMCW 信号验证方法**：
- 用频谱仪 Max Hold 模式看扫频范围
- 用频谱仪 Spectrogram（瀑布图）看频率随时间线性变化

### FMCW (Frequency Modulated Continuous Wave)

**原理**：频率连续线性变化（线性调频 chirp）。在 FPGA 实现中 = 每个时钟周期 phase_inc 都微调一个 Δ。

**实现方案**：
- 在 `ad9144_awg_dds4.v` 中增加 chirp 模式
- 新增 `chirp_en` 使能，使能时 `phase_inc` 每周期自增 `chirp_slope`
- 参数：

```verilog
// 向 DDS4 模块添加端口
input  wire        chirp_en,        // chirp 使能
input  wire [47:0] chirp_slope,     // phase_inc 每周期增量 (Hz/s)
input  wire [47:0] chirp_start_inc, // 起始频率控制字
input  wire [47:0] chirp_stop_inc,  // 终止频率控制字 (达到后停止/回绕)
```

- chirp 模式下 `phase_inc` 动态更新：
  ```verilog
  if (chirp_en) begin
      if (chirp_up && phase_inc < chirp_stop_inc)
          phase_inc <= phase_inc + chirp_slope;
      else if (!chirp_up && phase_inc > chirp_stop_inc)
          phase_inc <= phase_inc - chirp_slope;
  end
  ```

**扫频速率计算**：
- 扫频速率 (Hz/s) = `chirp_slope × 1_000_000_000 / 2^48 × f_tx_core_clk`
- 例如：250MHz clk, chirp_slope=0x1000 → ~3.55 kHz/s 扫频速率

### 与现有扫频引擎的关系

```
sweep_engine.v (现有)
├── 线性步进扫频 ✅ (已完成)
│   └── → SFCW (参数可编程化)
│
ad9144_awg_dds4.v (需扩展)
├── chirp 模式 (新增)
│   └── → FMCW (连续调频)
```

## 开发步骤 (1-2天)

1. **SFCW 参数可编程化** (Day 1)
   - 在 `ad9144_awg_reg_bank.v` 中添加寄存器 0x50-0x6C
   - `sweep_engine.v` 改用 reg_bank 输出驱动（替代硬编码 parameter）
   - Python 测试脚本验证扫频范围

2. **验证** (Day 1-2)
   - 频谱仪 Max Hold 看扫频覆盖范围
   - UART 动态改扫频参数

**FMCW chirp 模式** → 后续迭代

## 验证方法

| 信号类型 | 验证工具 | 观察内容 |
|---------|---------|---------|
| SFCW | 频谱仪 Max Hold | 频率范围内连续频点、无空隙 |
| SFCW | 频谱仪 Spectrogram | 阶梯状频率变化 |
| FMCW | 频谱仪 Spectrogram | 连续斜线频率变化 |
| FMCW | 示波器 FFT | 时域波形 + 频域变化 |

## 参考

- `rtl/sweep/sweep_engine.v` — 现有扫频引擎
- `rtl/jesd/ad9144_awg_dds4.v` — DDS 核心
- `rtl/jesd/ad9144_awg_reg_bank.v` — 寄存器映射
