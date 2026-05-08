# AD9144 4x插值配置说明

## 重要纠正

**此前的理解有误：插值模式不改变DAC最高输出采样率，而是改变FPGA向DAC输入数据的速率。**

AD9144在所有插值模式（1x/2x/4x/8x）下，DAC输出采样率最高均为**2.8 GSPS**。插值的作用是在DAC内部进行上采样，从而降低FPGA需要提供的输入数据率。

## 修改内容

将AD9144从2x插值改为4x插值，以降低FPGA输入数据率，使JESD204 lane rate更容易满足K325T GTX的线速率要求。

## 修改的寄存器

### 寄存器 0x112 - Interpolation Mode

**原配置（2x插值）：**
```verilog
WR_STA_42  : begin r_wr_infodata <= {1'b0,15'h112, 8'h01};  end   // Interpolation 2x
```

**新配置（4x插值）：**
```verilog
WR_STA_42  : begin r_wr_infodata <= {1'b0,15'h112, 8'h03};  end   // Interpolation 4x
```

## 影响分析

### 数据率变化

| 参数 | 2x插值 | 4x插值 | 说明 |
|------|--------|--------|------|
| **DAC输出采样率** | **2.8 GSPS** | **2.8 GSPS** | DAC最高输出，与插值模式无关 |
| FPGA输入数据率 | 1.4 GSPS | 0.7 GSPS | 2.8G / interpolation |
| JESD204 lane rate (4 lanes) | ~5 Gbps | ~7 Gbps | lane_rate = 1.25 × data_rate/lanes × 10/8 |

**注意：** 4 lanes @ ~7 Gbps 在K325T GTX支持范围内（GTX最高12.5 Gbps/lane）。

### 为什么选4x？

1. **降低FPGA数据率**：从1.4 GSPS降到0.7 GSPS，减轻FPGA内部时序压力
2. **JESD204 lane rate适中**：7 Gbps在GTX舒适区（5-10 Gbps）
3. **保留2.8 GSPS DAC输出**：满足赛题采样率要求（≥5 GSa/s需双通道交织或说明单芯片极限）

## 单芯片采样率说明

AD9144为双通道16-bit DAC，单通道最高2.8 GSPS。

**双通道交织**（IQ模式或交替采样）理论上可达5.6 GSPS，但需要：
- 硬件支持双通道同时输出同相波形
- 外部模拟合路器（功率合成器）
- 额外的相位校准

当前项目使用单通道输出，实际DAC采样率为2.8 GSPS。对于赛题要求的≥5 GSa/s，建议：
1. 与组委会沟通，说明采用单芯片2.8 GSPS + 高分辨率（16bit）的优势
2. 或评估双通道交织方案的可行性

## 验证步骤

1. ✅ 修改SPI配置（已完成：0x112 = 0x03）
2. 修改JESD204 IP配置（lane rate从5 Gbps调整到7 Gbps）
3. 重新生成bitstream
4. 烧录测试
5. 用示波器验证输出波形频率正确（DAC采样率仍为2.8 GSPS，波形频率由DDS phase_inc决定）

## 回退方案

如果4x插值遇到问题，可以回退到2x插值：
```verilog
WR_STA_42  : begin r_wr_infodata <= {1'b0,15'h112, 8'h01};  end   // Interpolation 2x
```

---
**修改日期**：2026-05-08
**修改者**：Sisyphus Agent
**更正说明**：2026-05-08 纠正了"4x插值提升DAC采样率"的错误理解。DAC输出采样率在所有插值模式下最高均为2.8 GSPS。
