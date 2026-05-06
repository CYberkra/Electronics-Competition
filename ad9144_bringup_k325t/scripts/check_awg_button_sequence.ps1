$ErrorActionPreference = 'Stop'

$topPath = 'D:\FPGA\ad9144_bringup_k325t\variants\awg_button\top.v'
$text = Get-Content -LiteralPath $topPath -Raw

$matches = [regex]::Matches($text, "3'd(?<sel>\d+):\s+sample_step_from_sel\s+=\s+7'd(?<step>\d+);")
if ($matches.Count -eq 0) {
    throw "No sample_step_from_sel entries found in $topPath"
}

$steps = @{}
foreach ($m in $matches) {
    $steps[[int]$m.Groups['sel'].Value] = [int]$m.Groups['step'].Value
}

foreach ($sel in 0..6) {
    if (-not $steps.ContainsKey($sel)) {
        throw "Missing frequency selection $sel in sample_step_from_sel"
    }
}

if ($text -notmatch "freq_sel\s+<=\s+3'd4;") {
    throw "Default freq_sel is not 3'd4; default output should stay near the known-good 50 MHz setting"
}

function Add-Mod100([int]$a, [int]$b) {
    return ($a + $b) % 100
}

foreach ($sel in 0..6) {
    $step = $steps[$sel]
    $addr = 0
    $sequence = New-Object System.Collections.Generic.List[int]

    foreach ($beat in 0..7) {
        $a0 = $addr
        $a1 = Add-Mod100 $a0 $step
        $a2 = Add-Mod100 $a1 $step
        $a3 = Add-Mod100 $a2 $step
        $sequence.Add($a0)
        $sequence.Add($a1)
        $sequence.Add($a2)
        $sequence.Add($a3)
        $addr = Add-Mod100 $addr (4 * $step)
    }

    for ($i = 0; $i -lt ($sequence.Count - 1); $i++) {
        $delta = ($sequence[$i + 1] - $sequence[$i] + 100) % 100
        if ($delta -ne $step) {
            throw "Selection $sel has discontinuous sample spacing at index $i`: $($sequence[$i]) -> $($sequence[$i + 1]), expected step $step"
        }
    }
}

$defaultStep = $steps[4]
if ($defaultStep -ne 5) {
    throw "Default frequency selection 4 maps to step $defaultStep, expected step 5 for about 50 MHz"
}

Write-Host "AWG button ROM sequence check PASS"
