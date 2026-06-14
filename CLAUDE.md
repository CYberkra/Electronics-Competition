# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWG (Arbitrary Waveform Generator) FPGA implementation for the 21st National Graduate Electronics Competition (研电赛), Uni-Trend problem #2 — 任意波形信号发生器. TX-only DAC design (pure signal generation, no ADC/signal-acquisition needed).

- **Target device**: Xilinx Kintex-7 XC7K325TFFG900-2 on 正点原子 K7-325T dev board
- **Daughter card**: FMCADDA-9250-9144 (AD9144 DAC 4ch 16bit 2.8Gsps)
- **Clock chip**: LMK04828 PLL (50M TCXO → 125M/250M)
- **FMC connector**: HPC, connected to Bank 117 GTX
- **KiCad PCB**: Simple expansion board (ST7789 LCD + EC11 encoder) — satisfies competition silkscreen requirement

## Build Commands

**Must use Vivado 2024.1 Enterprise Edition** — 2024.2+ removed 7-series JESD204 IP support.

```powershell
# Full build with ILA debug (Synthesis → Implementation → Bitstream)
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/build_all.tcl

# Quick build with UART control, no ILA (the common workflow)
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/fix_synth.tcl

# Incremental build — 3-5x faster after first full build
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/build_fast.tcl

# Program the board over JTAG
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source scripts/program.tcl

# Simulation
& D:\Xilinx\Vivado\2024.1\bin\vivado.bat -mode batch -source sim/run_simulation.tcl
```

Output bitstream: `vivado/awg_k325t.runs/impl_1/awg_top.bit`

## Architecture

### Top-Level (`awg_top`)

The top module orchestrates everything in a flat instantiation style (no AXI interconnect, no soft processor). All control is managed by a hardcoded initialization state machine.

### Clock Domains

```
sys_clk_bufg (100MHz) — 100M differential board clock → BUFG. Drives key UI, LED status.
clk_25m        (25MHz)  — sys_mmcm output from CFGMCLK (65MHz via STARTUPE2). Drives ALL SPI controllers (LMK, AD9144, AD9250).
clk_axi_100m   (100MHz) — sys_mmcm output. Drives JESD204 AXI-Lite configuration and VIO.
w_tx_core_clk  (250MHz) — glblclk MMCM output from LMK OUT6 125MHz. Drives DDS, packer, JESD TX core.
w_rx_core_clk  (125MHz) — glblclk MMCM output (currently unused, ADC stripped).
w_qpll_refclk  (125MHz) — LMK OUT4 → GBTCLK0 → IBUFDS_GTE2 → QPLL. Reference for GTX transceivers.
```

### Data Path

```
4× DDS (ad9144_awg_dds4) → 4×16bit samples/cycle @250MHz
  → sample_packer → 128bit tx_tdata
    → JESD204 TX Core → 4× GTX lanes @10Gbps
      → FMC HPC → AD9144 DAC
```

The DDS generates 4 samples per 250MHz clock cycle to meet JESD204B's 8-octet-per-frame requirement at 1Gsps.

### Control Path

Two control sources, multiplexed by `awg_reg_use_control`:

1. **Button** (KEY0/KEY1): On-board push buttons → `awg_key_ui_ctrl` — switch frequency/waveform/amplitude/offset
2. **UART** (115200 8N1): Host PC → `ad9144_uart_reg_bridge` → 32-bit register writes — enabled via `AWG_UART_CONTROL` define

Both feed into `ad9144_awg_reg_bank` which resolves priority and drives DDS parameters.

### Initialization Sequence (on-chip state machine @clk_25m)

```
State 0→1: Assert LMK04828 SPI config
State 2→3: Wait LMK done
State 4:   JESD TX reset sequence (pulse + AXI-Lite config window)
State 5→6: Assert AD9144 SPI config
State 7:   Idle — DDS begins output
```

### SPI Architecture

All three SPI targets (LMK04828, AD9250, AD9144) share the same `spi_wr_rd_single` controller module at 25MHz. Each has its own config wrapper that sequences the register writes for that specific chip.

### RTL Directory Map

