$ErrorActionPreference = 'Stop'

$topPath = 'D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v'
$ddsPath = 'D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_awg_dds4.v'
$packerPath = 'D:\FPGA\ad9144_bringup_k325t\rtl\awg\ad9144_sample_packer.v'
$topText = Get-Content -LiteralPath $topPath -Raw
$ddsText = Get-Content -LiteralPath $ddsPath -Raw
$packerText = Get-Content -LiteralPath $packerPath -Raw

$phaseMatches = [regex]::Matches($topText, "3'd(?<sel>\d+):\s+phase_inc_from_sel\s+=\s+48'h(?<hex>[0-9A-Fa-f]+);")
if ($phaseMatches.Count -eq 0) {
    throw "No phase_inc_from_sel entries found in $topPath"
}

$expectedPhaseInc = @{
    0 = '028F5C28F5C3'
    1 = '051EB851EB85'
    2 = '07AE147AE148'
    3 = '0A3D70A3D70A'
    4 = '0CCCCCCCCCCD'
    5 = '147AE147AE14'
    6 = '19999999999A'
}

foreach ($sel in 0..6) {
    if ($topText -notmatch "3'd$($sel):\s+phase_inc_from_sel\s+=\s+48'h") {
        throw "Missing frequency selection $sel in phase_inc_from_sel"
    }
}

foreach ($entry in $expectedPhaseInc.GetEnumerator()) {
    $pattern = "3'd$($entry.Key):\s+phase_inc_from_sel\s+=\s+48'h(?<hex>[0-9A-Fa-f]+);"
    $m = [regex]::Match($topText, $pattern)
    if (-not $m.Success) {
        throw "Missing phase increment entry for selection $($entry.Key)"
    }
    if ($m.Groups['hex'].Value.ToUpperInvariant() -ne $entry.Value) {
        throw "Selection $($entry.Key) maps to $($m.Groups['hex'].Value), expected $($entry.Value)"
    }
}

$expectedPhaseOffset = @{
    0 = '000000000000'
    1 = '200000000000'
    2 = '400000000000'
    3 = '800000000000'
    4 = 'C00000000000'
}

foreach ($entry in $expectedPhaseOffset.GetEnumerator()) {
    $pattern = "3'd$($entry.Key):\s+phase_offset_from_sel\s+=\s+48'h(?<hex>[0-9A-Fa-f]+);"
    $m = [regex]::Match($topText, $pattern)
    if (-not $m.Success) {
        throw "Missing phase offset entry for selection $($entry.Key)"
    }
    if ($m.Groups['hex'].Value.ToUpperInvariant() -ne $entry.Value) {
        throw "Selection $($entry.Key) maps to $($m.Groups['hex'].Value), expected $($entry.Value)"
    }
}

if ($topText -notmatch "freq_sel\s+<=\s+3'd4;") {
    throw "Default freq_sel is not 3'd4; default output should stay near the known-good 50 MHz setting"
}

if ($topText -notmatch "phase_sel\s+<=\s+3'd0;") {
    throw "Default phase_sel is not 3'd0"
}

foreach ($needle in @(
    'ad9144_awg_dds4 u_ad9144_awg_dds4',
    'ad9144_sample_packer u_ad9144_sample_packer',
    '.phase_inc     (phase_inc)',
    '.phase_offset  (phase_offset)',
    '.wave_mode     (wave_mode)',
    '.amplitude_q15 (amp_q15)',
    '.sample0       (awg_sample0)',
    '.sample3       (awg_sample3)',
    '.tx_tdata(w_tx_tdata)'
)) {
    if ($topText -notmatch [regex]::Escape($needle)) {
        throw "Missing expected wiring: $needle"
    }
}

foreach ($pattern in @(
    'reg\s*\[1:0\]\s+wave_sel\s*;',
    'wire\s*\[1:0\]\s+wave_mode\s*=\s*wave_sel\s*;',
    "if\(ui_mode == 2'd3\)",
    "2'd3:\s+wave_sel\s+<="
)) {
    if ($topText -notmatch $pattern) {
        throw "Missing waveform UI wiring pattern: $pattern"
    }
}

if ($ddsText -notmatch 'parameter INIT_FILE\s*=\s*"D:/FPGA/ad9144_bringup_k325t/rtl/awg/ad9144_sine_4096.hex"') {
    throw "DDS module is not pointing at the expected sine table"
}

foreach ($pattern in @(
    'input\s+wire\s+\[1:0\]\s+wave_mode',
    'function\s+signed\s+\[15:0\]\s+shape_from_addr',
    'function\s+signed\s+\[15:0\]\s+select_raw_sample',
    "2'd1:\s+shape_from_addr\s+=\s+addr\[11\]\s+\?",
    "2'd2:\s+begin",
    "2'd3:\s+begin"
)) {
    if ($ddsText -notmatch $pattern) {
        throw "Missing waveform generator pattern: $pattern"
    }
}

if ($packerText -notmatch '(?s)sample3\[7:0\].*sample2\[7:0\].*sample1\[7:0\].*sample0\[7:0\].*sample3\[15:8\].*sample2\[15:8\].*sample1\[15:8\].*sample0\[15:8\]') {
    throw "Sample packer bit order does not match the AD9144 vendor format"
}

Write-Host "AWG button DDS4 wiring check PASS"
