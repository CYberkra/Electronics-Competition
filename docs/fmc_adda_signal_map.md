# FMC ADDA 信号映射表

> 目标：记录 FMCADDA-9250-9144 子卡 ↔ 正点原子 K7-325T 底板之间的完整信号映射
> 来源：`FMCADDA-9250-9144 子卡用户说明.pdf`、`K7_BASE_1V3_2025_0111_USER.pdf`（底板原理图）

## 1. FMC HPC 接口信号总表（子卡侧）

来源：子卡用户说明文档 FMC HPC 接口信号列表

| 子卡信号名 | FMC 引脚 | LA 信号 | 方向 | 连接芯片 | 项目端口名 |
|-----------|---------|---------|------|---------|-----------|
| **时钟与参考** | | | | | |
| FPGA_REF_CLK_P/N | D5/D6 | GBTCLK0_M2C_P/N | IN | LMK04828 OUT0 | `fmc_gbtclk0_m2c_p/n` |
| — | D4/D3 | GBTCLK1_M2C_P/N | IN | 备用 | `fmc_gbtclk1_m2c_p/n` |
| — | G22/G23 | LA20_P/N | IN | LMK04828 SYSREF | `fmc_sysref_p/n` |
| **ADC (AD9250) — JESD204B** | | | | | |
| FMC_ADC_SCLK | D8 | LA01_P_CC | OUT | AD9250 SCLK | `ad9250_spi_sclk` |
| FMC_ADC_CSN | D9 | LA01_N_CC | OUT | AD9250 CSN | `ad9250_spi_csb` |
| FMC_ADC_SDIO | H9 | LA02_N | INOUT | AD9250 SDIO | `ad9250_spi_sdio` |
| FMC_ADC_RSTN | H4 | CLK0_M2C_P | OUT | AD9250 RSTN | `ad9250_reset` |
| FMC_ADC_FDA | — | LA02_P | IN | AD9250 FDA | — |
| FMC_ADC_FDB | — | LA02_P | IN | AD9250 FDB | — |
| FMC_ADC0_P/N | G4/G3 | DP0_M2C_P/N | IN | AD9250 Lane0 | `fmc_dp0_m2c_p/n` |
| FMC_ADC1_P/N | F6/F5 | DP1_M2C_P/N | IN | AD9250 Lane1 | `fmc_dp1_m2c_p/n` |
| **ADC 同步** | | | | | |
| — | D17/D18 | LA13_P/N | OUT | AD9250 SYNC~ | `adc_sync_p/n` |
| **DAC (AD9144) — JESD204B** | | | | | |
| FMC_DAC_SDIO | C10 | LA06_P | INOUT | AD9144 SDIO | `ad9144_spi_sdio` |
| FMC_DAC_SDO | C11 | LA06_N | — | AD9144 SDO | — |
| FMC_DAC_SCLK | C14 | LA10_P | OUT | AD9144 SCLK | `ad9144_spi_sclk` |
| FMC_DAC_CSN | C15 | LA10_N | OUT | AD9144 CSN | `ad9144_spi_csb` |
| FMC_DAC_RSTN | C19 | LA14_N | OUT | AD9144 RSTN | `ad9144_reset` |
| FMC_DAC_IRQN | C18 | LA14_P | IN | AD9144 IRQN | — |
| FMC_DAC_PROT0 | G23 | LA18_P_CC | OUT | AD9144 PROT0 | — |
| FMC_DAC_PROT1 | G24 | LA18_N_CC | OUT | AD9144 PROT1 | — |
| FMC_DAC_TXEN0 | H10 | LA04_P | OUT | AD9144 TXEN0 | `ad9144_txen0` |
| FMC_DAC_TXEN1 | H11 | LA04_N | OUT | AD9144 TXEN1 | `ad9144_txen1` |
| FMC_DAC0_P/N | H2/H1 | DP0_C2M_P/N | OUT | AD9144 Lane0 | `fmc_dp0_c2m_p/n` |
| FMC_DAC1_P/N | F2/F1 | DP1_C2M_P/N | OUT | AD9144 Lane1 | `fmc_dp1_c2m_p/n` |
| FMC_DAC2_P/N | J4/J3 | DP2_C2M_P/N | OUT | AD9144 Lane2 | `fmc_dp2_c2m_p/n` |
| FMC_DAC3_P/N | K2/K1 | DP3_C2M_P/N | OUT | AD9144 Lane3 | `fmc_dp3_c2m_p/n` |
| **DAC 同步** | | | | | |
| — | E19/D19 | LA05_P/N | IN | AD9144 SYNC0 | `dac_sync0_p/n` |
| — | D21/C21 | LA09_P/N | IN | AD9144 SYNC1 | `dac_sync1_p/n` |
| **ADK 总线 (LMK04828 控制)** | | | | | |
| FMC_ADK_SCLK | G31 | **LA29_N** | OUT | LMK04828 SCK | `lmk04828_spi_sclk` |
| FMC_ADK_SDIO | H32 | **LA28_N** | INOUT | LMK04828 SDIO | `lmk04828_spi_sdio` |
| FMC_ADK_CSB | H31 | **LA28_P** | OUT | LMK04828 CS# | `lmk04828_cs_n` |
| FMC_ADK_RST | G30 | **LA29_P** | OUT | LMK04828 RESET | `lmk04828_reset` |
| FMC_ADK_SYSREF | H29 | LA24_N | IN | LMK04828 SYSREF | — |

