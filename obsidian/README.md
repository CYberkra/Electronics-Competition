# K325T AWG FPGA 项目笔记

> 第二十一届研电赛优利德赛题二 —— 基于 Kintex-7 的任意波形发生器（AWG）FPGA 数字基带平台

## 快速入口

- [[项目简介]] — 项目背景、目标、竞赛要求
- [[硬件平台]] — K325T 开发板 + FMC ADDA 子卡资源
- [[软件工具链]] — Vivado 2024.1、Git、仿真环境
- [[顶层架构图]] — 系统模块划分与数据流
- [[开发路线图]] — 从 LED 到 FMC 高速 DAC 的完整路线
- [[待办事项]] — 当前阻断项与下一步任务

## 项目状态

| 阶段 | 状态 | 备注 |
|---|---|---|
| License & LED 闭环 | ✅ 完成 | Vivado trial + LED bitstream |
| DDS 波形生成 | ✅ 完成 | IP核 + 手写NCO（未接入） |
| 教学 DAC 验证 | ✅ 完成 | ATK-HS-ADDA 8bit 接口 |
| FMC 子卡驱动 | 🔄 进行中 | JESD204 链路建立中 |
| PCIe XDMA 控制 | ⏳ 待启动 | 需先完成 JESD204 |
| DDR3 波形缓冲 | ⏳ 待启动 | 大容量波形存储 |

## 关键路径

```
License → LED → clk_reset → DDS → amp_offset_scale → 教学DAC → FMC ADDA(JESD204) → BRAM波形 → PCIe → DDR3 → 校准
```

## 重要文档

- 竞赛 PDF: `D:\FPGA\第二十一届研电赛优利德命题 (1).pdf`
- 正点原子开发指南: `D:\FPGA\Kintex7\Kintex7\2_文档教程\【正点原子】Kintex7之FPGA开发指南V1.3.pdf`
- FMC 子卡资料: `D:\FPGA\FMCADDA-9250-9144\`
- AGENTS.md: `D:\FPGA\AGENTS.md`

## 仓库

```
D:\awg_fpga\          (主工程 RTL + Vivado)
https://github.com/CYberkra/Electronics-Competition.git
```
