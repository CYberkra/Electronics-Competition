---
type: troubleshooting
updated: 2026-05-06
tags:
  - vivado
  - errors
---

# Vivado 常见错误

## License

| 错误 | 含义 | 处理 |
|---|---|---|
| `[Common 17-345] A valid license was not found` | 当前功能或器件无 license | 运行 `check_k325t_synthesis.tcl`，检查 VLM |
| `[Common 17-69] bitstream generation is not permitted` | 加密 IP 不允许出 bitstream | 见 [[License与JESD204授权]] |

## XDC/DRC

| 错误 | 含义 | 处理 |
|---|---|---|
| `NSTD-1` | IO 没有电平标准 | 添加 `IOSTANDARD` |
| `UCIO-1` | IO 没有管脚位置 | 添加 `PACKAGE_PIN` |
| `No ports matched` | 约束端口名和顶层不一致，或旧 netlist | reset synthesis 后重跑 |

## Hardware Manager

| 现象 | 判断 |
|---|---|
| `[Labtoolstcl 44-513] HW Target shutdown` | 常见连接关闭提示，重新 Auto Connect |
| `Device has no supported debug core(s)` | 设计里没有 ILA/VIO，或烧错 bitstream |
| 有 ILA/VIO | 可以开始链路状态检查 |

## IP

| 现象 | 处理 |
|---|---|
| 2018.3 IP locked | 在 2024.1 中 upgrade/generate |
| 旧 COE 路径缺失 | 确认 `sine.coe` 已复制到旧路径 |
| 2024.2 JESD204 与 7 系列不兼容 | 使用 Vivado 2024.1 |

## Windows 脚本

当前 Codex batch 环境中，`launch_runs` 可能通过 `runme.bat -> cscript -> rundef.js` 触发：

```text
CScript Error: Loading your settings failed. (Access is denied.)
```

这不是 RTL 错误。用 direct build 绕过：

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\build_direct.tcl
```

