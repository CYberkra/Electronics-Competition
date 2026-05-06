---
type: troubleshooting
updated: 2026-05-06
tags:
  - license
  - jesd204
  - resolved
---

# License 与 JESD204 授权

## 当前事实

当前可用 license 文件：

```text
C:\Users\17844\AppData\Roaming\XilinxLicense\Xlnx_2024.lic
```

历史 trial 备份：

```text
C:\Users\17844\AppData\Roaming\XilinxLicense\trial_backup_20260506_093702.lic
```

已验证 Vivado 2024.1 Enterprise 能完成 K325T + JESD204 工程 bitstream 生成：

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit
```

## 历史阻塞

此前 `trial.lic` 只覆盖 K325T Synthesis/Implementation，不覆盖 JESD204 LogiCORE bitstream 生成权限。典型错误：

```text
ERROR: [Common 17-69] Command failed: This design contains one or more cells for which bitstream generation is not permitted:
jesd204_tx_inst/inst/i_jesd204_tx (<encrypted cellview>)
jesd204_rx_inst/inst/i_jesd204_rx (<encrypted cellview>)
```

如果这个错误重新出现，优先检查 Vivado 是否仍在读取 `Xlnx_2024.lic`，以及 JESD204 IP output products 是否重新生成。

## 判断规则

| 现象 | 结论 |
|---|---|
| `[Common 17-345] A valid license was not found for Synthesis/xc7k325t` | K325T 器件/综合 license 不可用 |
| `K325T_SYNTHESIS_TEST_OK` | K325T 综合 license 可用 |
| `[Common 17-69] bitstream generation is not permitted` 且指向 `jesd204_tx/rx` | JESD204 IP bitstream 授权缺失或未被当前 Vivado 读取 |
| `top_direct.bit` 正常生成 | license 不再是当前 AD9144 bring-up 阻塞 |

## 当前建议

当前不要再围绕 license 重复排查。若后续换电脑、换 Vivado 或换 license 文件，再运行：

```powershell
& D:\vivado\Vivado\2024.1\bin\vivado.bat -mode batch -source D:\FPGA\ad9144_bringup_k325t\scripts\build_direct.tcl
```

以能否重新生成 `top_direct.bit` 作为验收标准。
