param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\assets\audio\sfx")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sampleRate = 22050
$pi = [Math]::PI
$rng = [System.Random]::new(1337)

function Clamp-Sample([double]$value) {
    if ($value -gt 1.0) { return 1.0 }
    if ($value -lt -1.0) { return -1.0 }
    return $value
}

function Quantize-Sample([double]$value, [int]$steps = 48) {
    return [Math]::Round((Clamp-Sample $value) * $steps) / $steps
}

function Envelope([double]$time, [double]$duration, [double]$attack = 0.005, [double]$release = 0.05) {
    if ($time -lt 0.0 -or $time -gt $duration) {
        return 0.0
    }

    $attackFactor = 1.0
    if ($attack -gt 0.0 -and $time -lt $attack) {
        $attackFactor = $time / $attack
    }

    $releaseFactor = 1.0
    $releaseStart = $duration - $release
    if ($release -gt 0.0 -and $time -gt $releaseStart) {
        $releaseFactor = ($duration - $time) / $release
    }

    return [Math]::Max(0.0, [Math]::Min($attackFactor, $releaseFactor))
}

function Write-Wav([string]$path, [double[]]$samples, [int]$rate) {
    $directory = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $bytesPerSample = 2
    $subchunk2Size = $samples.Length * $bytesPerSample
    $chunkSize = 36 + $subchunk2Size
    $byteRate = $rate * $bytesPerSample

    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $writer = New-Object System.IO.BinaryWriter($stream)
        try {
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
            $writer.Write([int]$chunkSize)
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
            $writer.Write([int]16)
            $writer.Write([int16]1)
            $writer.Write([int16]1)
            $writer.Write([int]$rate)
            $writer.Write([int]$byteRate)
            $writer.Write([int16]$bytesPerSample)
            $writer.Write([int16]16)
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
            $writer.Write([int]$subchunk2Size)

            foreach ($sample in $samples) {
                $pcm = [int16]([Math]::Round((Clamp-Sample $sample) * 32767.0))
                $writer.Write($pcm)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-SampleBuffer([double]$duration) {
    return New-Object double[] ([int]([Math]::Ceiling($duration * $sampleRate)))
}

function Add-NoiseBurst([double[]]$buffer, [double]$volume, [double]$filterMix = 0.2) {
    $smoothed = 0.0
    for ($i = 0; $i -lt $buffer.Length; $i++) {
        $white = ($rng.NextDouble() * 2.0) - 1.0
        $smoothed = ($smoothed * (1.0 - $filterMix)) + ($white * $filterMix)
        $buffer[$i] += $smoothed * $volume
    }
}

function Build-EngineLoop {
    $duration = 1.0
    $samples = New-SampleBuffer $duration

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $t = $i / $sampleRate
        $rotor = 0.30 * [Math]::Sin(2.0 * $pi * 54.0 * $t)
        $body = 0.22 * [Math]::Sin(2.0 * $pi * 108.0 * $t + 0.5)
        $buzz = 0.10 * [Math]::Sign([Math]::Sin(2.0 * $pi * 216.0 * $t))
        $whirr = 0.10 * [Math]::Sin(2.0 * $pi * 324.0 * $t)
        $bladeChop = 0.68 + (0.24 * [Math]::Sin(2.0 * $pi * 8.0 * $t))
        $sample = ($rotor + $body + $buzz + $whirr) * $bladeChop
        $samples[$i] = Quantize-Sample $sample 56
    }

    return $samples
}

function Build-PlayerMissileFire {
    $duration = 0.22
    $samples = New-SampleBuffer $duration

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $t = $i / $sampleRate
        $progress = $t / $duration
        $freq = 1320.0 - (940.0 * $progress)
        $square = 0.60 * [Math]::Sign([Math]::Sin(2.0 * $pi * $freq * $t))
        $tone = 0.18 * [Math]::Sin(2.0 * $pi * ($freq * 0.5) * $t)
        $sample = ($square + $tone) * ([Math]::Pow(1.0 - $progress, 1.7))
        $sample *= Envelope $t $duration 0.002 0.045
        $samples[$i] = Quantize-Sample $sample 40
    }

    return $samples
}

function Build-ReloadChirp {
    $duration = 0.18
    $samples = New-SampleBuffer $duration

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $t = $i / $sampleRate
        $progress = $t / $duration
        $freq = 420.0 + (680.0 * $progress)
        $pulseA = [Math]::Sin(2.0 * $pi * $freq * $t)
        $pulseB = 0.55 * [Math]::Sin(2.0 * $pi * ($freq * 1.5) * $t)
        $gate = if ($progress -lt 0.48) { 1.0 } else { 0.78 }
        $sample = ($pulseA + $pulseB) * 0.34 * $gate
        $sample *= Envelope $t $duration 0.003 0.04
        $samples[$i] = Quantize-Sample $sample 44
    }

    return $samples
}

function Build-EnemyMissileFire {
    $duration = 0.20
    $samples = New-SampleBuffer $duration

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $t = $i / $sampleRate
        $progress = $t / $duration
        $freq = 780.0 - (500.0 * $progress)
        $triangle = [Math]::Asin([Math]::Sin(2.0 * $pi * $freq * $t)) * (2.0 / $pi)
        $undertone = 0.30 * [Math]::Sin(2.0 * $pi * 180.0 * $t)
        $sample = ($triangle * 0.62 + $undertone * 0.22) * ([Math]::Pow(1.0 - $progress, 1.4))
        if ($progress -gt 0.42 -and $progress -lt 0.58) {
            $sample *= 0.7
        }
        $sample *= Envelope $t $duration 0.002 0.055
        $samples[$i] = Quantize-Sample $sample 36
    }

    return $samples
}

function Build-Explosion {
    $duration = 0.72
    $samples = New-SampleBuffer $duration
    $noiseState = 0.0

    for ($i = 0; $i -lt $samples.Length; $i++) {
        $t = $i / $sampleRate
        $progress = $t / $duration
        $white = ($rng.NextDouble() * 2.0) - 1.0
        $noiseState = ($noiseState * 0.82) + ($white * 0.18)
        $boomFreq = 96.0 - (52.0 * $progress)
        $boom = 0.42 * [Math]::Sin(2.0 * $pi * $boomFreq * $t)
        $crackle = $noiseState * (0.85 - ($progress * 0.7))
        $sample = ($boom + $crackle * 0.75) * ([Math]::Pow(1.0 - $progress, 1.3))
        $sample *= Envelope $t $duration 0.001 0.16
        $samples[$i] = Quantize-Sample $sample 32
    }

    return $samples
}

$enginePath = Join-Path $OutputDir "helicopter_loop.wav"
$playerFirePath = Join-Path $OutputDir "player_missile_fire.wav"
$reloadPath = Join-Path $OutputDir "missile_reload_retro.wav"
$enemyFirePath = Join-Path $OutputDir "enemy_missile_fire.wav"
$deathPath = Join-Path $OutputDir "death.wav"

Write-Wav $enginePath (Build-EngineLoop) $sampleRate
Write-Wav $playerFirePath (Build-PlayerMissileFire) $sampleRate
Write-Wav $reloadPath (Build-ReloadChirp) $sampleRate
Write-Wav $enemyFirePath (Build-EnemyMissileFire) $sampleRate
Write-Wav $deathPath (Build-Explosion) $sampleRate

Write-Host "Generated retro SFX in $OutputDir"
