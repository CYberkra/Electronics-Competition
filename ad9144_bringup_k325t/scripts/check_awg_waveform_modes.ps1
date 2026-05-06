$ErrorActionPreference = 'Stop'

$rootPath = 'D:\FPGA\ad9144_bringup_k325t'
$topPath = Join-Path $rootPath 'variants\awg_button\top.v'
$ddsPath = Join-Path $rootPath 'rtl\awg\ad9144_awg_dds4.v'
$packerPath = Join-Path $rootPath 'rtl\awg\ad9144_sample_packer.v'
$sinePath = Join-Path $rootPath 'rtl\awg\ad9144_sine_4096.hex'
$bitPath = Join-Path $rootPath 'vivado_awg_button\top_awg_button.bit'

function Require-Match {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )
    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Require-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )
    if (-not $Text.Contains($Needle)) {
        throw $Message
    }
}

function Get-ShapeSample {
    param(
        [int]$Mode,
        [int]$Addr
    )

    switch ($Mode) {
        1 {
            if (($Addr -band 0x800) -ne 0) { return -32768 }
            return 32767
        }
        2 {
            $halfAddr = $Addr -band 0x7ff
            if (($Addr -band 0x800) -ne 0) {
                $triUnsigned = 2047 - $halfAddr
            } else {
                $triUnsigned = $halfAddr
            }
            return (($triUnsigned - 1024) -shl 5)
        }
        3 {
            return (($Addr - 2048) -shl 4)
        }
        default {
            return 0
        }
    }
}

foreach ($path in @($topPath, $ddsPath, $packerPath, $sinePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}

$topText = Get-Content -LiteralPath $topPath -Raw
$ddsText = Get-Content -LiteralPath $ddsPath -Raw
$packerText = Get-Content -LiteralPath $packerPath -Raw
$sineLines = Get-Content -LiteralPath $sinePath | Where-Object {
    $line = $_.Trim()
    $line -ne '' -and $line -notmatch '^(//|#)'
}

if ($sineLines.Count -ne 4096) {
    throw "Sine table entry count is $($sineLines.Count), expected 4096"
}

$badSine = $sineLines | Where-Object { $_.Trim() -notmatch '^[0-9A-Fa-f]{4}$' } | Select-Object -First 1
if ($badSine) {
    throw "Sine table contains a non-16-bit-hex entry: $badSine"
}

foreach ($pattern in @(
    'reg\s*\[1:0\]\s+ui_mode\s*;',
    'reg\s*\[1:0\]\s+wave_sel\s*;',
    'wire\s*\[1:0\]\s+key_wave_mode\s+=\s+wave_sel\s*;',
    'wire\s*\[1:0\]\s+wave_mode\s+=\s+awg_reg_use_control\s+\?\s+awg_reg_wave_mode\s+:\s+key_wave_mode\s*;',
    "ui_mode\s+<=\s+2'd1;",
    "wave_sel\s+<=\s+2'd0;",
    "freq_sel\s+<=\s+3'd4;",
    "amp_sel\s+<=\s+3'd3;",
    "phase_sel\s+<=\s+3'd0;",
    "(?s)if\s*\(\s*ui_mode\s*==\s*2'd3\s*\).*?ui_mode\s+<=\s+2'd0;",
    "2'd3:\s+wave_sel\s+<=\s+wave_sel\s+\+\s+1'b1;",
    "2'd3:\s+wave_sel\s+<=\s+wave_sel\s+-\s+1'b1;",
    'assign\s+led\s*=\s*ui_mode\s*;'
)) {
    Require-Match $topText $pattern "Missing waveform UI pattern: $pattern"
}

foreach ($needle in @(
    'ad9144_awg_dds4 u_ad9144_awg_dds4',
    '.phase_inc     (phase_inc)',
    '.phase_offset  (phase_offset)',
    '.wave_mode     (wave_mode)',
    '.amplitude_q15 (amp_q15)',
    '.sample0       (awg_sample0)',
    '.sample3       (awg_sample3)',
    'ad9144_sample_packer u_ad9144_sample_packer',
    '.tx_tdata(w_tx_tdata)'
)) {
    Require-Contains $topText $needle "Missing expected top-level wiring: $needle"
}

foreach ($pattern in @(
    'input\s+wire\s+\[1:0\]\s+wave_mode',
    'function\s+signed\s+\[15:0\]\s+shape_from_addr',
    'function\s+signed\s+\[15:0\]\s+select_raw_sample',
    "2'd1:\s+shape_from_addr\s+=\s+addr\[11\]\s+\?\s+-16'sd32768\s+:\s+16'sd32767;",
    "2'd2:\s+begin",
    "2'd3:\s+begin",
    "select_raw_sample\s*=\s*\(mode\s*==\s*2'd0\)\s*\?\s*sine_value\s*:\s*shape_value;"
)) {
    Require-Match $ddsText $pattern "Missing waveform generator pattern: $pattern"
}

if ($packerText -notmatch '(?s)sample3\[7:0\].*sample2\[7:0\].*sample1\[7:0\].*sample0\[7:0\].*sample3\[15:8\].*sample2\[15:8\].*sample1\[15:8\].*sample0\[15:8\]') {
    throw 'Sample packer byte order no longer matches the vendor AD9144 format'
}

$shapeChecks = @(
    @{ Mode = 1; Addr = 0;    Expected = 32767  },
    @{ Mode = 1; Addr = 2048; Expected = -32768 },
    @{ Mode = 2; Addr = 0;    Expected = -32768 },
    @{ Mode = 2; Addr = 1024; Expected = 0      },
    @{ Mode = 2; Addr = 2048; Expected = 32736  },
    @{ Mode = 3; Addr = 0;    Expected = -32768 },
    @{ Mode = 3; Addr = 2048; Expected = 0      },
    @{ Mode = 3; Addr = 4095; Expected = 32752  }
)

foreach ($check in $shapeChecks) {
    $actual = Get-ShapeSample -Mode $check.Mode -Addr $check.Addr
    if ($actual -ne $check.Expected) {
        throw "Shape math mismatch: mode=$($check.Mode), addr=$($check.Addr), got=$actual, expected=$($check.Expected)"
    }
}

if (Test-Path -LiteralPath $bitPath) {
    $bit = Get-Item -LiteralPath $bitPath
    Write-Host ("Current bitstream: {0} bytes, LastWriteTime={1:yyyy-MM-dd HH:mm:ss}" -f $bit.Length, $bit.LastWriteTime)
} else {
    Write-Host "Current bitstream is not present at $bitPath"
}

Write-Host 'AD9144 AWG waveform mode check PASS'