## 2. FPGA 底板管脚映射（正点原子 K7-325T 侧）

来源：`constraints/fmc_adda.xdc`，已验证信号打 ✅

| LA 信号 | FMC 引脚 | FPGA 管脚 | Bank | IOSTD | 端口名 | 状态 |
|---------|---------|-----------|------|-------|--------|------|
| GBTCLK0_M2C_P/N | D5/D6 | G8/G7 | 117 | — | `fmc_gbtclk0_m2c_p/n` | ✅ |
| CLK0_M2C_P | H4 | F20 | 14 | LVCMOS25 | `ad9250_reset` | ✅ |
| LA01_P_CC | D8 | F21 | — | LVCMOS25 | `ad9250_spi_sclk` | ✅ |
| LA01_N_CC | D9 | E21 | — | LVCMOS25 | `ad9250_spi_csb` | ✅ |
| LA02_N | H9 | J18 | — | LVCMOS25 | `ad9250_spi_sdio` | ✅ |
| LA02_P | — | — | — | — | (FDA/FDB) | — |
| LA04_P | H10 | D16 | — | LVCMOS25 | `ad9144_txen0` | ✅ |
| LA04_N | H11 | C16 | — | LVCMOS25 | `ad9144_txen1` | ✅ |
| LA05_P/N | D11/D12 | E19/D19 | — | LVDS_25 | `dac_sync0_p/n` | ✅ |
| LA06_P | C10 | B18 | — | LVCMOS25 | `ad9144_spi_sdio` | ✅ |
| LA09_P/N | D14/D15 | D21/C21 | — | LVDS_25 | `dac_sync1_p/n` | ✅ |
| LA10_P | C14 | C19 | — | LVCMOS25 | `ad9144_spi_sclk` | ✅ |
| LA10_N | C15 | B19 | — | LVCMOS25 | `ad9144_spi_csb` | ✅ |
| LA13_P/N | D17/D18 | D22/C22 | — | LVDS_25 | `adc_sync_p/n` | ✅ |
| LA14_N | C19 | F18 | — | LVCMOS25 | `ad9144_reset` | ✅ |
| LA14_P | C18 | — | — | — | `ad9144_irqn` | — |
| LA18_P_CC | G23 | G23 | — | LVCMOS25 | PROT0 | — |
| LA18_N_CC | G24 | G24 | — | LVCMOS25 | PROT1 | — |
| LA20_P/N | G22/G23 | D14/C14 | — | LVDS_25 | `fmc_sysref_p/n` | ✅ |
| **LA28_P** | H31 | **J11** | — | LVCMOS25 | **`lmk04828_cs_n`** | ✅ |
| **LA28_N** | H32 | **J12** | — | LVCMOS25 | **`lmk04828_spi_sdio`** | ✅ |
| **LA29_P** | G30 | **F15** | — | LVCMOS25 | **`lmk04828_reset`** | ✅ |
| **LA29_N** | G31 | **E16** | — | LVCMOS25 | **`lmk04828_spi_sclk`** | ✅ |
| PRSNT | — | AF30 | — | LVCMOS25 | `fmc_prsnt` | ✅ |

