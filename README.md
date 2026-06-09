# AWG K325T — 任意波形信号发生器

> 第二十一届研电赛 · 优利德赛题二 FPGA 数字基带
> 目标器件：Xilinx Kintex-7 XC7K325TFFG900-2（正点原子 K7-325T 开发板）
> 子卡：FMCADDA-9250-9144（AD9250 ADC + AD9144 DAC）

---

## 项目简介

基于 **正点原子 K7-325T** + **FMCADDA-9250-9144 子卡** 的高速任意波形发生器 FPGA 实现。

### 核心指标

| 指标 | 值 |
|------|----|
| DAC | AD9144, 4 通道 16bit, 2.8Gsps |
| ADC | AD9250, 双通道 14bit, 250Msps |
| JESD204B | TX 4L @10Gbps / RX 2L @5Gbps |
| 时钟 | LMK04828 PLL（50M TCXO → 125M/250M）|
| 频率分辨率 | 48bit DDS ≈ 1μHz @250MHz clk |

### 当前进度

- [x] AD9144 DAC 4L JESD204B 建链（GTX @10Gbps）
- [x] AD9250 ADC 2L JESD204B 建链
- [x] LMK04828 SPI 时钟配置
- [x] DDS 信号发生（正弦/三角/方波/锯齿波）
- [x] 扫频引擎
- [x] BRAM 波形回放
- [x] 幅度/偏置缩放
- [x] 数字校准表
- [x] UART 远程控制
- [x] 板载按键控制（频率/波形/幅度/偏置）
- [x] Bitstream 生成

---

## 环境要求

| 项目 | 版本/路径 |
|------|----------|
| **Vivado** | **2024.1 Enterprise Edition** |
| 目标器件 | `xc7k325tffg900-2` |
| License | Synthesis + `xc7k325t` + JESD204 |

> **注意**：Vivado 2024.2+ 已移除 7 系列 JESD204 IP 支持，必须使用 2024.1。

---

## 快速开始

### 1. 生成 Bitstream

```powershell
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/fix_synth.tcl
```

输出：`vivado/awg_k325t.runs/impl_1/awg_top.bit`

### 2. 重新构建工程（如需）

```tcl
# Vivado Tcl Console
source scripts/build_all.tcl
```

---

## 仓库结构

```
Electronics-Competition/
├── rtl/                    # Verilog RTL 源码
│   ├── top/                # 顶层模块 awg_top
│   ├── control/            # 按键 / LED 控制
│   ├── dds/                # DDS + NCO + LUT
│   ├── dsp/                # AWG 核心 / 幅度偏置 / 复用
│   ├── jesd/               # JESD204B 接口 + SPI 配置
│   ├── sweep/              # 扫频引擎
│   └── wave/               # BRAM 波形播放器
├── constraints/            # XDC 约束文件
│   ├── awg_k325t.xdc       # 主约束（系统级）
│   └── fmc_adda.xdc        # FMC 子卡管脚映射
├── vivado/                 # Vivado 工程 + IP 配置
├── scripts/                # 自动化 Tcl 脚本
├── docs/                   # 文档
│   ├── fmc_adda_signal_map.md  # FMC 信号映射表
│   ├── overview/          # 项目概述（硬件平台、工具链）
│   ├── architecture/      # 系统架构（时钟树、顶层图）
│   ├── modules/           # 模块设计笔记（AD9144/JESD/LMK/DDS）
│   ├── timing/            # 约束与时序（CDC 风险）
│   ├── troubleshooting/   # 问题排查（License/错误/验证流程）
│   ├── reference/         # 参数手册、文件索引
│   ├── competition/       # 竞赛文档
│   └── references/        # 参考原理图 + 用户手册 PDF
├── sim/                    # 仿真 testbench
├── kicad/                  # KiCad 工程（扩展模块）
└── constraints/            # FPGA 约束
```

---

## FMC 信号映射

详见 [`docs/fmc_adda_signal_map.md`](docs/fmc_adda_signal_map.md) — 包含子卡↔底板完整管脚映射表。

---

## 关键文档

| 需求 | 位置 |
|------|------|
| FMC 信号总表 | `docs/fmc_adda_signal_map.md` |
| 子卡用户说明 | `docs/references/FMCADDA-9250-9144子卡用户说明.pdf` |
| 子卡原理图 | `docs/references/FMC_9250_9144_BRD_SCH.pdf` |
| 底板原理图 | `docs/references/K7_BASE_1V3_2025_0111_USER.pdf` |
| 底板 IO 参考 | `docs/references/K7_IO.xdc` |
| FMC 约束 | `constraints/fmc_adda.xdc` |
| 模块设计笔记 | `docs/modules/`（AD9144/JESD/LMK/DDS） |
| 问题排查 | `docs/troubleshooting/`（License/错误/验证） |
| 竞赛设计文档 | `docs/competition/design_document.md` |

---

## Git 规范

### 分支策略

```
main          # 稳定版本
  └── dev     # 日常开发
```

### 提交类型

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 |
| `docs` | 文档 |
| `refactor` | 重构 |
| `chore` | 构建/工具 |

### 提交规范

- 不提交 Vivado 生成文件（`.runs/`, `.cache/`, `.sim/`, `.gen/`）
- 不提交 bitstream（`.bit`）
- 不提交波形配置（`.wcfg`）

---

> **最后更新**: 2026-06-09
