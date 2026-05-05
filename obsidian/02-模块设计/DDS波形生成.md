# DDS 波形生成

## 两种实现路线

| 路线 | 当前状态 | 文件 | 特点 |
|---|---|---|---|
| **Xilinx IP** | ✅ 工程已接入 | `rtl/dds/dds_compiler_wrapper.v` | 48bit phase, 即用即稳 |
| **手写 NCO** | ✅ 仿真通过, ⏳ 未接入工程 | `rtl/dds/dds_nco.v` + `sine_lut.v` | 64bit phase, 更高分辨率 |

## 手写 DDS 架构 (目标方案)

```
┌─────────────────────────────────────────────────────────────┐
│                        dds_nco.v                             │
│  parameter PHASE_W = 64, ADDR_W = 12, DATA_W = 16           │
│                                                              │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │ phase_inc   │───→│  phase_acc      │───→│ addr[11:0]  │ │
│  │ (64bit)     │    │  64bit累加器     │    │ LUT地址     │ │
│  └─────────────┘    └─────────────────┘    └─────────────┘ │
│         ↑                                              ↓    │
│  ┌─────────────┐                              ┌─────────────┐│
│  │phase_offset │                              │  sine_lut   ││
│  │ (64bit)     │                              │ 4096×16bit  ││
│  └─────────────┘                              │ 1/4周期存储 ││
│                                                └─────────────┘│
│                                                       ↓       │
│                                                ┌─────────────┐│
│                                                │ sample[15:0]││
│                                                │ 有符号16bit  ││
│                                                └─────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 频率分辨率

```
分辨率 = f_clk / 2^PHASE_W

48bit (Xilinx IP) @ 100MHz:
    = 100,000,000 / 2^48
    = 100,000,000 / 281,474,976,710,656
    ≈ 0.355 nHz
    
64bit (手写 NCO) @ 5GSa/s:
    = 5,000,000,000 / 2^64
    ≈ 2.71 × 10^-10 Hz
    
竞赛要求 1mHz → 48bit 完全满足，64bit 是架构灵活性考虑
```

## 波形类型

`wave_shape_gen.v` 支持：

| 波形 | 生成方式 | 特点 |
|---|---|---|
| **正弦** | LUT 查表 | 标准 DDS 输出，THD 取决于 LUT 深度 |
| **方波** | MSB(phase_acc) | 最简单，谐波丰富 |
| **三角波** | 地址镜像 | phase[MSB-1] 决定斜率方向 |
| **锯齿波** | 直接输出地址 | 线性 ramp |
| **任意波** | BRAM/DDR3 回放 | 用户上传波形表 |

## 关键频率参数

### 当前教学DAC版本 (100M clk)

| 目标频率 | phase_inc (48bit hex) |
|---|---|
| 1 Hz | `48'h0000000002AF31` |
| 1 MHz | `48'h28f5c28f5c2` |
| 2 MHz | `48'h51eb851eb84` |
| 10 MHz | `48'h19999999999` |

### FMC版本目标 (250M link clock / 500M DACCLK)

```
f_out = phase_inc × f_dac / 2^64

10 MHz @ 500MHz DACCLK:
    phase_inc = 10M × 2^64 / 500M
              ≈ 64'h0CCCCCCCCCCCCCCD
```

## 接口兼容性

手写 DDS 设计为 **drop-in replacement** for `dds_compiler_wrapper`：

```verilog
// 相同接口，上层无需改动
dds_compiler_wrapper dds_inst (
    .clk       (clk),
    .rst_n     (rst_n),
    .freq_load (freq_load),
    .phase_inc (phase_inc),
    .sine_out  (sine_out),
    .out_valid (out_valid)
);
```

## 已知问题

- `wave_shape_gen.v` 方波测试在 256 拍窗口内 `peak_min` 捕获问题
  - 原因: 统计周期不足
  - 解决: testbench 延长观察周期或放宽预期
- `amp_offset_scale.v` `amplitude=0x7FFF` 时存在 ±1 截断误差
  - 原因: 定点乘法舍入
  - 解决: testbench 已放宽容差
