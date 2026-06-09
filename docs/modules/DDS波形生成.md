
# DDS 波形生成

## 已完成内容

`D:\awg_fpga` 中的 DDS Compiler 验证路径已经跑通：

| 项目 | 状态 |
|---|---|
| DDS Compiler IP 配置 | 已完成 |
| Wrapper 封装 | 已完成 |
| 行为仿真 | 1 MHz / 2 MHz / 0 Hz 通过 |
| LED 板级测试 bitstream | 已生成 |

bit 文件：

```text
D:\awg_fpga\vivado\awg_k325t.runs\impl_1\awg_dds_led_top.bit
```

## DDS Compiler 参数

| 参数 | 值 |
|---|---|
| Phase Width | 48 bit |
| Output Width | 16 bit signed |
| Phase Increment | Programmable |
| Phase Out | disabled |

频率公式：

```text
f_out = phase_inc * f_clk / 2^48
phase_inc = f_out * 2^48 / f_clk
```

常用值：

| 目标频率  |      时钟 | Phase Inc            |
| ----- | ------: | -------------------- |
| 1 MHz | 100 MHz | `48'h28f5c28f5c2`    |
| 2 MHz | 100 MHz | `48'h51eb851eb84`    |
| 1 Hz  | 100 MHz | `48'h0000000002AF31` |
| 1 mHz | 100 MHz | `48'h0000000000000B` |

## 与 AD9144 路线的关系

DDS 本身不是当前阻塞。AD9144 standalone bring-up 目前使用 vendor ROM waveform，而不是最终 DDS 数据。正确顺序：

1. 用 vendor ROM 证明 JESD/AD9144 链路活着。
2. 用 ILA 看到 TX sample data 正在变化。
3. 再把 DDS/BRAM/DDR 数据接入 JESD transport。

## 关联文件

```text
D:\awg_fpga\rtl\dds\dds_compiler_wrapper.v
D:\awg_fpga\rtl\top\awg_dds_led_top.v
D:\awg_fpga\sim\tb\tb_dds_compiler.v
D:\awg_fpga\constraints\awg_dds_led_top.xdc
```

