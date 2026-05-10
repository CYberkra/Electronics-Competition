# AWG K325T — 任意波形信号发生器

> 第二十一届研电赛 · 优利德赛题二 FPGA 数字基带
> 目标器件：Xilinx Kintex-7 XC7K325TFFG900-2I（正点原子开发板）

---

## 项目简介

基于 **正点原子 K7-325T** 开发板，实现研电赛优利德命题"任意波形信号发生器"的 FPGA 数字基带部分。

**核心指标**

| 指标 | 要求 | 当前状态 |
|------|------|----------|
| 采样率 | ≥ 5GSa/s | Phase 2 规划 |
| 模拟带宽 | ≥ 1GHz | Phase 2 规划 |
| 垂直分辨率 | ≥ 14bit | Phase 2 规划 |
| 正弦最小频率 | ≤ 1mHz | ✅ 已验证 |
| 最高频率 | ≥ 1GHz | Phase 2 规划 |
| 频率分辨率 | ≤ 1mHz | ✅ 已验证 |
| 谐波失真 | 优于 -40dBc | 待测 |
| 非谐波杂散 | 优于 -60dBc | 待测 |

**当前进度**

- [x] License 验证
- [x] LED 闪烁 / 按键调频（1Hz ~ 10MHz，8 档）
- [x] DDS Compiler IP（48bit 相位 / 16bit 输出）
- [x] 教学 DAC 并行接口
- [x] FMC ADDA 骨架（AD9144 + AD9250）
- [x] LMK04828 SPI 控制器
- [x] JESD204 IP 配置（TX 4 lane / 10Gbps）
- [ ] 幅度/偏置/缩放模块
- [ ] 扫频引擎
- [ ] BRAM 波形存储
- [ ] Phase 2：DDR3 + PCIe + 完整测量验证

---

## 环境要求

| 项目 | 版本/路径 |
|------|----------|
| **Vivado** | **2024.1 Enterprise Edition** |
| 目标器件 | `xc7k325tffg900-2` |
| 开发板 | 正点原子 Kintex-7 325T |
| License | 需包含 Synthesis + `xc7k325t` + JESD204 |

> **注意**：Vivado 2024.2 已移除 7 系列 FPGA 的 JESD204 IP 支持，**必须使用 2024.1**。

---

## 快速开始

### 1. 克隆仓库（任意路径）

```powershell
git clone https://github.com/CYberkra/Electronics-Competition.git
cd Electronics-Competition
```

> 所有脚本已改为**相对路径自动推导**，无需固定放在 `D:\awg_fpga`。

### 2. 打开 Vivado 工程

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat vivado\awg_k325t.xpr
```

> 若提示 `Critical Messages` 找不到 `.wcfg` 或 `.dcp`，点 **OK 忽略** 即可。这是 Vivado `.xpr` 跨机器迁移的正常现象，不影响功能。

### 3. 升级 IP（首次打开必须做）

```tcl
# 在 Vivado Tcl Console 中执行
source scripts/vivado2024.1/upgrade_ip.tcl
```

或手动：IP Catalog → `dds_compiler_0` → **Reset Output Products** → **Generate Output Products**

### 4. 一键生成 Bitstream

```powershell
# Tcl 脚本（推荐）
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/rebuild_awg_base.tcl

# Python 后台运行
python scripts/launch_vivado.py

# PowerShell
.\scripts\vivado_wrapper.ps1
```

生成后的 Bitstream：`vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit`

### 5. JESD204 专用脚本（Vivado 2024.1）

```powershell
# 验证 License 和设备支持
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/vivado2024.1/verify_license.tcl

# 检查 JESD204 IP 可用性
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/vivado2024.1/check_jesd204.tcl

# 创建 JESD204 TX IP
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/vivado2024.1/create_jesd204_tx_ip.tcl

