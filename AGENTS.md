# FPGA Project Agent Notes

> **Agent 必读提示**
> 
> 本文档是 K325T AWG 项目的**知识库**。任何协助本项目的 Agent 在操作前必须阅读此文档。
> 
> - **快速入口**：查看 [3. 当前项目状态](#3-当前项目状态) 了解最新进展
> - **开发规范**：查看 [5. 技术规范](#5-技术规范) 了解编码和时钟处理标准
> - **踩坑记录**：查看 [6. 经验教训](#6-经验教训) 避免重复犯错
> - **操作指南**：查看 [8. 操作指南](#8-操作指南) 获取常用命令
>
> **最后更新**: 2026-05-06  
> **维护者**: Sisyphus Agent

---

## 目录

1. [项目上下文](#1-项目上下文)
2. [重要参考文档](#2-重要参考文档)
3. [当前项目状态](#3-当前项目状态)
4. [已完成模块详情](#4-已完成模块详情)
5. [技术规范](#5-技术规范)
6. [经验教训](#6-经验教训)
7. [常见问题 FAQ](#7-常见问题-faq)
8. [操作指南](#8-操作指南)
9. [外部资源](#9-外部资源)
10. [Git 版本控制](#10-git-版本控制)
11. [AD9144/JESD204 Bring-Up](#11-ad9144jesd204-bring-up)
12. [文档维护记录](#12-文档维护记录)

---

## 1. 项目上下文

### 1.1 项目目标

基于**正点原子 K7-325T** 开发板完成研电赛优利德赛题二"任意波形信号发生器"的 FPGA 数字基带开发。

**核心指标**:
- 采样率 ≥ 5GSa/s
- 模拟带宽 ≥ 1GHz
- 垂直分辨率 ≥ 14bit
- 正弦最小频率 ≤ 1mHz
- 最高频率 ≥ 1GHz
- 频率分辨率 ≤ 1mHz
- 谐波失真优于 -40dBc
- 非谐波杂散优于 -60dBc

### 1.2 系统架构

**Phase 1 - 基础验证**:
```text
License → LED → clk_reset → DDS → amp_offset_scale → teaching DAC → sweep_engine → BRAM waveform → demo
```

**Phase 2 - 完整系统**:
```text
DDR3 → PCIe XDMA → high-speed DAC → calibration table → full measurement
```

### 1.3 开发环境

| 项目 | 值 |
|------|-----|
| **Vivado 版本** | **2024.1 Enterprise Edition** |
| **Vivado 路径** | `D:\vivado\Vivado\2024.1` |
| **Vivado 启动器** | `D:\vivado\Vivado\2024.1\bin\vivado.bat` |
| **License 管理器** | `D:\vivado\Vivado\2024.1\bin\vlm.bat` |
| **降级原因** | JESD204 IP 仅 2024.1 同时支持 7 系列 + JESD204；Standard Edition 不支持 K325T |
| **目标器件** | `xc7k325tffg900-2` |
| **License 文件** | `C:\Users\17844\AppData\Roaming\XilinxLicense\Xlnx_2024.lic` |
| **原 License 备份** | `C:\Users\17844\AppData\Roaming\XilinxLicense\trial_backup_20260506_093702.lic` |
| **License 状态** | ✅ Synthesis + xc7k325t + jesd204 + bitgen 全功能（2026-05-06） |

**License 验证命令**:
```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\check_k325t_synthesis.tcl
```

### 1.4 开发板关键资源

| 资源 | 规格 |
|------|------|
| FPGA | XC7K325TFFG900-2I |
| 核心板 DDR3 | 4 x 4Gbit NT5CC256M16, 总计 2GB |
| 核心板 QSPI Flash | N25Q128, 128Mbit / 16MB |
| 核心板时钟 | 100MHz 有源差分晶振 |
| 理论 DDR3 带宽 | 1600M x 64 = 102.4 Gbps |
| PCIe | PCIe 2.0 x8 |

### 1.5 路径规则

Vivado 对路径长度和非 ASCII 字符敏感。**优先使用短 ASCII 路径**:

```text
✅ 推荐: D:\awg_fpga\...
✅ 推荐: D:\k7\325\...
❌ 避免: D:\FPGA\【正点原子】Kintex7资料\...
```

---

## 2. 重要参考文档

### 2.1 项目规划文档

| 文档 | 路径 | 用途 |
|------|------|------|
| 架构开发计划 | `D:\FPGA\K325T_AWG_architecture_development_plan.md` | 总体架构和模块划分 |
| 模块流程图 | `D:\FPGA\K325T_AWG_FPGA_module_flowchart.md` | 数据流和模块关系 |
| 完整开发计划 | `D:\FPGA\K325T_AWG_FPGA完整开发计划.md` | 详细开发步骤 |
| 开发板资料整理 | `D:\FPGA\K325T_研电赛优利德赛题二开发板资料整理.md` | 板子资源汇总 |
| 赛题 PDF | `D:\FPGA\第二十一届研电赛优利德命题 (1).pdf` | 赛题要求和评分标准 |

### 2.2 正点原子开发指南

| 文档 | 路径 | 关键章节 |
|------|------|----------|
| FPGA 开发指南 | `D:\FPGA\Kintex7\Kintex7\2_文档教程\【正点原子】Kintex7之FPGA开发指南V1.3.pdf` | Ch2/3(资源), Ch5(LED流程), Ch12/13(时序), Ch16(仿真), Ch18(ILA), Ch19(PLL), Ch21/22(RAM/FIFO), Ch24(固化), Ch32(AD/DA教学) |
| 快速体验指南 | `D:\FPGA\Kintex7\Kintex7\1_Kintex7开发板出厂综合测试\【正点原子】Kintex7开发板用户快速体验V1.3.pdf` | 出厂测试、PCIe 驱动安装、常见问题 |
| 时序约束手册 | `D:\FPGA\Kintex7\Kintex7\2_文档教程\其他参考文档\【正点原子】FPGA静态时序分析与时序约束_V2.3.pdf` | create_clock、input/output delay、false path |
| IO 引脚分配表 | `D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7开发板IO引脚分配表.xlsx` | 引脚表格查询 |
| IO 约束参考 | `D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7_IO.xdc` | 快速查找引脚定义 |
| 底板原理图 | `D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7_BASE_1V3_2025_0111_USER.pdf` | 电气连接确认 |
| 核心板原理图 | `D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7_CORE_V1.0.pdf` | 核心板连接 |

### 2.3 芯片数据手册

根目录: `D:\FPGA\Kintex7\Kintex7\7_芯片数据手册`

| 类别 | 关键文档 |
|------|----------|
| FPGA 概述 | `01_FPGA\K7_Datasheet\ds175_Kintex-7 overview.pdf` |
| 配置与启动 | `01_FPGA\7_Series_user_guide\ug470_7Series_Config.pdf` |
| IO 电气特性 | `01_FPGA\7_Series_user_guide\ug471_7Series_SelectIO.pdf` |
| 引脚分配 | `01_FPGA\7_Series_user_guide\ug475_7Series_Pkg_Pinout.pdf` |
| 时钟资源 | `01_FPGA\7_Series_user_guide\ug472_7Series_Clocking.pdf` |
| BRAM/FIFO | `01_FPGA\7_Series_user_guide\ug473_7Series_Memory_Resources.pdf` |
| DSP48E1 | `01_FPGA\7_Series_user_guide\ug479_7Series_DSP48E1.pdf` |
| GTX 收发器 | `01_FPGA\7_Series_user_guide\ug476_7Series_Transceivers.pdf` |
| PCIe | `01_FPGA\7_Series_product_guide\pcie_7x\v3_3\pg054-7series-pcie.pdf` |
| DDR3 器件 | `03_DDR\NT5CC256M16ER.pdf` |
| QSPI Flash | `04_Flash\N25Q128A.pdf` |
| 教学 DAC | `06_ADDA芯片\3PD9708E.pdf` |

---

## 3. 当前项目状态

### 3.1 总体进度

```text
Phase 1: 基础验证
├── [✅] License 验证
├── [✅] LED 闪烁（1_led）
├── [✅] 寄存器示例（6_reg）
├── [✅] DDS Compiler IP 模块
│   ├── [✅] Vivado 工程创建
│   ├── [✅] IP 配置（48bit 相位 / 16bit 输出）
│   ├── [✅] Wrapper 封装模块
│   ├── [✅] 仿真验证（1MHz/2MHz/0Hz）
│   ├── [✅] 板级测试设计（LED 指示）
│   ├── [✅] Bitstream 生成
│   └── [⏳] 板子烧录验证（待用户执行）
├── [🔄] AWG core 前端（DDS + 波形选择 + 幅度/偏置）
│   ├── [✅] awg_core 统一模块已接入 `awg_dds_led_top`
│   ├── [✅] `tb_awg_core` 参考链路逐拍对拍通过
│   └── [⏳] 等板子接回电脑后做板级确认
├── [✅] 幅度/偏置/缩放模块
├── [✅] 教学 DAC 接口
├── [⬜] 扫频引擎
├── [⬜] BRAM 波形存储
└── [⬜] Phase 1 Demo

Phase 2: 完整系统
├── [⬜] DDR3 MIG 配置
├── [⬜] PCIe XDMA 接口
├── [🔄] 高速 DAC 数字接口（JESD204B + AD9144 FMC）
│   ├── [✅] Vendor Demo 源码提取（K7 demo）
│   ├── [✅] JESD204 TX IP 配置（v7.2, 4 lanes, 10Gbps, GTXE2）
│   ├── [✅] SPI 寄存器配置提取（AD9144 125 步 + LMK04828 138 步）
│   ├── [✅] K325T FMC HPC 引脚映射（Bank 117 GTX）
│   ├── [✅] XDC 约束编写（standalone bring-up 包）
│   ├── [✅] 顶层模块适配（vendor top + K325T FMC 端口）
│   ├── [✅] 综合 / 优化 / 布局 / 布线跑通
│   ├── [✅] Bitstream 生成（`top_direct.bit`）
│   └── [🔎] 板级 JESD 建链验证（AD9144 TX digital path active；AD9250 RX tvalid=0）
├── [⬜] 校准表
└── [⬜] 完整测量验证
```

### 3.2 活跃工程列表

| 工程 | 路径 | 状态 | 最后更新 |
|------|------|------|----------|
| **awg_k325t** (DDS) | `D:\awg_fpga` | 🔄 `awg_core` 前端已接入，仿真对拍通过 | 2026-05-06 |
| **ad9144_bringup_k325t** (JESD204 vendor demo) | `D:\FPGA\ad9144_bringup_k325t` | 🔎 `top_direct.bit` 已烧录；等待 15s 后 TX/RX ILA clock 可用；AD9144 TX 侧 QPLL/reset/tready/SYNC/SYSREF/data 正常，AD9250 RX `tvalid=0` | 2026-05-06 |
| **fpga_only_diag** | `D:\FPGA\fpga_only_diag` | ✅ K325T 本体/JTAG/板载 100MHz/ILA 验证通过 | 2026-05-06 |
| **awg_k325t** (JESD204 integration) | `D:\awg_fpga` | ⏸ 等 standalone 建链验证后再集成 | 2026-05-06 |
| **1_led** | `D:\k7\325\1_led` | ✅ 已验证 | 2026-05-02 |
| **6_reg** | `D:\FPGA\Kintex7\Kintex7\4_Source_Code\1_Verilog\6_reg` | ✅ 已验证 | 2026-05-01 |

---

## 4. 已完成模块详情

### 4.1 DDS Compiler IP 模块

**状态**: ✅ 仿真通过，Bitstream 已生成，待板级验证

#### 4.1.1 工程结构

```text
D:\awg_fpga
├── rtl/
│   ├── dds/
│   │   └── dds_compiler_wrapper.v      # DDS IP 封装（中文注释）
│   ├── top/
│   │   └── awg_dds_led_top.v           # 板级顶层（含 DAC 接口）
│   └── dac/
│       └── dac_edu_parallel_if.v       # 教学 DAC 接口
├── sim/
│   └── tb/
│       └── tb_dds_compiler.v           # 仿真测试平台（中文注释）
├── constraints/
│   └── awg_dds_led_top.xdc             # 引脚约束
└── vivado/
    └── awg_k325t.xpr                   # Vivado 2024.1 工程
```

#### 4.1.2 IP 配置参数

**DDS Compiler v6.0 配置**:

| 参数 | 值 | 说明 |
|------|-----|------|
| **Phase Width** | **48 bit** | IP 支持的最大相位宽度（范围 3-48） |
| **Output Width** | **16 bit** | 有符号正弦输出，范围 -32768 ~ +32767 |
| **Phase Increment** | Programmable | 通过 AXI-Stream 动态更新频率 |
| **Has Phase Out** | false | 仅输出正弦波，不输出相位 |
| **Noise Shaping** | None | 基本截断模式 |

**频率分辨率**:
- @ 5GSa/s: ~17.8 uHz（微赫兹），远优于 1mHz 要求
- @ 100MHz: ~0.356 uHz

#### 4.1.3 频率公式

**输出频率**:
```
f_out = phase_inc × f_clk / 2^48
```

**频率控制字**:
```
phase_inc = f_out × 2^48 / f_clk
```

**常用参数值**:

| 目标频率 | 时钟频率 | Phase Inc (hex) | Phase Inc (dec) |
|----------|----------|-----------------|-----------------|
| 1 MHz | 100 MHz | `48'h28f5c28f5c2` | 2,814,749,767,106 |
| 2 MHz | 100 MHz | `48'h51eb851eb84` | 5,629,499,534,212 |
| 1 Hz | 100 MHz | `48'h0000000002AF31` | 2,814,769 |
| 1 mHz | 100 MHz | `48'h0000000000000B` | 11 |

#### 4.1.4 RTL 模块详解

**Module 1: dds_compiler_wrapper.v**

路径: `D:\awg_fpga\rtl\dds\dds_compiler_wrapper.v`

功能：将 Xilinx DDS Compiler IP 的 AXI-Stream 接口简化为易用接口。

**接口定义**:

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| `clk` | input | 1 | DDS 工作时钟 |
| `rst_n` | input | 1 | 低电平有效复位 |
| `freq_load` | input | 1 | **脉冲**：加载新频率（一个时钟周期高电平） |
| `phase_inc` | input | 48 | 频率控制字（相位增量） |
| `sine_out` | output | 16 | 有符号正弦波输出 |
| `out_valid` | output | 1 | 输出数据有效标志 |

**关键逻辑**:
- `config_tvalid <= freq_load`：将外部脉冲转换为 AXI-Stream valid
- `sine_out = data_tdata[15:0]`：从 IP 的 32bit 输出中提取低 16bit 有效数据

**Module 2: awg_dds_led_top.v**

路径: `D:\awg_fpga\rtl\top\awg_dds_led_top.v`

功能：板级顶层模块，用于 K325T 开发板验证。

**时钟链**:
```
sys_clk_p/n (AE10/AF10, 差分 100MHz)
  → IBUFDS (差分转单端)
    → BUFG (全局时钟缓冲)
      → clk (全局时钟)
```

**LED 输出**:
- **LED[0] (R24)**: `sine_out[15]`（符号位）→ 1Hz 正弦波 → **2Hz 闪烁**
- **LED[1] (R23)**: `sine_out[14] ^ sine_out[15]` → 峰值指示

**板级频率**: ~1Hz（`PHASE_INC_1HZ = 48'h0000000002AF31`）

**Module 3: tb_dds_compiler.v**

路径: `D:\awg_fpga\sim\tb\tb_dds_compiler.v`

功能：仿真测试平台，验证 1MHz / 2MHz / 0Hz 三种频率输出。

**测试流程**:
```
t=0      : 复位
 t=100ns : 释放复位
 t=120ns : 加载 1MHz
 t=10.6μs: 观察 1MHz（10 周期）
 t=10.6μs: 加载 2MHz
 t=20.6μs: 观察 2MHz（20 周期）
 t=20.6μs: 加载 0Hz
 t=25.6μs: 观察 DC
 t=25.6μs: 仿真结束
```

#### 4.1.5 约束文件

路径: `D:\awg_fpga\constraints\awg_dds_led_top.xdc`

```tcl
# 差分 100MHz 时钟
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_p]
set_property PACKAGE_PIN AF10 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_n]

# 复位按键（低有效）
set_property PACKAGE_PIN AB25 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# LED 输出
set_property PACKAGE_PIN R24 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN R23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# 时钟约束
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

# LED 非时序关键路径
set_false_path -to [get_ports {led[*]}]
```

#### 4.1.6 仿真验证结果

**行为仿真状态**: ✅ **通过**

| 测试项 | 预期 | 实际 | 状态 |
|--------|------|------|------|
| 1MHz 输出 | 10 周期 / 10μs | 10 周期 / 10μs | ✅ |
| 2MHz 输出 | 20 周期 / 10μs | 20 周期 / 10μs | ✅ |
| 0Hz 输出 | 恒定 DC | 恒定 DC | ✅ |
| 波形质量 | 标准正弦波 | 无失真正弦波 | ✅ |

**波形文件路径**:
```text
D:\awg_fpga\vivado\awg_k325t.sim\sim_1\behav\xsim\tb_dds_compiler_behav.wdb
```

#### 4.1.7 Bitstream 生成状态

**综合结果**:
```text
Synthesis:      0 errors, 0 critical warnings
Implementation: Place/route/write_bitstream passed
Timing:         WNS = 7.6ns (meets 100MHz constraint)
```

**输出文件**:
```text
D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit
```

#### 4.1.8 板级测试预期

烧录 `.bit` 文件后：
1. **LED0 (R24)**: 以约 **2Hz** 频率闪烁（1Hz 正弦波的符号位）
2. **LED1 (R23)**: 在正弦波峰/谷处亮，过零点附近灭
3. **KEY0 (AB25)**: 按下复位，释放后重新开始

#### 4.1.9 重建指令

**完整重建**（修改 RTL 后）:
```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\rebuild_dds_from_synthesis.tcl
```

**仅仿真**:
```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\awg_fpga\run_simulation.tcl
```

#### 4.1.10 AWG core 前端

路径: `D:\awg_fpga\rtl\dsp\awg_core.v`

功能：把 `dds_nco`、`sine_lut`、`wave_shape_gen`、`sample_mux`、`amp_offset_scale` 串成统一的 AWG 前端，后续可以直接挂寄存器或按键控制。

当前状态：已接入 `D:\awg_fpga\rtl\top\awg_dds_led_top.v`，`D:\awg_fpga\sim\tb\tb_awg_core.v` 参考链路对拍通过。顶层当前先把 `phase_offset`、`wave_mode`、`amplitude`、`offset` 固定为常量，下一步是把它们改成可动态配置。

### 4.2 基础示例：1_led

路径: `D:\k7\325\1_led`

功能：最简单的 LED 闪烁示例，验证时钟和约束。

**关键文件**:
- RTL: `D:\k7\325\1_led\rtl\led.v`
- 约束: `D:\k7\325\1_led\prj\led.srcs\constrs_1\new\led.xdc`
- 工程: `D:\k7\325\1_led\prj\led.xpr`
- Bit: `D:\k7\325\1_led\prj\led.runs\impl_1\led.bit`

**引脚映射**:
```text
sys_clk_p -> AE10, DIFF_SSTL15_DCI
sys_clk_n -> AF10, DIFF_SSTL15_DCI
key       -> A26,  LVCMOS33
led       -> R24,  LVCMOS33
```

**教训**: 曾使用单端 `clk` 端口导致 `DRC NSTD-1` 和 `UCIO-1`，修复方案是使用差分时钟 `sys_clk_p/sys_clk_n`。

### 4.3 基础示例：6_reg

路径: `D:\FPGA\Kintex7\Kintex7\4_Source_Code\1_Verilog\6_reg`

功能：4 级移位寄存器，验证时序和按键。

**关键文件**:
- RTL: `D:\FPGA\Kintex7\Kintex7\4_Source_Code\1_Verilog\6_reg\rtl\shfit_reg.v`
- 约束: `D:\FPGA\Kintex7\Kintex7\4_Source_Code\1_Verilog\6_reg\prj\reg.xdc`
- Bit: `D:\FPGA\Kintex7\Kintex7\4_Source_Code\1_Verilog\6_reg\prj\reg.runs\impl_1\shfit_reg.bit`

**引脚映射**:
```text
sys_clk_p -> AE10, DIFF_SSTL15_DCI
sys_clk_n -> AF10, DIFF_SSTL15_DCI
sys_rst_n -> AB25, LVCMOS33
a         -> A26,  LVCMOS33 (KEY0)
b         -> A25,  LVCMOS33 (KEY1)
y         -> R24,  LVCMOS33 (LED0)
z         -> R23,  LVCMOS33 (LED1)
```

---

## 5. 技术规范

### 5.1 Verilog 编码规范

1. **注释**: 新文件使用 ASCII 注释，避免 GBK 中文乱码
2. **端口声明**: 显式声明 `input wire` / `output wire`
3. **复位**: 统一使用低电平有效异步复位（`rst_n`）
4. **时钟**: 单时钟域设计，跨时钟域使用 FIFO 或同步器
5. **命名**: 模块名小写 + 下划线，参数用 `localparam`

### 5.2 时钟处理规范（强制）

**K325T 差分时钟标准链**:
```verilog
// Step 1: 差分输入缓冲（必须）
IBUFDS clk_ibufds (
    .I  (sys_clk_p),   // 正端
    .IB (sys_clk_n),   // 负端
    .O  (clk_ibuf)     // 单端输出
);

// Step 2: 全局时钟缓冲（必须）
BUFG clk_bufg (
    .I (clk_ibuf),
    .O (clk)           // 全局时钟
);
```

**不允许**: 直接将差分信号接到逻辑，或省略 BUFG。

### 5.3 复位规范

```verilog
// 推荐：异步复位、同步释放（复位同步器）
reg [1:0] rst_sync;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rst_sync <= 2'b00;
    else
        rst_sync <= {rst_sync[0], 1'b1};
end
wire rst_synced = rst_sync[1];
```

**简化版**（demo 可用）: 直接透传 `rst_n`，但注意可能引入亚稳态。

### 5.4 XDC 约束规范

**必须包含**:
```tcl
# 1. 时钟引脚 + 电平标准
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15_DCI [get_ports sys_clk_p]

# 2. 时钟约束
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

# 3. 其他引脚 + 电平标准
set_property PACKAGE_PIN R24 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# 4. 非时序关键路径（可选）
set_false_path -to [get_ports {led[*]}]
```

**禁止**: 不要整文件包含 `K7_IO.xdc`，只复制需要的引脚。

---

## 6. 经验教训

### 6.1 Vivado 使用经验

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **License 报错** | `[Common 17-345] A valid license was not found` | 检查 `vlm.bat` 和 `C:\Users\17844\AppData\Roaming\XilinxLicense\trial.lic`，确保 license 未过期 |
| **JESD204 bitstream 被拒绝** | `[Common 17-69] bitstream generation is not permitted`，指向 `jesd204_tx` / `jesd204_rx` encrypted cell | 这不是 K325T 器件 license 问题；切换到包含 JESD204 bitstream 权限的官方 license 后，必须重新生成 IP output products 并重跑 bitstream |
| **路径敏感** | 工程打开失败或 IP 锁定 | 使用短 ASCII 路径，避免中文和空格 |
| **IP 锁定** | `IP is locked` | 右键 IP → **Upgrade IP** 或 **Reset Output Products** → **Generate** |
| **增量编译失效** | 修改后仍使用旧网表 | **Flow Navigator** → **Run Synthesis** → **Reset Runs** → 重新运行 |
| **Stale netlist** | `No ports matched 'xxx'` | 修改顶层端口后必须 **Reset Synthesis**，不能只重置 Implementation |
| **Vivado 版本不兼容** | 2024.2 的 JESD204 IP 无法用于 7 系列 | **必须使用 Vivado 2024.1 Enterprise Edition**（唯一同时支持 7 系列 + JESD204 的版本） |
| **Edition 不支持器件** | Standard Edition 提示 K325T 不在支持列表 | 安装 **Enterprise Edition**，Standard 不支持 Kintex-7 |
| **JESD204 IP 参数差异** | `C_LANE_RATE` 无效 | 使用 `GT_Line_Rate`；`C_PLL_SELECTION` 只能为 3；删除 `C_PLL_SELECTION` 使用默认值也可 |

### 6.2 IP 配置经验

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **64bit 相位不支持** | `Value '64' is out of the range (3,48)` | DDS Compiler v6.0 最大支持 **48bit**，使用 48bit 仍能满足 1mHz 分辨率要求 |
| **save_ip 不存在** | `invalid command name "save_ip"` | 使用 `save_project` 代替 |
| **参数依赖** | Phase_Width 无法手动设置 | 将 `Parameter_Entry` 从 `System_Parameters` 改为 `Hardware_Parameters` |
| **IP 删除残留** | 删除 IP 后工程报错 | 关闭工程 → 手动删除 IP 目录 → 重新打开工程 |
| **JESD204 版本选择** | 2018.3 的 IP 在 2024.1 中报错 | 使用 **JESD204 v7.2** + **jesd204_phy v4.0**，重新生成 IP |
| **JESD204 参数名变化** | `C_LANE_RATE` / `C_PLL_SELECTION` 等参数无效 | `GT_Line_Rate` 替代 `C_LANE_RATE`；`C_PLL_SELECTION` 仅支持 3 |
| **Transceiver 选择** | 默认 GTP 不适用 K325T | 显式设置 `CONFIG.Transceiver {GTXE2}` |

### 6.3 仿真经验

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **波形显示为柱状** | 看起来像方波 | 右键信号 → **Radix** → **Signed Decimal**；右键 → **Waveform Style** → **Analog** |
| **仿真后还是旧波形** | 修改代码但波形不变 | **Restart** 仿真（不是 Rerun），或关闭仿真重新打开 |
| **Behavioral vs Timing** | 时序仿真有毛刺 | 行为仿真足够验证功能，时序仿真用于检查时序违例 |
| **VCD 文件巨大** | 仿真时间长导致 VCD 很大 | 使用 `$dumpvars(1, tb_xxx)` 只记录顶层信号，或减少仿真时间 |

### 6.4 硬件调试经验

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **HW Target shutdown** | `[Labtoolstcl 44-513]` | 正常提示，**Hardware Manager** → **Open Target** → **Auto Connect** 重新连接 |
| **LED 不亮** | 烧录后无反应 | 1) 检查 bit 文件时间戳 2) 确认 DONE LED 亮 3) 检查约束文件引脚 4) 按 KEY0 复位 |
| **DRC NSTD-1** | `Unspecified I/O Standard` | 为所有顶层端口添加 `IOSTANDARD` 约束 |
| **DRC UCIO-1** | `Unconstrained Logical Port` | 为所有顶层端口添加 `PACKAGE_PIN` 约束 |
| **没有 debug core** | `Device has no supported debug core(s)` | 正常提示，表示设计中没有 ILA/VIO |

---

## 7. 常见问题 FAQ

### Q1: Vivado 提示 License 无效怎么办？

**A**: 
1. 检查 License 文件是否存在: `C:\Users\17844\AppData\Roaming\XilinxLicense\trial.lic`
2. 打开 Vivado License Manager: `D:\vivado\Vivado\2024.1\bin\vlm.bat`
3. 确认 License 包含 `Synthesis` 和 `xc7k325t`
4. 运行验证命令:
```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\check_k325t_synthesis.tcl
```
5. 看到 `K325T_SYNTHESIS_TEST_OK` 只代表 K325T 综合授权可用；JESD204 IP 是否可生成 bitstream 需要用 `ad9144_bringup_k325t\scripts\build_direct.tcl` 实测。

### Q2: 为什么 DDS 模块仿真通过但板子 LED 不闪烁？

**A**:
1. 确认烧录的是最新 `.bit` 文件（检查时间戳）
2. 确认 DONE LED（配置完成指示灯）亮起
3. 按下 KEY0 (AB25) 复位，观察是否变化
4. 检查约束文件引脚是否正确（AE10/AF10 时钟，AB25 复位，R24/R23 LED）
5. 确认 DDS 输出频率不是太快（1Hz 正弦波 → 2Hz LED 闪烁）

### Q3: Vivado 仿真波形显示异常（柱状/方波）？

**A**:
1. 右键波形信号 → **Radix** → **Signed Decimal**
2. 右键波形信号 → **Waveform Style** → **Analog**
3. 右键波形区域 → **Zoom Fit**（快捷键 **F**）
4. 如果仍异常，确认仿真时间足够长（建议 30μs）

### Q4: 修改 RTL 后仿真结果没变？

**A**:
1. 在 Vivado 仿真窗口点击 **Restart**（不是 Rerun）
2. 或者关闭仿真，重新 **Run Simulation**
3. 确认修改已保存（文件无星号标记）
4. 如果添加了新信号，需要重新运行仿真

### Q5: 如何查看综合后的 RTL 原理图？

**A**:
1. 完成综合: **Flow Navigator** → **SYNTHESIS** → **Run Synthesis**
2. 打开综合设计: **Open Synthesized Design** → **Schematic**
3. 可查看实际生成的 LUT、FF、DSP 等资源

### Q6: AD9144/JESD204 工程为什么综合布线通过但没有 bit 文件？

**A**:
1. 先看错误日志: `D:\FPGA\ad9144_bringup_k325t\vivado\build_direct_20260506.err.log`
2. 若出现 `[Common 17-69] bitstream generation is not permitted` 且列出 `jesd204_tx_inst/inst/i_jesd204_tx`、`jesd204_rx_inst/inst/i_jesd204_rx`，说明缺的是 JESD204 LogiCORE IP bitstream 权限。
3. 历史 `trial.lic` 只覆盖 K325T `Synthesis` / `Implementation`，不覆盖 JESD204 加密 IP 的 bitstream 生成；2026-05-06 已切换到 `Xlnx_2024.lic` 并实测生成 `top_direct.bit`。
4. 不要把该问题归因到 XDC、FMC 引脚、K325T 器件 license 或 `HW Target shutdown`。
5. 解法只有两类：取得官方 AMD/Xilinx JESD204 IP license，或替换为合法开源/自研 JESD204 实现。当前采用前者，已完成 bitstream 验收。

---

## 8. 操作指南

### 8.1 烧录板子步骤

```text
1. 确认 bit 文件存在且有最新时间戳
   D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit

2. Vivado 左侧: Flow Navigator → Open Hardware Manager

3. Hardware Manager 工具栏: Open Target → Auto Connect
   （如果提示 Target shutdown，重新 Auto Connect）

4. 确认设备出现: xc7k325t_0

5. 右键设备 → Program Device
   或工具栏点击 Program Device 图标

6. 选择 bit 文件路径，点击 Program

7. 观察板子: DONE LED 应亮起，然后 LED0/LED1 开始闪烁
```

### 8.2 新建模块开发流程

```text
1. 新建 RTL 文件（使用 ASCII 编码）
   D:\awg_fpga\rtl\<module_name>\<module_name>.v

2. 编写模块代码（参考技术规范）

3. 编写/更新 testbench
   D:\awg_fpga\sim\tb\tb_<module_name>.v

4. 添加文件到 Vivado 工程
   Sources → Add Sources → Add or create design sources

5. 运行行为仿真验证功能
   Flow Navigator → SIMULATION → Run Simulation → Run Behavioral Simulation

6. 验证通过后，添加到顶层模块

7. 更新约束文件（如有新引脚）

8. 运行综合 → 实现 → 生成 Bitstream

9. 烧录到板子验证
```

### 8.3 Vivado Tcl 常用命令

```tcl
# 打开工程
open_project D:/awg_fpga/vivado/awg_k325t.xpr

# 设置仿真顶层
set_property top tb_dds_compiler [get_filesets sim_1]

# 运行行为仿真
launch_simulation -mode behavioral

# 运行仿真时间
run 30us

# 保存波形配置
save_wave_config -object [current_wave_config] D:/awg_fpga/vivado/tb_dds_compiler_behav.wcfg

# 综合
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 实现
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 关闭工程
close_project
```

### 8.4 波形查看技巧

```text
1. Zoom Fit:          快捷键 F
2. Zoom In:           Ctrl + 滚轮向上
3. Zoom Out:          Ctrl + 滚轮向下
4. 添加信号:          左侧 Scope 面板拖拽
5. 信号分组:          右键 → New Group
6. 修改显示格式:      右键信号 → Radix
7. 模拟波形显示:      右键信号 → Waveform Style → Analog
8. 标记时间点:        点击波形上方时间轴
9. 测量时间差:        双击两个标记点
```

---

## 9. 外部资源

### 9.1 正点原子指南速查

| 需求 | 查看章节 |
|------|----------|
| 板子资源介绍 | Ch2/3 |
| LED 项目完整流程 | Ch5 |
| Verilog 编码基础 | Ch6 |
| 时序和仿真 | Ch16 |
| ILA 在线调试 | Ch18 |
| PLL 时钟生成 | Ch19 |
| RAM/FIFO IP | Ch21/22 |
| QSPI Flash 固化 | Ch24 |
| AD/DA 教学示例 | Ch32 |
| DDR3 MIG 配置 | Ch36+ |

### 9.2 引脚查询流程

```text
1. 快速查找: D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7_IO.xdc
   （搜索 KEY/LED/UART/系统时钟 等关键词）

2. 表格确认: D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7开发板IO引脚分配表.xlsx

3. 原理图验证: D:\FPGA\Kintex7\Kintex7\3_开发板原理图\K7_BASE_1V3_2025_0111_USER.pdf
   （确认电气连接和上拉/下拉）
```

### 9.3 常用引脚速查

| 信号名 | 引脚 | 电平标准 | 功能 |
|--------|------|----------|------|
| sys_clk_p | AE10 | DIFF_SSTL15_DCI | 100MHz 差分时钟正端 |
| sys_clk_n | AF10 | DIFF_SSTL15_DCI | 100MHz 差分时钟负端 |
| sys_rst_n | AB25 | LVCMOS33 | 复位按键 KEY0（低有效） |
| key[0] | A26 | LVCMOS33 | 按键 KEY0 |
| key[1] | A25 | LVCMOS33 | 按键 KEY1 |
| led[0] | R24 | LVCMOS33 | LED0 |
| led[1] | R23 | LVCMOS33 | LED1 |
| uart_rxd | T23 | LVCMOS33 | UART 接收 |
| uart_txd | T22 | LVCMOS33 | UART 发送 |

---

## 9.4 K325T 核心板 GT Bank 引脚（FFG900）

> 来源：核心板原理图 `K7_CORE_V1.0.pdf` 第 8 页（BANK_MGT）

**Bank 115**:
| 信号 | 引脚 | 信号 | 引脚 |
|:---|:---|:---|:---|
| TX0_P | Y2 | RX0_P | AA4 |
| TX0_N | Y1 | RX0_N | AA3 |
| TX1_P | V2 | RX1_P | Y6 |
| TX1_N | V1 | RX1_N | Y5 |
| TX2_P | U4 | RX2_P | W4 |
| TX2_N | U3 | RX2_N | W3 |
| TX3_P | T2 | RX3_P | V6 |
| TX3_N | T1 | RX3_N | V5 |
| CLK0_P | R8 | CLK1_P | U8 |
| CLK0_N | R7 | CLK1_N | U7 |

**Bank 116**:
| 信号 | 引脚 | 信号 | 引脚 |
|:---|:---|:---|:---|
| TX0_P | P2 | RX0_P | T6 |
| TX0_N | P1 | RX0_N | T5 |
| TX1_P | N4 | RX1_P | R4 |
| TX1_N | N3 | RX1_N | R3 |
| TX2_P | M2 | RX2_P | P6 |
| TX2_N | M1 | RX2_N | P5 |
| TX3_P | L4 | RX3_P | M6 |
| TX3_N | L3 | RX3_N | M5 |
| CLK0_P | L8 | CLK1_P | N8 |
| CLK0_N | L7 | CLK1_N | N7 |

**Bank 117**:
| 信号 | 引脚 | 信号 | 引脚 |
|:---|:---|:---|:---|
| TX0_P | K2 | RX0_P | K6 |
| TX0_N | K1 | RX0_N | K5 |
| TX1_P | J4 | RX1_P | H6 |
| TX1_N | J3 | RX1_N | H5 |
| TX2_P | H2 | RX2_P | G4 |
| TX2_N | H1 | RX2_N | G3 |
| TX3_P | F2 | RX3_P | F6 |
| TX3_N | F1 | RX3_N | F5 |
| CLK0_P | G8 | CLK1_P | J8 |
| CLK0_N | G7 | CLK1_N | J7 |

**Bank 118**:
| 信号 | 引脚 | 信号 | 引脚 |
|:---|:---|:---|:---|
| TX0_P | D2 | RX0_P | E4 |
| TX0_N | D1 | RX0_N | E3 |
| TX1_P | C3 | RX1_P | D6 |
| TX1_N | C4 | RX1_N | D5 |
| TX2_P | B2 | RX2_P | B6 |
| TX2_N | B1 | RX2_N | B5 |
| TX3_P | A4 | RX3_P | A8 |
| TX3_N | A3 | RX3_N | A7 |
| CLK0_P | C8 | CLK1_P | E8 |
| CLK0_N | C7 | CLK1_N | E7 |

> 注意：SFP 10G 示例使用 Bank 118（`q0_ck1_p_in=C8`, `rxp_in=D6`, `txp_out=C4`）。
> FMC HPC 高速信号连接到 **Bank 117**。

---

## 9.5 FMC HPC 引脚速查（FMCADDA-9250-9144 子卡）

> 来源：底板原理图 `K7_BASE_1V3_2025_0111_USER.pdf` 第 15 页（J34A/J34B/J34E）
> 子卡型号：FMCADDA-9250-9144（AD9250 250Msps ADC + AD9144 2.8Gsps DAC）
> **所有高速信号均连接至 Bank 117（GTXE2）**

### 高速差分对（Bank 117 GTX）

| 信号 | FPGA 引脚 | Bank117 | 方向 | 说明 |
|:---|:---|:---|:---|:---|
| DP0_C2M_P/N | H2 / H1 | TX2 | TX | DAC lane 0（JESD204 TX） |
| DP1_C2M_P/N | F2 / F1 | TX3 | TX | DAC lane 1（JESD204 TX） |
| DP2_C2M_P/N | J4 / J3 | TX1 | TX | DAC lane 2（JESD204 TX） |
| DP3_C2M_P/N | K2 / K1 | TX0 | TX | DAC lane 3（JESD204 TX） |
| DP0_M2C_P/N | G4 / G3 | RX2 | RX | ADC lane 0（JESD204 RX） |
| DP1_M2C_P/N | F6 / F5 | RX3 | RX | ADC lane 1（JESD204 RX） |
| GBTCLK0_M2C_P/N | G8 / G7 | CLK0 | RX | GTX RefClk 125M（LMK OUT0） |
| GBTCLK1_M2C_P/N | J8 / J7 | CLK1 | RX | 备用 RefClk |

### 低速信号（LA + CLK）—— 从底板原理图人工提取

> 提取方式：`K7_BASE_1V3_2025_0111_USER.pdf` 第 15 页局部放大截图人工辨认 + 高亮信号确认

| 信号 | FPGA 引脚 | 状态 | 说明 |
|:---|:---|:---|:---|
| LA00_CC_P/N | **D17 / D18** | ✅ 截图确认 | **glblclk (125M)** |
| LA03_P/N | **G11 / ?** | ⚠️ N端待确认 | 通用 |
| LA01_CC_P/N | **F21 / E21** | ✅ | ADC SPI SCLK / CSN |
| LA02_P/N | **K18 / J18** | ✅ | ADC SPI SDIO |
| LA03_P/N | **G11 / ?** | ⚠️ N端待确认 | 通用 |
| LA04_P/N | **D16 / C16** | ✅ | DAC TXEN0 / TXEN1 |
| LA05_P/N | **E19 / D19** | ✅ | **DAC SYNC0** |
| LA06_P/N | **B18 / A18** | ✅ | **DAC SPI SDIO / SDO** |
| LA07_P/N | **G17 / F17** | ✅ | 通用 |
| LA08_P/N | **B22 / A22** | ✅ | 通用 |
| LA09_P/N | **D21 / C21** | ✅ | DAC SYNC1 |
| LA10_P/N | **B19 / ?** | ⚠️ N端待确认 | **DAC SPI SCLK / CSN** |
| LA11_P/N | **C20 / B20** | ✅ | 通用 |
| LA12_P/N | **L17 / L18** | ✅ | 通用 |
| LA13_P/N | **D18 / D19** | ✅ 截图确认 | ADC SYNC |
| LA14_P/N | **G18 / F18** | ✅ 截图确认 | **DAC RSTN / IRQN** |
| LA15_P/N | **A20 / A21** | ✅ | 通用 |
| LA16_P/N | **A16 / A17** | ✅ | 通用 |
| LA17_CC_P/N | **H14 / G14** | ✅ 截图确认 | 通用 |
| LA18_CC_P/N | **D12 / D13** | ✅ 截图确认 | 通用 |
| LA19_P/N | **A14 / E15** | ⚠️ | 通用 |
| LA20_P/N | **D14 / C14** | ✅ | **FPGA SYSREF** |
| LA21_P/N | **A11 / A12** | ✅ | 通用 |
| LA22_P/N | **C15 / B15** | ✅ | 通用 |
| LA23_P/N | **B14 / A15** | ✅ | 通用 |
| LA24_P/N | **H11 / H12** | ✅ | TRIG / SYSREF |
| LA25_P/N | **D11 / C11** | ✅ | 通用 |
| LA26_P/N | **? / ?** | ⬜ | 通用 |
| LA27_P/N | **B13 / A13** | ✅ | 通用 |
| LA28_P/N | **J11 / J12** | ✅ | **LMK SPI SDIO / CSB** |
| LA29_P/N | **F15 / E16** | ✅ | **LMK SPI SCLK / RST** |
| LA30_P/N | **F11 / E11** | ⚠️ | 通用 |
| LA31_P/N | **L11 / K11** | ✅ | 通用 |
| LA32_P/N | **? / ?** | ⬜ | 通用 |
| LA33_P/N | **J16 / H16** | ✅ | 通用 |
| CLK0_M2C_P/N | **F20 / E20** | ✅ | ADC RSTN / FDB 或备用时钟 |
| CLK1_M2C_P/N | **G13 / F13** | ✅ | 通用时钟 |
| IIC_SCL | **AD29** | ✅ | EEPROM SCL |
| IIC_SDA | **AE29** | ✅ | EEPROM SDA |
| PRSNT_M2C_L | **AF30** | ✅ | FMC 在位检测 |

---

## 10. Git 版本控制

### 10.1 仓库信息

- **GitHub 仓库**: `https://github.com/CYberkra/Electronics-Competition.git`
- **本地路径**: `D:\awg_fpga`
- **初始化日期**: 2026-05-05
- **主分支**: `main`

### 10.2 已提交内容

首次提交包含 38 个文件：
- RTL 源码：`rtl/top/`、`rtl/dds/`、`rtl/dac/`、`rtl/dsp/`
- 约束文件：`constraints/awg_dac_edu.xdc`、`constraints/awg_dds_led_top.xdc`
- 仿真平台：`sim/tb/`、`sim/work/`（脚本和 testbench）
- Vivado 项目：`vivado/awg_k325t.xpr` + DDS IP 配置 `.xci`
- 编译脚本：TCL / Python / PowerShell
- `.gitignore`（已配置 Vivado 生成文件排除规则）

### 10.3 提交规范

后续开发时，在 `D:\awg_fpga` 目录执行：

```powershell
git add .
git commit -m "feat: 做了什么改动"
git push
```

### 10.4 .gitignore 策略

已排除的内容：
- Vivado 生成文件（`*.cache/`、`*.runs/`、`*.sim/`、`.Xil/`、`*.bit`、`*.bin`）
- 仿真输出（`*.vcd`、`xsim.dir/`）
- 构建日志（`build_*.log`）
- Python 缓存

**必须保留的内容**：
- RTL 源文件（`.v`）
- 约束文件（`.xdc`）
- IP 核配置（`.xci`）
- Vivado 项目文件（`.xpr`）
- 脚本和文档

---

## 11. AD9144/JESD204 Bring-Up

> **当前状态（2026-05-06）**
>
> 已切换到可用 license，standalone 工程完成 `synth_design`、`opt_design`、`place_design`、`route_design`、`write_bitstream`，并生成 `D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit`。下一步不是继续查 license，而是烧录板子并用 Hardware Manager 的 ILA/VIO 检查 JESD 建链状态。

### Standalone bring-up package

Use this package before touching the AWG repo integration:

```text
D:\FPGA\ad9144_bringup_k325t
```

Important files:

```text
D:\FPGA\ad9144_bringup_k325t\constraints\top_k325t_fmc.xdc
D:\FPGA\ad9144_bringup_k325t\scripts\create_project.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\build_bitstream.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\synth_direct.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\build_direct.tcl
D:\FPGA\ad9144_bringup_k325t\docs\hardware_checklist.md
D:\FPGA\ad9144_bringup_k325t\ip_data\sine.coe
```

The package uses the full vendor demo source from:

```text
D:\FPGA\FMCADDA-9250-9144\extracted_k7_full\fmcadda_9250_9144_demo_dac4L_k7\fmcadda_9250_9144.srcs
```

Do not use the vendor `top.xdc` directly. It targets a different board/GT bank.

### Corrected K325T FMC low-speed mapping

Verified against `D:\FPGA\page15_fmc_4x.png` from K7 base schematic sheet 15:

| FMC signal | K325T FPGA pins | Use in vendor `top.v` |
|---|---|---|
| LA00_CC_P/N | D17 / D18 | `glblclk_p/n` |
| LA05_P/N | E19 / D19 | `i_tx_sync_p/n` for DAC SYNC0 |
| LA10_P/N | C19 / B19 | `das_sclk` / `das_sen_n` |
| LA13_P/N | D22 / C22 | `o_rx_sync_p/n` for ADC SYNC |
| LA14_P/N | G18 / F18 | DAC IRQN / `das_rstn` |
| LA28_P/N | J11 / J12 | `lmk_cs_n` / `lmk_sda` |
| LA29_P/N | F15 / E16 | `lmk_rst` / `lmk_sclk` |
| LA20_P/N | D14 / C14 | `sysref_p/n` |

This corrects two older risky notes:

- `LA13_P/N` is **D22/C22**, not D18/D19.
- `LA10_P/N` is **C19/B19**, not B19/unknown.
- LMK04828 SPI should use LA28/LA29, not the FMC IIC pins AD29/AE29.

### Current build status

Verified command:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\create_project.tcl
```

Result:

```text
PROJECT_CREATED=D:/FPGA/ad9144_bringup_k325t/vivado/ad9144_bringup_k325t.xpr
```

Vivado can import the vendor sources and IP. The 2018.3 IPs are locked initially and must be upgraded in 2024.1.

Bitstream exists at:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit
```

Resolved blockers / notes from Codex batch runs:

1. `launch_runs` uses generated `runme.bat -> cscript -> rundef.js`; in the current Codex shell this prints `CScript Error: Loading your settings failed. (Access is denied.)` before any `runme.log` is created. This is a local Windows Script Host/run-infrastructure issue, not an RTL error.
2. `synth_direct.tcl` bypasses `launch_runs` and reaches `synth_design`.
3. The historical trial license at `C:\Users\17844\AppData\Roaming\XilinxLicense\trial.lic` was verified on 2026-05-06 for K325T `Synthesis` and `Implementation`, but it did **not** include JESD204 encrypted-IP bitstream generation rights.
4. The currently active license file is `C:\Users\17844\AppData\Roaming\XilinxLicense\Xlnx_2024.lic`. Fresh batch verification generated the JESD204 design bitstream.

K325T license verification command:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\check_k325t_synthesis.tcl
```

Expected marker:

```text
K325T_SYNTHESIS_TEST_OK
```

Prefer the direct build if `launch_runs` still hits CScript:

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\build_direct.tcl
```

2026-05-06 direct build result:

- `synth_design`: passed, `0 Errors`, `0 Critical Warnings`.
- `opt_design`: passed.
- `place_design`: passed.
- `route_design`: passed; routed nets verification passed with `Number of Failed Nets = 0`.
- Final timing is not clean yet: `WNS = -3.207 ns`, `TNS = -232.567 ns`, mainly reset/debug/clock-domain paths. This must be cleaned before final hardware confidence, but it did not block bitstream generation.
- `write_bitstream`: passed after switching license.
- Bitstream output:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit
Length: 2966686 bytes
LastWriteTime: 2026-05-06 09:55:42
```

Build log:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\build_direct_license_accept_20260506.log
```

Historical note: if `[Common 17-69] bitstream generation is not permitted` reappears and points to `jesd204_tx` / `jesd204_rx`, Vivado is no longer picking up the working license or stale IP output products were reused.

### What to do after bitstream generation

1. Program the generated bitstream:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit
```

2. Do not immediately assume analog output is correct. First open Hardware Manager and inspect ILA/VIO link status.
3. Minimum ILA checks before using the oscilloscope:
   - QPLL lock = 1
   - TX reset done = 1
   - TX `tready` = 1
   - AD9144 SYNC status is stable
   - SYSREF activity is visible
   - TX sample data changes rather than staying flat

### 2026-05-06 board-level digital-link check

Fresh Hardware Manager batch scripts:

```text
D:\FPGA\ad9144_bringup_k325t\scripts\verify_hw_link.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\write_debug_probes_from_synth.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\probe_ila_clocks.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\report_vio_state.tcl
```

Generated probes file:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct_from_synth.ltx
```

Observed hardware status:

- JTAG target opens: `localhost:3121/xilinx_tcf/Digilent/210512180081`.
- Device found: `xc7k325t_0`.
- Programming `top_direct.bit` succeeds; startup status is `HIGH`.
- Vivado reports `3 ILA core(s)` and `1 VIO core(s)`.
- `.ltx` binding works; probe names are visible.
- VIO defaults are not holding JESD in reset:
  - `w_jesd_tx_sys_reset_vio = 0`
  - `w_jesd_rx_sys_reset_vio = 0`
  - `w_rx_axi_ena = 1`
- `hw_ila_1` arms successfully, so debug hub / JTAG / base logic are alive.
- `hw_ila_2` (RX, clocked by `w_rx_core_clk`) fails with `Ila core [hw_ila_2] clock has stopped`.
- `hw_ila_3` (TX, clocked by `w_tx_core_clk`) fails with `Ila core [hw_ila_3] clock has stopped`.

Interpretation: the FPGA is programmed correctly and the debug cores are present, but the JESD core clocks are not running. In `top.v`, `w_rx_core_clk` and `w_tx_core_clk` come from `clk_for_glbclk`, whose input is FMC `glblclk_p/n`. That clock should be supplied by the FMCADDA/LMK path. Next checks are physical/FMC side first:

1. Confirm the FMCADDA-9250-9144 card is actually installed on the K325T FMC HPC connector and fully seated.
2. Confirm the daughter-card power/PLL LED state after programming. The quick checklist expects LMK04828 PLL LED green.
3. If the card is installed, re-check the K325T FMC low-speed mapping for LMK SPI and `glblclk_p/n`, because LMK may not be configured or its clock may not reach FPGA.
4. Only after `hw_ila_2` / `hw_ila_3` can arm should the agent judge `QPLL lock`, `TX reset done`, `TX tready`, `SYNC`, `SYSREF`, and sample data.

### 2026-05-06 FPGA-only diagnostic

Purpose: exclude the daughter card and verify the K325T board itself before continuing AD9144 debugging.

Diagnostic files:

```text
D:\FPGA\fpga_only_diag\rtl\fpga_only_diag_top.v
D:\FPGA\fpga_only_diag\constraints\fpga_only_diag.xdc
D:\FPGA\fpga_only_diag\scripts\build_fpga_only_diag.tcl
D:\FPGA\fpga_only_diag\scripts\verify_fpga_only_diag.tcl
D:\FPGA\fpga_only_diag\vivado\fpga_only_diag.bit
D:\FPGA\fpga_only_diag\vivado\fpga_only_diag.ltx
D:\FPGA\fpga_only_diag\vivado\hw_verify_20260506\fpga_only_counter.csv
```

What it tests:

- K325T JTAG detection: `xc7k325t_0`.
- Bitstream download: startup status `HIGH`.
- Board differential clock input: `sys_clk_p/n = AE10/AF10`.
- Debug hub and ILA visibility over JTAG.
- A 25-bit captured counter increments by 1 each sample.

Important constraint note: the initial diagnostic used `DIFF_SSTL15_DCI` for `sys_clk_p/n`, matching `K7_IO.xdc`, but Hardware Manager could not detect the debug hub. Rebuilding with the same standard used by many 正点原子 examples, `DIFF_SSTL15`, fixed the FPGA-only ILA path. Keep future simple board-clock diagnostics aligned with the example style unless there is a measured reason to use DCI.

Verification result:

```text
BSCAN_SWITCH_USER_MASK=0001
PROGRAM_DONE
ILA_COUNT=1
CURRENT_ILA=hw_ila_1
RUN_STATUS=0
WAIT_STATUS=0
UPLOAD_STATUS=0
WRITE_STATUS=0
```

Captured counter evidence:

```text
counter_reg_n_0_[24:0]
1488406
1488407
1488408
1488409
...
```

Conclusion: K325T FPGA body, JTAG download/debug path, board 100 MHz differential clock path, and basic fabric logic are good. The AD9144 issue should now be treated as FMCADDA daughter-card / LMK04828 / `glblclk_p/n` / low-speed SPI mapping bring-up, not as a base FPGA failure.

### 2026-05-06 FMC installed re-test

After the FMCADDA-9250-9144 daughter card was installed and powered, a fresh board-level run showed the previous `clock has stopped` result was partly caused by testing too soon after programming.

Important reset timing:

- Vendor `rst_module.v` clocks its reset delay with `clk_25m`.
- `o_mod1_rstn` / `w_rst_n` stays low for `100000000` cycles, about 4 seconds.
- Hardware scripts must wait at least 8 seconds after `program_hw_devices`; 12-15 seconds is the current safe wait before judging JESD ILA clocks.

New helper scripts:

```text
D:\FPGA\ad9144_bringup_k325t\scripts\build_cfg_debug_direct.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\capture_cfg_debug_ila.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\probe_ila_clocks_wait.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\capture_jesd_ila_wait.tcl
```

Generated diagnostic bit/probes:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_cfg_debug.bit
D:\FPGA\ad9144_bringup_k325t\vivado\top_cfg_debug.ltx
```

Config-domain evidence after 12s wait:

```text
w_rst_n = 1
lmk_datain_ready = 1
ads_datain_ready = 1
das_rstn_OBUF = 1
lmk_sclk_OBUF = 0/1 observed
ads_sclk_OBUF = 0/1 observed
das_sclk_OBUF = 0/1 observed
```

JESD ILA clock evidence after 15s wait:

```text
hw_ila_1 run/wait = 0
hw_ila_2 run/wait = 0
hw_ila_3 run/wait = 0
```

Captured JESD CSV files:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\jesd_capture_20260506\tx_ila.csv
D:\FPGA\ad9144_bringup_k325t\vivado\jesd_capture_20260506\rx_ila.csv
```

AD9144 TX-side evidence from `tx_ila.csv`:

```text
w_common0_qpll_lock_out = 1
w_tx_reset_done = 1
w_tx_tready = 1
w_tx_sync = 1
w_sysref = 0/1 observed
w_tx_tdata_1[63:0] changes across samples
w_tx_tdata[127:64] changes across samples
r_dds_addra_num0 changes: 00, 14, 28, 3c, 50
```

Interpretation: the FPGA-to-AD9144 JESD TX digital side is now active enough to proceed to analog/output checks on the DAC path. This does not yet prove the analog DAC output amplitude/frequency is correct; it proves the FPGA TX core clock, QPLL, reset, tready, SYSREF observation, and payload generation are alive.

Current vendor-ROM analog output expectation:

- This is still the vendor demo waveform path, not the final AWG DDS/control path.
- Waveform source is `D:\FPGA\ad9144_bringup_k325t\ip_data\sine.coe`.
- Vendor comments indicate AD9144 DAC sample rate is 2.0GSPS with 2x interpolation, so the FPGA/baseband sample rate is 1.0GSPS.
- Captured `r_dds_addra_num0` steps through `00, 14, 28, 3c, 50...`; combined with the 20-sample sine ROM pattern, the first oscilloscope target should be about **50MHz**.
- Probe **OUT1** first with a 50 ohm load/termination. If it is flat, try the other DAC outputs before changing RTL, because the vendor demo channel/output mapping may not match the panel label you expect.
- Wait **12-15s after programming** before judging either ILA or analog output; the vendor reset/config sequence is not immediate.

AD9250 RX-side evidence from `rx_ila.csv`:

```text
w_rx_reset_done = 1
w_rx_tvalid = 0
w_rx_sync = 0
w_sysref_1 = 0/1 observed
w_rx_frame_error[7:0] = 00
w_rx_tdata[63:0] = 0000000000000000
```

Interpretation: the ADC/RX chain is not producing valid samples yet. Do not treat this as blocking the short-term goal of seeing an AD9144 DAC output waveform; handle RX separately after DAC output is observed.

### Timing cleanup reminder

The 2026-05-06 routed timing report is:

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct_timing_routed.rpt
```

Current result:

```text
WNS = -3.207 ns
TNS = -232.567 ns
Timing constraints are not met
```

The worst paths are mostly reset/debug/cross-clock-domain paths, including `rst_module_inst` fanout into JESD data/trigger logic and ILA probe paths. Treat this as a timing-constraint/CDC cleanup task after first board-level JESD link observation. It did not block `write_bitstream`.

### Vendor ROM waveform note

The vendor `blk_mem_gen_0` needs `sine.coe`. The original 2018.3 IP recorded legacy paths and disables ROM initialization if the COE file is missing. The bring-up script keeps the COE at:

```text
D:\FPGA\ad9144_bringup_k325t\ip_data\sine.coe
```

and copies it to:

```text
D:\FPGA\sine.coe
D:\FPGA\FMCADDA-9250-9144\sine.coe
```

If this is missing, the AD9144 path may link but output a flat waveform.

---

## 12. 文档维护记录

| 日期 | 更新内容 | 维护者 |
|------|----------|--------|
| 2026-05-01 | 初始版本：License 验证、1_led、6_reg 示例 | Sisyphus |
| 2026-05-02 | 添加 DDS Compiler IP 模块简要记录 | Sisyphus |
| 2026-05-05 | **全面重构**：添加 10 个章节结构、完整 DDS 文档、技术规范、经验教训、FAQ、操作指南 | Sisyphus |
| 2026-05-05 | 添加 FMC ADDA (AD9144+AD9250) 引脚映射、子卡规格、JESD204B 配置参数 | Sisyphus |
| 2026-05-06 | **修正 Vivado 版本为 2024.1**；添加核心板 GT Bank 引脚表（Bank115~118）；完善 FMC HPC 映射标注 Bank117；添加 JESD204 IP 配置和建链流程章节；添加版本兼容性经验教训 | Sisyphus |
| 2026-05-06 | **人工提取 FMC HPC 低速引脚**：通过底板原理图第 15 页局部放大截图，确认 LA13(D18/D19)、LA14(G18/F18)、LA17_CC(H14/G14)、LA18_CC(D12/D13)；修正 LA10_P=B19；更新引脚状态标记 | Sisyphus |
| 2026-05-06 | **记录 AD9144/JESD204 standalone build 结果**：综合/布局/布线通过，`write_bitstream` 被 JESD204 加密 IP license 阻塞；补充错误日志路径、重跑命令、license 边界、后续 ILA 检查步骤 | Codex |
| 2026-05-06 | **验收可用 license**：`Xlnx_2024.lic` 被 Vivado 2024.1 识别，AD9144/JESD204 standalone direct build 完成 `write_bitstream`，生成 `top_direct.bit`；更新下一步为板级烧录和 ILA/VIO 建链检查 | Codex |
| 2026-05-06 | **完成 FPGA-only 排除法验证**：创建 `fpga_only_diag` 最小设计并实测通过，证明 K325T 本体、JTAG、板载 100MHz、debug hub/ILA 正常；AD9144 当前问题收敛到 FMCADDA/LMK/glblclk 路径 | Codex |
| 2026-05-06 | **FMC 子卡复测与 JESD TX 验证**：发现 vendor reset 延时约 4s，硬件脚本需等待 12-15s；等待后 TX/RX ILA clock 可用，AD9144 TX 侧 QPLL/reset/tready/SYNC/SYSREF/data 正常，AD9250 RX `tvalid=0` 待后续单独处理 | Codex |
| 2026-05-06 | **补充示波器首测预期**：当前 vendor ROM 路径预期 DAC 输出约 50MHz，先测 OUT1，若为平线再换 OUT2-OUT4；判断前需等待 12-15s 完成复位/配置 | Codex |
| 2026-05-06 | **开始 AWG core 前端**：新增 `rtl/dsp/awg_core.v`，把 DDS / 波形选择 / 幅度 / 偏置串成统一前端；`tb_awg_core` 已对拍通过，并已接入 `awg_dds_led_top.v` | Codex |

### 下次更新建议

- [x] 拿到可用 JESD204 LogiCORE license 后，记录 license 文件名、加载方式和状态
- [x] 重新生成 IP output products 并记录 `top_direct.bit` 是否生成
- [ ] 清理 routed timing 中 reset/debug/CDC 路径，更新 WNS/TNS
- [ ] 添加 AD9144 顶层适配模块文档
- [ ] 添加扫频引擎模块文档
- [ ] 把 AWG core 前端的寄存器/按键控制补齐
- [ ] 添加 DDR3 MIG 配置记录
- [ ] 添加 PCIe XDMA 接口文档
- [ ] 更新板级验证结果（LED 闪烁实测 / JESD 建链实测 / 示波器波形）

---

> **End of Document**
>
> 本文档为 Agent 协作知识库，由 Sisyphus/Codex 维护。
> 如有疑问或需要更新，请在会话中提及。


## 13. Current AWG status addendum (2026-05-06)

- Active board demo chain:
  `sys_clk_p/n -> IBUFDS/BUFG -> awg_key_ui_ctrl -> awg_core -> dac_edu_parallel_if -> da_clk/da_data[7:0]`
- Current validated files:
  - `D:\awg_fpga\rtl\control\awg_key_ui_ctrl.v`
  - `D:\awg_fpga\rtl\dsp\awg_core.v`
  - `D:\awg_fpga\rtl\top\awg_dds_led_top.v`
  - `D:\awg_fpga\constraints\awg_dds_led_top.xdc`
- Teaching DAC pins were merged into the main top XDC, so `da_clk` and `da_data[7:0]` are no longer unconstrained.
- Fresh verification:
  - `run_awg_key_ui_ctrl_sim.ps1` -> PASS
  - `run_awg_core_sim.ps1` -> PASS
  - `rebuild_awg_base.tcl` -> PASS, bitstream generated at `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit`
- Next board step: reconnect the board, program the bitstream in Hardware Manager, and observe KEY0/KEY1 control plus DAC output.

## 14. AWG debug observability addendum (2026-05-06)

- Added visible front-panel feedback in `D:\awg_fpga\rtl\control\awg_led_status.v`.
  - Normal mode returns to waveform LEDs: `led[0]=awg_sample[15]`, `led[1]=awg_sample[14]^awg_sample[15]`.
  - After a control change, LEDs show the active edit group for about 1 second:
    - frequency: `01`
    - waveform: `10`
    - amplitude: `11`
    - offset: both LEDs blink
- `D:\awg_fpga\rtl\dsp\amp_offset_scale.v` now registers the multiply result and offset before saturation.
  - This adds one AWG sample clock of latency.
  - It fixed the 100 MHz setup path from `wave_sel` through the DSP/saturator.
- Conditional ILA support is inside `D:\awg_fpga\rtl\top\awg_dds_led_top.v` under `AWG_DEBUG_ILA`.
  - probe0 `key0`
  - probe1 `key1`
  - probe2 `rst_n`
  - probe3 `ui_mode[1:0]`
  - probe4 `wave_mode[2:0]`
  - probe5 `freq_load`
  - probe6 `phase_inc[47:0]`
  - probe7 `amplitude[15:0]`
  - probe8 `offset[15:0]`
  - probe9 `awg_sample[15:0]`
  - probe10 `sample_valid`
  - probe11 `da_data[7:0]`
  - probe12 `led[1:0]`
- Build commands:
  - Normal bit: `D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\awg_fpga\scripts\rebuild_awg_base.tcl`
  - Debug bit/ltx: `D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\awg_fpga\scripts\rebuild_awg_debug.tcl`
  - Hardware program/capture: `D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\awg_fpga\scripts\program_and_capture_awg_debug.tcl`
- Output files:
  - Normal bit: `D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit`
  - Stable debug bit: `D:\awg_fpga\artifacts\debug\awg_dds_led_top_debug.bit`
  - Stable debug probes: `D:\awg_fpga\artifacts\debug\awg_dds_led_top_debug.ltx`
  - ILA CSV output directory: `D:\awg_fpga\measurements\ila\capture_YYYYMMDD_HHMMSS`
- Important workflow detail: `rebuild_awg_debug.tcl` uses the main `impl_1` run, so it temporarily writes a debug `awg_dds_led_top.bit`. It also copies the debug bit/ltx to `D:\awg_fpga\artifacts\debug\`. Run `rebuild_awg_base.tcl` afterward when the normal non-debug bit should be restored.
- Fresh verification from 2026-05-06:
  - `D:\awg_fpga\sim\work\run_awg_led_status_sim.ps1` -> PASS
  - `D:\awg_fpga\sim\work\run_awg_key_ui_ctrl_sim.ps1` -> PASS
  - `D:\awg_fpga\sim\work\run_awg_core_sim.ps1` -> PASS
  - Normal bitstream rebuilt after debug restore: WNS `2.087ns`, hold slack `0.107ns`, 0 failing endpoints.
  - Debug build script completed and copied debug bit/ltx; debug routed timing was WNS about `1.655ns`, 0 failing endpoints.
- Board-side capture status:
  - Computer detects the Digilent USB cable: `USB Serial Converter`, `VID_0403&PID_6014`, serial `210512180081`.
  - Initial `open_hw_target` failure was caused by board power being off. After power was restored, Vivado detected `xc7k325t_0`.
  - Debug bit programming succeeded with startup status `HIGH`.
  - `program_and_capture_awg_debug.tcl` must set `BSCAN_SWITCH_USER_MASK=1`; otherwise Hardware Manager may not find `dbg_hub` on user scan chain 1.
  - Successful ILA capture: `D:\awg_fpga\measurements\ila\capture_20260506_181837\hw_ila_1.csv`.
  - Captured CSV includes `key0/key1/rst_n/ui_mode/wave_mode/freq_load/phase_inc/amplitude/offset/awg_sample/sample_valid/da_data/led`.
  - Default output is 1Hz, so a 2048-sample ILA window at 100MHz shows little visible waveform movement unless controls are changed or a faster debug frequency is used.

## 15. AD9144 AWG Button Variant Addendum (2026-05-06)

- Purpose: make the already-proven AD9144/JESD analog path respond to the two K325T board keys on the oscilloscope.
- This variant does not replace the known-good vendor baseline `top_direct.bit`.
- Active bitstream now generated and programmed:
  - `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button.bit`
  - Build log: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button_build_20260506_retry.log`
  - Program log: `D:\FPGA\ad9144_bringup_k325t\vivado_awg_button_program_20260506.log`
- Source and constraints:
  - `D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v`
  - `D:\FPGA\ad9144_bringup_k325t\constraints\awg_button_k325t.xdc`
  - `D:\FPGA\ad9144_bringup_k325t\scripts\create_awg_button_project.tcl`
  - `D:\FPGA\ad9144_bringup_k325t\scripts\build_awg_button_direct.tcl`
  - `D:\FPGA\ad9144_bringup_k325t\scripts\program_awg_button.tcl`
- What changed versus `top_direct.bit`:
  - JESD204/GTX/LMK04828/AD9144/AD9250 initialization is kept from the vendor demo.
  - The vendor sine ROM path is retained, but its ROM address step, amplitude scale, and phase offset are controlled by keys.
  - This is a conservative oscilloscope-visible control demo, not the final full `awg_core` JESD integration.
- Key behavior:
  - `key0` is `A26`; `key1` is `A25`; both are active-low board buttons.
  - Default mode is amplitude mode (`ui_mode=1`), default amplitude is about 75 percent.
  - Press/release `key0`: increase current mode setting.
  - Press/release `key1`: decrease current mode setting.
  - Hold both keys for about 250 ms: switch edit mode.
  - LED output shows `ui_mode`: `0=frequency`, `1=amplitude`, `2=phase`.
- Scope expectations:
  - Probe AD9144 `OUT1` first with 50 ohm termination.
  - After programming, wait 12-15 seconds before judging output.
  - In default mode, pressing `key0` should increase amplitude toward full-scale; pressing `key1` should reduce amplitude.
  - Phase mode changes the ROM phase offset but is not a good single-channel pass/fail test; use a stable external reference or a second channel if phase must be judged.
- Frequency/phase artifact fix:
  - The AD9144 vendor path packs four DAC samples into each JESD TX beat.
  - The known-good 50 MHz pattern is `0,5,10,15,20...` in the 100-entry sine ROM.
  - Do not change only the beat-to-beat address increment. The four samples inside the beat must use `0,1,2,3` times the selected sample step, and the next beat must advance by `4 * sample_step`.
  - If this relationship is broken, low frequencies show phase-slip artifacts and high frequencies show obvious waveform distortion.
  - Regression check: `powershell -NoProfile -ExecutionPolicy Bypass -File D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1`.
- Fresh verification on 2026-05-06:
  - First build failed because PowerShell wrote a UTF-8 BOM into the copied vendor `top.v`; Vivado reported illegal bytes `EF BB BF`.
  - BOM was removed and the retry build completed with `write_bitstream completed successfully`.
  - Generated bitstream size: 3,225,126 bytes.
  - Hardware programming completed with `End of startup status: HIGH`.
  - Vivado reported 3 ILA cores and 1 VIO core after programming; missing probes warning only affects debug-core viewing, not analog output.

## 16. AD9144 AWG Button Artifact Fix Addendum (2026-05-06)

- User observation after first scope test:
  - 50 MHz was mostly smooth with slight artifacts.
  - Lower frequency showed clear phase-misalignment artifacts.
  - Higher frequency showed obvious waveform distortion.
- Root cause:
  - The first AWG button variant treated the frequency setting as a beat-to-beat ROM address step but kept the four in-beat sample offsets fixed at `+5/+10/+15`.
  - That produced nonuniform sample order such as `0,5,10,15,1,6...` at low frequency or `0,5,10,15,25,30...` at high frequency.
- Fix:
  - `sample_step_from_sel()` now returns the per-DAC-sample ROM step.
  - In-beat addresses are `phase + 0*step`, `phase + 1*step`, `phase + 2*step`, `phase + 3*step`.
  - The next JESD beat advances by `4*step`.
  - Default frequency selection is `3'd4`, mapping to `step=5`, preserving the known-good 50 MHz baseline.
  - Frequency choices are intentionally conservative for this ROM demo: about 10, 20, 30, 40, 50, 80, and 100 MHz. Higher final AWG frequencies should be implemented with the real NCO/waveform path rather than this 100-point ROM demo.
- Verification:
  - `D:\FPGA\ad9144_bringup_k325t\scripts\check_awg_button_sequence.ps1` validates every frequency selection has constant inter-sample phase spacing across JESD beat boundaries.
