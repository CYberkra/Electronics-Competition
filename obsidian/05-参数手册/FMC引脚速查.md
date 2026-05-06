---
type: reference
updated: 2026-05-06
tags:
  - fmc
  - pinout
  - ad9144
---

# FMC 引脚速查

来源：K7 底板原理图第 15 页和 FMCADDA-9250-9144 子卡资料。当前以 `D:\FPGA\ad9144_bringup_k325t\constraints\top_k325t_fmc.xdc` 为实现依据。

## 高速差分对

| FMC signal | FPGA pins | Bank117 | 方向 | 用途 |
|---|---|---|---|---|
| DP0_C2M_P/N | H2 / H1 | TX2 | FPGA -> DAC | DAC lane 0 |
| DP1_C2M_P/N | F2 / F1 | TX3 | FPGA -> DAC | DAC lane 1 |
| DP2_C2M_P/N | J4 / J3 | TX1 | FPGA -> DAC | DAC lane 2 |
| DP3_C2M_P/N | K2 / K1 | TX0 | FPGA -> DAC | DAC lane 3 |
| DP0_M2C_P/N | G4 / G3 | RX2 | ADC -> FPGA | ADC lane 0 |
| DP1_M2C_P/N | F6 / F5 | RX3 | ADC -> FPGA | ADC lane 1 |
| GBTCLK0_M2C_P/N | G8 / G7 | CLK0 | 子卡 -> FPGA | GTX refclk |
| GBTCLK1_M2C_P/N | J8 / J7 | CLK1 | 子卡 -> FPGA | 备用 refclk |

## 低速信号

| 信号 | FPGA pins | 用途 |
|---|---|---|
| LA00_CC_P/N | D17 / D18 | `glblclk_p/n` |
| LA05_P/N | E19 / D19 | DAC SYNC0 `i_tx_sync_p/n` |
| LA13_P/N | D22 / C22 | ADC SYNC `o_rx_sync_p/n` |
| LA20_P/N | D14 / C14 | `sysref_p/n` |
| LA28_P/N | J11 / J12 | LMK `cs_n` / `sda` |
| LA29_P/N | F15 / E16 | LMK `rst` / `sclk` |

## SPI/control

| 目标 | 信号 | FPGA 引脚 |
|---|---|---|
| AD9250 | `ads_sda` | J18 |
| AD9250 | `ads_sclk` | F21 |
| AD9250 | `ads_sen_n` | E21 |
| AD9250 | `ads_rstn` | F20 |
| AD9144 | `das_sda` | B18 |
| AD9144 | `das_sclk` | C19 |
| AD9144 | `das_sen_n` | B19 |
| AD9144 | `das_rstn` | F18 |
| AD9144 | `das_txen0` | D16 |
| AD9144 | `das_txen1` | C16 |
| LMK04828 | `lmk_sda` | J12 |
| LMK04828 | `lmk_sclk` | E16 |
| LMK04828 | `lmk_cs_n` | J11 |
| LMK04828 | `lmk_rst` | F15 |

## 已修正的旧误区

- LA13 是 D22/C22，不是 D18/D19。
- LA10 是 C19/B19，不是 B19/unknown。
- LMK SPI 使用 LA28/LA29，不使用 FMC IIC AD29/AE29。