## 3. ADK 总线详情

ADK（ADDA Kit）总线是 LMK04828 的 SPI 控制总线，连接到 FMC HPC 的 LA28/LA29 差分对。

| ADK 信号 | SPI 等效 | FMC 引脚 | LA 信号 | 方向 | 说明 |
|---------|---------|---------|---------|------|------|
| ADK_SCLK | SPI SCK | G31 | LA29_N | OUT | SPI 时钟 |
| ADK_SDIO | SPI SDIO | H32 | LA28_N | INOUT | SPI 数据（双向） |
| ADK_CSB | SPI CS# | H31 | LA28_P | OUT | SPI 片选（低有效） |
| ADK_RST | RESET | G30 | LA29_P | OUT | 复位（低有效） |

## 4. 板载外设（非 FMC）

| 信号 | FPGA 管脚 | Bank | IOSTD | 说明 |
|------|----------|------|-------|------|
| `sys_clk_p/n` | AE10/AF10 | — | DIFF_SSTL15_DCI | 板载 100MHz 差分时钟 |
| `sys_rst_n` | AB25 | 13 | LVCMOS25 | 板载 KEY0（低复位） |
| `key0` | A26 | — | LVCMOS33 | 板载 KEY |
| `key1` | A25 | — | LVCMOS33 | 板载 KEY |
| `led[0]` | R24 | — | LVCMOS33 | 板载 LED |
| `led[1]` | R23 | — | LVCMOS33 | 板载 LED |
| `uart_rxd` | T23 | — | LVCMOS33 | USB-UART (CH340G) |
| `uart_txd` | T22 | — | LVCMOS33 | USB-UART (CH340G) |

## 5. 当前分配状态

**全部 44 个端口已约束，零 DRC Error。** ✅

| 模块 | 状态 | 验证方式 |
|------|------|---------|
| AD9144 SPI/SYNC/TXEN/RESET | ✅ 已约束 | 子卡用户说明 + 底板原理图 |
| AD9250 SPI/SYNC/RESET | ✅ 已约束 | 子卡用户说明 + 底板原理图 |
| JESD204B GTX 收发器 | ✅ 已约束 | 子卡用户说明 |
| LMK04828 SCLK/SDIO/CS#/RESET | ✅ 已约束 | ADK 总线表 + 底板原理图 P15 |
| 板载 UART/KEY/LED/时钟 | ✅ 已约束 | K7_IO.xdc 参考 |

## 6. 参考文件

| 文件 | 位置 | 用途 |
|------|------|------|
| 子卡用户说明 | `docs/references/FMCADDA-9250-9144子卡用户说明.pdf` | FMC 接口信号表 |
| 子卡原理图 | `docs/references/FMC_9250_9144_BRD_SCH.pdf` | 子卡电路详细连接 |
| 正点原子底板原理图 | `docs/references/K7_BASE_1V3_2025_0111_USER.pdf` | FPGA 管脚→FMC 连接器映射 |
| 正点原子 IO 参考 | `docs/references/K7_IO.xdc` | 板级外设引脚速查 |
| FMC 约束 | `constraints/fmc_adda.xdc` | FPGA 管脚约束实现 |
| 主约束 | `constraints/awg_k325t.xdc` | 系统级约束 |