# 重新创建完整工程（含 DDS + JESD204）
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/vivado2024.1/recreate_project_with_jesd204.tcl
```

### 6. 仿真验证

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source run_simulation.tcl
```

---

## 仓库结构

```
Electronics-Competition/
├── rtl/                  # Verilog RTL 源码
│   ├── top/              # 顶层模块（DDS LED Demo / FMC ADDA）
│   ├── dds/              # DDS 直接数字频率合成
│   ├── dac/              # DAC 接口（教学 DAC / AD9144 SPI）
│   ├── dsp/              # 数字信号处理
│   ├── clk/              # 时钟模块（LMK04828 SPI）
│   └── fmc/              # FMC 子卡逻辑（JESD204 / AD9250）
├── constraints/          # XDC 约束文件
├── sim/                  # 仿真 testbench
├── vivado/               # Vivado 工程（.xpr + .xci IP 配置）
├── scripts/              # 自动化脚本
│   ├── *.tcl             # 旧脚本（兼容 DDS 基础流程）
│   └── vivado2024.1/     # Vivado 2024.1 迁移专用脚本
├── obsidian/             # 项目知识库（Obsidian 格式）
├── AGENTS.md             # 项目知识库（Agent 协作必读）
├── README.md             # 本文件
└── .gitignore
```

---

## 关键文档

| 需求 | 查看 |
|------|------|
| 项目完整知识库 | `AGENTS.md` |
| 模块架构与踩坑记录 | `AGENTS.md` → 第 4-6 章 |
| 开发板引脚速查 | `obsidian/05-参数手册/` |
| JESD204 建链流程 | `obsidian/02-模块设计/AD9144 Bring-Up.md` |
| 时钟配置 | `obsidian/02-模块设计/LMK04828时钟配置.md` |
| Vivado 2024.1 迁移 | `scripts/vivado2024.1/` + `obsidian/00-项目概述/软件工具链.md` |

---

## 协作规范

### Git 分支策略

```text
main          # 稳定版本
  └── dev     # 日常开发
      └── feature/<name>
```

### 提交规范

```bash
git commit -m "type: 简短描述"
```

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `docs` | 文档更新 |
| `refactor` | 代码重构 |
| `test` | 添加测试 |
| `chore` | 构建/工具更新 |

### 代码规范

- **注释**：使用 ASCII 注释，避免 GBK 中文乱码
- **端口**：显式声明 `input wire` / `output wire`
- **复位**：低电平有效异步复位（`rst_n`）
- **时钟**：差分时钟必须使用 `IBUFDS` → `BUFG`
- **脚本**：**禁止硬编码绝对路径**，使用相对路径自动推导

### 应该提交 vs 不应该提交

✅ **必须提交**：RTL（`.v`）、约束（`.xdc`）、IP 配置（`.xci`）、脚本、文档
❌ **不要提交**：Vivado 生成文件（`*.cache/`、`*.runs/`、`*.sim/`）、Bitstream（`*.bit`）、波形配置（`*.wcfg`）

---

## 常见问题

### Q: 打开工程时提示 "Could not find the file ..."？

Vivado `.xpr` 使用绝对路径保存波形配置（`.wcfg`）和 IP 缓存（`.dcp`）。**点 OK 忽略**，不影响功能。波形配置会在首次仿真运行后自动重建。

### Q: 脚本可以放在任意路径吗？

可以。所有脚本已改为**相对路径自动推导**：
- Tcl：`[file dirname [info script]]`
- Python：`Path(__file__).parent.resolve()`
- PowerShell：`$MyInvocation.MyCommand.Path`
- Batch：`%~dp0`

### Q: 为什么必须用 Vivado 2024.1？

2024.2 移除了 7 系列 FPGA 的 JESD204 IP 支持。本项目使用 AD9144 高速 DAC，依赖 JESD204 v7.2 IP，**必须使用 2024.1**。

---

> **维护者**: Sisyphus Agent
> **最后更新**: 2026-05-06
