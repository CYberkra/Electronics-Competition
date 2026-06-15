# AWG K325T — 任意波形信号发生器

> 第二十一届研电赛 · 优利德赛题二 FPGA 数字基带
> 目标器件：Xilinx Kintex-7 XC7K325TFFG900-2（正点原子 K7-325T）
> 子卡：FMCADDA-9250-9144 (AD9144 DAC)
> 扩展模块：KiCad PCB (ST7789 LCD + EC11 编码器 + Logo 丝印)

---

## 项目简介

基于 **K7-325T** + **AD9144 DAC** 的高速任意波形发生器，TX-only 纯信号生成设计。

### 核心指标

| 指标 | 值 | 赛题要求 |
|------|----|---------|
| DAC | AD9144, 4ch 16bit, 2.8Gsps | ≥5GSa/s ⚠️ |
| 垂直分辨率 | 16 bit | ≥14bit ✅ |
| 频率分辨率 | 48bit DDS, ~μHz | ≤1mHz ✅ |
| JESD204B | TX 4L @10Gbps | — |
| 时钟 | LMK04828 (50M TCXO) | — |
| 控制 | UART 115200 + 按键 | — |

### 实测幅度 (2026-06-14, 满幅度 0x7FFF)

| 100kHz | 1MHz | 10MHz | 100MHz | 300MHz |
|--------|------|-------|--------|--------|
| 60mV | 120mV | 500mV | 680mV | 470mV |

### 当前进度

- [x] JESD204B 4L @10Gbps 建链
- [x] LMK04828 SPI 时钟配置
- [x] SPI clock-enable 重构 (derived clock → clk_in + spi_tick)
- [x] DDS 4级流水线 (48bit, 4采样/周期, Sine LUT 4096×16bit)
- [x] 4种波形 (正弦/方波/三角/锯齿) + BRAM 任意波形
- [x] 扫频引擎 (线性, sweep_engine.v)
- [x] 幅度/偏置 Q1.15 缩放
- [x] UART 远程控制 (115200 8N1 ASCII 协议)
- [x] 板载按键控制 (KEY0/KEY1)
- [x] KiCad 扩展模块 (ST7789 + EC11, 含 Logo 丝印)
- [x] 竞赛文档 (设计文档 + 测试方案 + PPT)
- [ ] 扩展模块 FPGA 驱动 (EC11 + ST7789)
- [ ] 对数扫频
- [ ] 数字校准表实例化 (ad9144_awg_cal)
- [ ] 频谱仪频域测试 (THD/SFDR/ENOB)
- [ ] 外部放大器 (→3Vpp)

---

## 环境要求

| 项目 | 版本/路径 |
|------|----------|
| **Vivado** | **2024.1** (2024.2+ 无 7 系 JESD IP) |
| 目标器件 | `xc7k325tffg900-2` |
| License | Synthesis + JESD204 |

---

## 快速开始

### 构建 & 烧录

```powershell
# 综合 → 实现 → Bitstream
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/build_all.tcl

# 烧录
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/program.tcl
```

### UART 控制

```python
python tools/set_freq.py 50000000  # 50MHz
# 或手动: W 08 00000003 (开控制) → W 10/14 (设频率) → W 2C 00000001 (应用)
```

---

## 仓库结构

```
Electronics-Competition/
├── rtl/               # Verilog RTL (top/ control/ dds/ dsp/ jesd/ sweep/ wave/)
├── constraints/       # XDC 约束 (awg_k325t.xdc, fmc_adda.xdc)
├── vivado/            # Vivado 工程 (.xpr + IP .xci)
├── scripts/           # Tcl 构建/烧录脚本
├── tools/             # Python UART 工具
├── docs/competition/  # 竞赛文档 (设计文档/测试方案/PPT/视频脚本)
├── sim/               # 仿真 testbench
└── kicad/             # KiCad 扩展模块 PCB
```

## 扩展模块管脚

| 功能 | FPGA 引脚 | 备注 |
|------|----------|------|
| TFT SPI (6pin) | N27/M24/M27/M25/N29/M20 | ST7789, P2 CMOS接口 |
| EC11 编码器 | L20/J21/J22 | CMOS_D1/D2/D3 |
| LEDK | L30 | CMOS_D4 |

约束已备注释在 `constraints/awg_k325t.xdc` §14，顶层端口待加。

---

## 关键文档

| 需求 | 位置 |
|------|------|
| 赛题原文 | `docs/competition/uni-trend-problem-statement.md` |
| 设计文档 | `docs/competition/design_document.md` |
| 测试方案 | `docs/competition/AWG指标测试方案.md` |
| 测试记录 | `docs/competition/AWG指标测试结果记录.md` |
| 答辩 PPT | `docs/competition/竞赛答辩PPT.pptx` |
| PPT 大纲 | `docs/competition/答辩PPT内容大纲.md` |
| 视频脚本 | `docs/competition/video_script.md` |
| 扩展模块管脚 | `kicad/模块管脚分配表.csv` |

---

> **最后更新**: 2026-06-15
