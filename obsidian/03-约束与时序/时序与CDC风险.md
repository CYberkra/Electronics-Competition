---
type: timing
updated: 2026-05-06
tags:
  - timing
  - cdc
  - reset
---

# 时序与 CDC 风险

## 当前 routed timing

报告：

```text
D:\FPGA\ad9144_bringup_k325t\vivado\top_direct_timing_routed.rpt
```

结果：

```text
WNS = -3.157 ns
TNS = -235.311 ns
Timing constraints are not met
```

这不是 `write_bitstream` 失败原因。当前 bitstream 失败是 JESD204 IP license。时序问题仍然必须在 license 解锁后处理。

## 已观察到的风险路径

| 类型 | 例子 | 处理方向 |
|---|---|---|
| reset fanout | `rst_module_inst/o_mod1_rstn` 到多个域 | reset 同步释放、分域 reset |
| debug/ILA path | ILA probe paths | 降低 debug 采样域压力或加约束 |
| cross clock | `clk_out1_clk_sys_mmcm` 到 `clk_out*_clk_for_glbclk` | 明确 CDC，必要时 false path/async groups |
| SYSREF/同步输入 | `sysref_p` 到 JESD/ILA | 确认输入延迟和采样域 |

## 不建议的做法

- 不要为了强行出 bit 直接把所有 DRC/时序降级为 Warning。
- 不要对未理解的跨时钟路径大面积 `set_false_path`。
- 不要把 reset 当作普通同步数据直接跨多个时钟域。

## 推荐处理顺序

1. license 解锁并能进入 bitstream 阶段后，再做 timing cleanup。
2. 用 `report_timing_summary` 找最坏路径分组。
3. 把 reset 按目标时钟域同步释放。
4. 对 ILA/debug 路径单独判断是否需要重采样或调低采样时钟。
5. 对已证明为异步无关的路径加明确约束。

