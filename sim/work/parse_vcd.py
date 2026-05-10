#!/usr/bin/env python3
"""Parse VCD file and print ASCII waveform for da_data"""

import re
from collections import defaultdict

def parse_vcd(vcd_path):
    signals = {}      # id -> name
    widths = {}       # id -> bitwidth
    data = defaultdict(list)  # id -> [(time, value), ...]

    with open(vcd_path, 'r') as f:
        lines = f.readlines()

    in_def = False
    current_time = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue

        if line.startswith('$var'):
            # $var wire 8 ! da_data [7:0] $end
            parts = line.split()
            if len(parts) >= 5:
                width = int(parts[2])
                sid = parts[3]
                name = parts[4]
                signals[sid] = name
                widths[sid] = width
        elif line.startswith('#'):
            current_time = int(line[1:])
        elif line.startswith('b') or line.startswith('B'):
            # Binary value: b1010 !
            parts = line.split()
            val_str = parts[0][1:]  # remove 'b'
            sid = parts[1]
            value = int(val_str, 2) if val_str else 0
            data[sid].append((current_time, value))
        elif line.startswith('r') or line.startswith('R'):
            # Real value (skip)
            pass
        elif len(line) >= 2 and line[0] in '01xzXZ' and line[1] != '':
            # Single bit value without space sometimes
            pass
        elif len(line) >= 2 and line[1] in '0123456789abcdefABCDEF':
            # Single bit: 0! or 1!
            # Actually for multi-bit without 'b', it's just value + id
            pass
        else:
            # Try format: value followed by identifier, e.g., "x!" or "z!"
            # For our case da_data is 8bit, so it should have 'b' prefix
            pass

    return signals, widths, data

def main():
    from pathlib import Path
    script_dir = Path(__file__).parent.resolve()
    vcd_path = str(script_dir / "dac_interface_tb.vcd")

    signals, widths, data = parse_vcd(vcd_path)

    # Find da_data signal
    target_sid = None
    for sid, name in signals.items():
        if name == "da_data":
            target_sid = sid
            break

    if not target_sid:
        print("[ERROR] da_data not found in VCD")
        print("Available signals:", list(signals.values()))
        return

    da_data_values = data[target_sid]

    print("=" * 60)
    print("VCD Waveform Analysis for da_data")
    print("=" * 60)
    print(f"Total transitions: {len(da_data_values)}")

    if not da_data_values:
        return

    # Extract unique sample points (at clock edges, roughly every 5ns or 10ns)
    # Filter to one sample per 10ns (100MHz clock period)
    samples = []
    last_t = -1
    for t, v in da_data_values:
        if t >= 0 and (t - last_t) >= 5:  # sample at least 5ns apart
            samples.append((t, v))
            last_t = t

    print(f"Sampled points (≥5ns apart): {len(samples)}")
    print()

    # Print first 20 samples
    print("Time(ns)  da_data  ASCII bar")
    print("-" * 40)

    max_val = 255
    bar_width = 30

    for t, v in samples[:20]:
        bar_len = int(v / max_val * bar_width)
        bar = "#" * bar_len + "-" * (bar_width - bar_len)
        print(f"{t:8}  {v:3}      {bar}")

    print()

    # Check sine-like pattern: should go up then down
    if len(samples) >= 16:
        vals = [v for _, v in samples[:16]]
        print("First 16 samples numeric:")
        print(vals)

        # Check monotonic up to peak
        peak_idx = vals.index(max(vals))
        increasing = all(vals[i] <= vals[i+1] for i in range(peak_idx))
        decreasing = all(vals[i] >= vals[i+1] for i in range(peak_idx, len(vals)-1))

        print()
        if increasing and decreasing:
            print("[PASS] Waveform shows correct sine-like envelope")
            print(f"       Peak at sample {peak_idx}, value={max(vals)}")
        else:
            print("[WARN] Waveform may not be sinusoidal")
            print(f"       Peak at sample {peak_idx}")

if __name__ == "__main__":
    main()