```
rtl/
├── top/       awg_top.v (flat instantiation), awg_top_diag.v, awg_test_led.v
├── control/   awg_key_ui_ctrl.v, awg_led_status.v — button debounce, LED blinking patterns
├── dds/       dds_compiler_wrapper.v (Xilinx DDS IP wrapper), dds_nco.v, sine_lut.v, wave_shape_gen.v
├── dsp/       awg_core.v, amp_offset_scale.v, sample_mux.v — signal processing pipeline
├── jesd/      SPI controllers (spi_wr_rd_single.v, lmk_spi_wr_config.v, ad9144_spi_wr_config.v, ad9250_spi_config.v)
│              JESD AXI (jesd_axi_write.v, jesd_axi_read.v), UART (uart_rx.v, uart_tx.v, ad9144_uart_reg_bridge.v)
│              AWG core (ad9144_awg_dds4.v, ad9144_awg_reg_bank.v, ad9144_sample_packer.v, ad9144_awg_cal.v)
│              Reset (rst_module.v), data parse (jesd_data_parse.v)
├── sweep/     sweep_engine.v — frequency sweep/ramp engine
└── wave/      bram_wave_player.v — BRAM-based arbitrary waveform playback
```

### Vivado IP Cores

| IP | Purpose |
|----|---------|
| `jesd204_phy_0` | GTXE2 transceiver wrapper (QPLL, 4 TX lanes @10Gbps) |
| `jesd204_tx` | JESD204B TX link layer core |
| `jesd204_rx` | JESD204B RX core (present but not wired, ADC stripped) |
| `clk_sys_mmcm` | 65M CFGMCLK → 25M + 100M |
| `clk_for_glbclk` | 125M glblclk → 125M rx_core_clk + 250M tx_core_clk |
| `dds_compiler_0` | Xilinx DDS Compiler IP |
| `ila_awg_debug` / `my_ila_jesd` | ILA debug cores (controlled by `AWG_DEBUG_ILA` define) |
| `vio_for_jesd_rst` | Virtual I/O for JESD reset debug |
| `blk_mem_gen_0` | Block RAM for waveform storage |

### Build-Time Defines

Set via `set_property verilog_define` in Tcl scripts:

- `AWG_UART_CONTROL=1` — enables UART remote register bridge (115200 8N1)
- `AWG_DEBUG_ILA=1` — inserts ILA debug core probing DDS samples, state machine, status signals

### Key Constraint Notes

- `constraints/awg_k325t.xdc` — system-level: clocks, pin mapping, false paths for CDC, SPI, UART
- `constraints/fmc_adda.xdc` — FMC daughter card pin mapping (may be a subset/supplement)
- DRC check PDRC-153 (gated clock false positive) downgraded to Info — the SPI FSM uses clock-enable pattern
- All SPI/UART signals are false-path'd since they are low-speed async control

### Simulation

Testbenches in `sim/tb/`:
- `tb_awg_core.v` — AWG core signal processing
- `tb_awg_cal.v` — digital calibration table
- `tb_dds_compiler.v` — DDS waveform generation
- `tb_key_led.v` / `tb_awg_key_ui_ctrl.v` / `tb_awg_led_status.v` — button/LED control

All sims use Vivado XSim. Run via `sim/run_simulation.tcl`.

### KiCad Project

`kicad/` contains a companion PCB project — a display + rotary encoder expansion module (ST7789 LCD, SOT-23 transistors, passive components). This is a separate hardware module, not part of the FPGA bitstream. The KiCad MCP server is configured in `.mcp.json`.

### Git Conventions

- Branch: `main` (stable) → `dev` (active development)
- Commit types: `feat`, `fix`, `docs`, `refactor`, `chore`
- Never commit: `.runs/`, `.cache/`, `.sim/`, `.gen/`, `.bit`, `.wcfg`, `.Xil/`
- Vivado IP: keep `.xci` files, ignore generated outputs

### Critical Constraints

1. **Vivado 2024.1 only** — newer versions lack 7-series JESD204 IP
2. **Short ASCII paths** — Vivado silently fails on long/Chinese paths
3. **JESD204 IP requires license** — `trial.lic` at `%APPDATA%\XilinxLicense\`
4. **CFGMCLK from STARTUPE2** — the system MMCM is clocked from the FPGA's internal 65MHz configuration clock, not the 100MHz board clock
5. **TX-only design** — this is a pure AWG/signal-generation project. The competition problem does NOT require ADC. No signal acquisition needed.
