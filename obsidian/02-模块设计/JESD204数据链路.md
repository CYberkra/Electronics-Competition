# JESD204 数据链路

## 链路建立四步法

```
Step 1: LMK04828 配置时钟
    └── 输出 125M REFCLK + 500M DACCLK + 3.90625M SYSREF

Step 2: AD9144 SPI 初始化
    └── 配置 SPI 接口 → JESD204 模式 (L=4, F=1, K=32, M=2)
    └── 使能 DAC0 → 释放 RESET

Step 3: FPGA JESD204 IP 建链
    └── 等待 AD9144 SYNC~ 拉低 (请求同步)
    └── CGS (Code Group Sync) → ILAS → 数据传输

Step 4: FPGA 发送波形数据
    └── DDS NCO → Transport Layer → Link Layer → GTX PHY
```

## Xilinx JESD204 IP 结构 (Vivado 2024.1)

```
┌────────────────────────────────────────────────────────────┐
│                     jesd204_tx_ad9144                       │
│  (xilinx.com:ip:jesd204 v7.2)                              │
│                                                             │
│  ┌─────────────────┐   ┌─────────────────┐   ┌──────────┐ │
│  │ Transport Layer │ → │  Link Layer     │ → │ PHY      │ │
│  │ (数据映射)       │   │ (8B/10B+对齐)   │   │ (GTX×4)  │ │
│  │                 │   │                 │   │          │ │
│  │ M=2 converters  │   │ L=4 lanes       │   │ 10Gbps   │ │
│  │ F=1 octet/frame │   │ K=32 frames/MF  │   │ per lane │ │
│  │ S=1 sample/conv │   │ Subclass 1      │   │          │ │
│  │ NP=16 bits      │   │ Scrambling ON   │   │          │ │
│  └─────────────────┘   └─────────────────┘   └──────────┘ │
│           ↑                        ↑              ↑        │
│     sample/data              sync~ / sysref    txp/txn     │
└────────────────────────────────────────────────────────────┘
```

## 关键参数

| 参数 | 值 | 说明 |
|---|---|---|
| L | 4 | 使用 DP0~DP3 四路差分 |
| M | 2 | DAC0 + DAC1 (可扩展为4) |
| F | 1 | 每帧每lane 1 byte |
| K | 32 | 每个 multiframe 32 frames |
| S | 1 | 每converter每frame 1 sample |
| NP | 16 | 每个 sample 16bit |
| Lane Rate | 10 Gbps | M×S×NP×(10/8)×(1/L)×sample_rate |
| Subclass | 1 | 使用 SYSREF 实现确定性延迟 |
| Scrambling | Enabled | 降低 EMI，改善误码率 |

## lane rate 计算验证

```
sample_rate = 250 MHz (interpolation = 1, DACCLK = 500M / 2 = 250M)
lane_rate = M × S × NP × (10/8) × (1/L) × sample_rate
          = 2 × 1 × 16 × 1.25 × (1/4) × 250M
          = 2.5 Gbps per lane (minimum)

实际配置: 10 Gbps per lane (过采样或更高 interpolation)
```

## 接口信号

### JESD204 TX → FPGA Top

```verilog
// 来自 LMK04828
input  wire gtx_refclk_p, gtx_refclk_n;   // 125M
input  wire sysref_p, sysref_n;           // 3.90625M

// 来自 AD9144 (SYNC~)
input  wire syncn;                         // Active low, LMFC同步请求

// 到 AD9144 (高速差分)
output wire [3:0] txp, txn;               // 4 lane JESD204 data

// 到 DDS/Transport
input  wire [31:0] tx_data;               // 2 converters × 16bit
input  wire        tx_valid;
output wire        tx_ready;
```

## 建链状态机

```
FPGA Reset
    ↓
等待 LMK locked (SPI done)
    ↓
等待 AD9144 SPI done
    ↓
JESD204 IP Reset Release
    ↓
CGS (Code Group Sync)
    └── 发送 K28.5 字符，等待 AD9144 SYNC~ 拉高
    ↓
ILAS (Initial Lane Alignment Sequence)
    └── 发送 /R/ /A/ /Q/ 序列，对齐各 lane
    ↓
User Data Phase
    └── SYNC~ 拉高，开始传输波形数据
    └── LED0 = 建链成功指示
```

## 已知问题

- Vivado 2024.2 **不支持** 7 系列 JESD204 IP（已确认 AR#000036844）
- 必须使用 **Vivado 2024.1**
- IP 版本: `xilinx.com:ip:jesd204:7.2`

## 参考文件

- IP 创建脚本: `scripts/vivado2024.1/create_jesd204_tx_ip.tcl`
- 约束文件: `constraints/fmc_adda.xdc`
- AD9144  datasheet: `D:\FPGA\FMCADDA-9250-9144\AD9144*.pdf`
