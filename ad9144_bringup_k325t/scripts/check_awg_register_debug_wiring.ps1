$ErrorActionPreference = 'Stop'

$rootPath = 'D:\FPGA\ad9144_bringup_k325t'
$topPath = Join-Path $rootPath 'variants\awg_button\top.v'
$regPath = Join-Path $rootPath 'rtl\awg\ad9144_awg_reg_bank.v'
$buildDebugPath = Join-Path $rootPath 'scripts\build_awg_button_debug.tcl'
$captureDebugPath = Join-Path $rootPath 'scripts\capture_awg_button_debug.tcl'

foreach ($path in @($topPath, $regPath, $buildDebugPath, $captureDebugPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}

$topText = Get-Content -LiteralPath $topPath -Raw
$regText = Get-Content -LiteralPath $regPath -Raw
$buildText = Get-Content -LiteralPath $buildDebugPath -Raw
$captureText = Get-Content -LiteralPath $captureDebugPath -Raw

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

foreach ($pattern in @(
    'module\s+ad9144_awg_reg_bank',
    'ADDR_CONTROL\s+=\s+8''h08',
    'ADDR_PHASE_INC_LO\s+=\s+8''h10',
    'ADDR_PHASE_OFFSET_LO\s+=\s+8''h18',
    'ADDR_AMPLITUDE\s+=\s+8''h20',
    'ADDR_WAVE_MODE\s+=\s+8''h28',
    'CORE_ID\s+=\s+32''h41574731',
    'control_reg\s+<=\s+32''h00000001;',
    'phase_inc\s+<=\s+48''h0CCCCCCCCCCD;',
    'amplitude_q15\s+<=\s+16''h6000;'
)) {
    Require-Match $regText $pattern "Missing register bank pattern: $pattern"
}

foreach ($pattern in @(
    'ad9144_awg_reg_bank\s+u_ad9144_awg_reg_bank',
    '\.cfg_wr_en\s*\(\s*1''b0\s*\)',
    '\.cfg_rd_en\s*\(\s*1''b0\s*\)',
    'wire\s+\[47:0\]\s+phase_inc\s+=\s+awg_reg_use_control\s+\?\s+awg_reg_phase_inc\s+:\s+key_phase_inc;',
    'wire\s+\[15:0\]\s+amp_q15\s+=\s+awg_reg_use_control\s+\?\s+awg_reg_amplitude_q15\s+:\s+key_amp_q15;',
    'wire\s+\[1:0\]\s+wave_mode\s+=\s+awg_reg_use_control\s+\?\s+awg_reg_wave_mode\s+:\s+key_wave_mode;',
    'assign\s+w_tx_tdata\s+=\s+awg_reg_output_enable\s+\?\s+awg_tx_tdata\s+:\s+128''d0;',
    'mark_debug\s*=\s*"true".*awg_debug_ctrl',
    'mark_debug\s*=\s*"true".*awg_debug_samples',
    'mark_debug\s*=\s*"true".*awg_debug_tdata_lo',
    'mark_debug\s*=\s*"true".*awg_debug_tdata_hi',
    'mark_debug\s*=\s*"true".*awg_debug_phase_inc',
    'mark_debug\s*=\s*"true".*awg_debug_phase_offset'
)) {
    Require-Match $topText $pattern "Missing top-level register/debug pattern: $pattern"
}

foreach ($pattern in @(
    'create_debug_core\s+awg_button_ila\s+ila',
    'top_awg_button_debug\.bit',
    'top_awg_button_debug\.ltx',
    '\*awg_debug_ctrl\*',
    '\*awg_debug_samples\*',
    '\*awg_debug_tdata_lo\*',
    '\*awg_debug_tdata_hi\*'
)) {
    Require-Match $buildText $pattern "Missing debug build pattern: $pattern"
}

foreach ($pattern in @(
    'top_awg_button_debug\.bit',
    'top_awg_button_debug\.ltx',
    'awg_button_debug_',
    'write_hw_ila_data\s+-force\s+-csv_file'
)) {
    Require-Match $captureText $pattern "Missing debug capture pattern: $pattern"
}

Write-Host 'AD9144 AWG register/debug wiring check PASS'
