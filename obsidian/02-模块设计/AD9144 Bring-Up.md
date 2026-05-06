---
type: bringup
updated: 2026-05-06
tags:
  - ad9144
  - bringup
  - jesd204
  - oscilloscope
---

# AD9144 Bring-Up

## 当前结论

截至 2026-05-06，standalone bring-up 工程已经完成从 license、bitstream 到板级数字链路的基本验收：

| 阶段 | 结果 |
|---|---|
| `create_project.tcl` | 通过 |
| IP import/upgrade/generate | 通过 |
| `synth_design` | 通过，0 errors |
| `opt_design` / `place_design` / `route_design` | 通过 |
| `write_bitstream` | 通过，已生成 `top_direct.bit` |
| FPGA-only diagnostic | 通过，K325T/JTAG/100MHz/ILA 正常 |
| FMC installed JESD TX check | 通过到数字侧：QPLL/reset/tready/SYNC/SYSREF/data 正常 |
| AD9250 RX | `tvalid=0`，后续单独排查 |

当前短期目标应转到 **AD9144 DAC 模拟输出首测**，不是继续查 license 或基础 FPGA 连接。

## 工程路径

```text
D:\FPGA\ad9144_bringup_k325t
```

关键文件：

```text
D:\FPGA\ad9144_bringup_k325t\constraints\top_k325t_fmc.xdc
D:\FPGA\ad9144_bringup_k325t\scripts\build_direct.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\build_cfg_debug_direct.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\capture_cfg_debug_ila.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\probe_ila_clocks_wait.tcl
D:\FPGA\ad9144_bringup_k325t\scripts\capture_jesd_ila_wait.tcl
D:\FPGA\ad9144_bringup_k325t\ip_data\sine.coe
```

bit/probes：

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct.bit
D:\FPGA\ad9144_bringup_k325t\vivado\top_cfg_debug.bit
D:\FPGA\ad9144_bringup_k325t\vivado\top_cfg_debug.ltx
```

## 板级数字链路证据

TX ILA 证据文件：

```text
D:\FPGA\ad9144_bringup_k325t\vivado\jesd_capture_20260506\tx_ila.csv
```

关键观测：

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

结论：FPGA 到 AD9144 的 JESD TX 数字侧已经活起来，可以进入示波器验证。它还不证明模拟幅度、频率和通道映射正确。

RX ILA 证据文件：

```text
D:\FPGA\ad9144_bringup_k325t\vivado\jesd_capture_20260506\rx_ila.csv
```

关键观测：

```text
w_rx_reset_done = 1
w_rx_tvalid = 0
w_rx_sync = 0
w_sysref_1 = 0/1 observed
w_rx_frame_error[7:0] = 00
w_rx_tdata[63:0] = 0000000000000000
```

结论：AD9250 RX 暂未产生有效数据，但不阻塞当前“先看到 DAC 输出波形”的短期目标。

## 示波器首测预期

当前设计还是 vendor ROM waveform，不是最终 AWG DDS 输出。根据 vendor 配置注释和 ILA 采样：

- AD9144 DAC sample rate 约为 2.0GSPS。
- 2x interpolation 后 FPGA/baseband sample rate 约为 1.0GSPS。
- ROM 正弦模式约 20 个 baseband sample 一个周期。
- 因此首测应优先寻找约 **50MHz** 的正弦或近似正弦输出。

操作建议：

1. 烧录后等待 12-15s，再判断 ILA 或模拟输出。
2. 先测 **OUT1**，使用 50 ohm 负载/终端。
3. OUT1 若为平线，依次试 OUT2-OUT4，不要立刻改 RTL。
4. 若所有输出都为平线，回到 TX ILA、SYSREF/SYNC、AD9144 SPI 初始化、模拟输出使能和供电/时钟指示灯排查。

## 2026-05-07 AWG button waveform demo

当前工作路径已经从 vendor ROM 过渡到四采样 DDS4：

```text
D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_awg_dds4.v
D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_sample_packer.v
D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v
D:\FPGA\ad9144_bringup_k325t\vivado_awg_button\top_awg_button.bit
```

按键 UI：
- 默认 `ui_mode=1`，即幅度模式。
- 双键长按约 250 ms 切换模式：`1=amplitude -> 2=phase -> 3=waveform -> 0=frequency`。
- 单按 KEY0 增大/前进当前参数，单按 KEY1 减小/后退当前参数。
- 波形模式下可切换 `0=sine`、`1=square`、`2=triangle`、`3=saw`。

硬件观察：
- OUT1 已确认有输出。
- 频率、幅度、波形切换均能在示波器上看到效果。
- 相位模式暂不作为单通道示波器验收项。
- 当前仍有波形失真，后续重点是 ILA 可观测性、timing/CDC 清理和模拟输出质量定位。
