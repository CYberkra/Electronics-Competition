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
> **最后更新**: 2026-05-05  
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
10. [文档维护记录](#10-文档维护记录)

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
| **Vivado 版本** | 2024.2 |
| **Vivado 路径** | `D:\vivado\Vivado\2024.2` |
| **Vivado 启动器** | `D:\vivado\Vivado\2024.2\bin\vivado.bat` |
| **License 管理器** | `D:\vivado\Vivado\2024.2\bin\vlm.bat` |
| **目标器件** | `xc7k325tffg900-2` |
| **License 文件** | `C:\Users\17844\AppData\Roaming\XilinxLicense\trial.lic` |
| **License 状态** | ✅ 已验证（2026-05-01） |

**License 验证命令**:
```powershell
& D:\vivado\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\FPGA\check_k325t_synthesis.tcl
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
├── [⬜] 幅度/偏置/缩放模块
├── [⬜] 教学 DAC 接口
├── [⬜] 扫频引擎
├── [⬜] BRAM 波形存储
└── [⬜] Phase 1 Demo

Phase 2: 完整系统
├── [⬜] DDR3 MIG 配置
├── [⬜] PCIe XDMA 接口
├── [⬜] 高速 DAC 数字接口
├── [⬜] 校准表
└── [⬜] 完整测量验证
```

### 3.2 活跃工程列表

| 工程 | 路径 | 状态 | 最后更新 |
|------|------|------|----------|
| **awg_k325t** (DDS) | `D:\awg_fpga` | ✅ Bitstream 已生成 | 2026-05-05 |
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
    └── awg_k325t.xpr                   # Vivado 2024.2 工程
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
& D:\vivado\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\FPGA\rebuild_dds_from_synthesis.tcl
```

**仅仿真**:
```powershell
& D:\vivado\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\awg_fpga\run_simulation.tcl
```

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
| **路径敏感** | 工程打开失败或 IP 锁定 | 使用短 ASCII 路径，避免中文和空格 |
| **IP 锁定** | `IP is locked` | 右键 IP → **Upgrade IP** 或 **Reset Output Products** → **Generate** |
| **增量编译失效** | 修改后仍使用旧网表 | **Flow Navigator** → **Run Synthesis** → **Reset Runs** → 重新运行 |
| **Stale netlist** | `No ports matched 'xxx'` | 修改顶层端口后必须 **Reset Synthesis**，不能只重置 Implementation |

### 6.2 IP 配置经验

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| **64bit 相位不支持** | `Value '64' is out of the range (3,48)` | DDS Compiler v6.0 最大支持 **48bit**，使用 48bit 仍能满足 1mHz 分辨率要求 |
| **save_ip 不存在** | `invalid command name "save_ip"` | 使用 `save_project` 代替 |
| **参数依赖** | Phase_Width 无法手动设置 | 将 `Parameter_Entry` 从 `System_Parameters` 改为 `Hardware_Parameters` |
| **IP 删除残留** | 删除 IP 后工程报错 | 关闭工程 → 手动删除 IP 目录 → 重新打开工程 |

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
2. 打开 Vivado License Manager: `D:\vivado\Vivado\2024.2\bin\vlm.bat`
3. 确认 License 包含 `Synthesis` 和 `xc7k325t`
4. 运行验证命令:
```powershell
& D:\vivado\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\FPGA\check_k325t_synthesis.tcl
```

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

## 11. 文档维护记录

| 日期 | 更新内容 | 维护者 |
|------|----------|--------|
| 2026-05-01 | 初始版本：License 验证、1_led、6_reg 示例 | Sisyphus |
| 2026-05-02 | 添加 DDS Compiler IP 模块简要记录 | Sisyphus |
| 2026-05-05 | **全面重构**：添加 10 个章节结构、完整 DDS 文档、技术规范、经验教训、FAQ、操作指南 | Sisyphus |

### 下次更新建议

- [ ] 添加扫频引擎模块文档
- [ ] 添加 DDR3 MIG 配置记录
- [ ] 添加 PCIe XDMA 接口文档
- [ ] 添加高速 DAC 接口文档
- [ ] 更新板级验证结果（LED 闪烁实测）

---

> **End of Document**
>
> 本文档为 Agent 协作知识库，由 Sisyphus 维护。
> 如有疑问或需要更新，请在会话中提及。
