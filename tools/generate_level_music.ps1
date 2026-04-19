param(
    [string]$OutputDir = 'assets/audio/music/levels',
    [int]$SampleRate = 22050
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetDir = Join-Path $projectRoot $OutputDir
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

function Get-Frequency {
    param(
        [int]$Midi
    )

    return 440.0 * [Math]::Pow(2.0, ($Midi - 69) / 12.0)
}

function Get-WaveSample {
    param(
        [double]$Phase,
        [string]$Wave
    )

    switch ($Wave) {
        'triangle' {
            return (2.0 / [Math]::PI) * [Math]::Asin([Math]::Sin($Phase))
        }
        'square' {
            if ([Math]::Sin($Phase) -ge 0) {
                return 1.0
            }
            return -1.0
        }
        'saw' {
            $wrapped = ($Phase / (2.0 * [Math]::PI)) - [Math]::Floor(($Phase / (2.0 * [Math]::PI)) + 0.5)
            return 2.0 * $wrapped
        }
        default {
            return [Math]::Sin($Phase)
        }
    }
}

function Add-Voice {
    param(
        [double[]]$Samples,
        [double]$Frequency,
        [double]$StartSeconds,
        [double]$DurationSeconds,
        [double]$Amplitude,
        [string]$Wave = 'sine',
        [double]$Attack = 0.02,
        [double]$Release = 0.08,
        [double]$PhaseOffset = 0.0,
        [double]$PitchDrift = 0.0
    )

    $startIndex = [Math]::Max([Math]::Floor($StartSeconds * $SampleRate), 0)
    $endIndex = [Math]::Min([Math]::Ceiling(($StartSeconds + $DurationSeconds) * $SampleRate), $Samples.Length)
    if ($endIndex -le $startIndex) {
        return
    }

    $attackSamples = [Math]::Max([Math]::Floor($Attack * $SampleRate), 1)
    $releaseSamples = [Math]::Max([Math]::Floor($Release * $SampleRate), 1)
    $voiceSamples = [Math]::Max($endIndex - $startIndex, 1)

    for ($index = $startIndex; $index -lt $endIndex; $index++) {
        $voiceIndex = $index - $startIndex
        $time = $voiceIndex / [double]$SampleRate
        $progress = $voiceIndex / [double]$voiceSamples
        $drift = if ($PitchDrift -ne 0.0) { [Math]::Sin(2.0 * [Math]::PI * $progress) * $PitchDrift } else { 0.0 }
        $phase = (2.0 * [Math]::PI * ($Frequency + $drift) * $time) + $PhaseOffset
        $sample = Get-WaveSample -Phase $phase -Wave $Wave
        $envelope = 1.0
        if ($voiceIndex -lt $attackSamples) {
            $envelope = $voiceIndex / [double]$attackSamples
        }
        elseif (($endIndex - $index) -lt $releaseSamples) {
            $envelope = [Math]::Max(0.0, ($endIndex - $index) / [double]$releaseSamples)
        }
        $Samples[$index] += $sample * $Amplitude * $envelope
    }
}

function Add-ChordPad {
    param(
        [double[]]$Samples,
        [int[]]$MidiNotes,
        [double]$StartSeconds,
        [double]$DurationSeconds,
        [double]$Amplitude,
        [string]$Wave = 'triangle'
    )

    foreach ($midi in $MidiNotes) {
        Add-Voice -Samples $Samples -Frequency (Get-Frequency -Midi $midi) -StartSeconds $StartSeconds -DurationSeconds $DurationSeconds -Amplitude ($Amplitude / [Math]::Max($MidiNotes.Count, 1)) -Wave $Wave -Attack 0.12 -Release 0.25 -PitchDrift 0.18
        Add-Voice -Samples $Samples -Frequency (Get-Frequency -Midi ($midi + 12)) -StartSeconds $StartSeconds -DurationSeconds $DurationSeconds -Amplitude ($Amplitude / [Math]::Max($MidiNotes.Count, 1) * 0.35) -Wave 'sine' -Attack 0.08 -Release 0.2
    }
}

function Add-BassPulse {
    param(
        [double[]]$Samples,
        [int]$Midi,
        [double]$StartSeconds,
        [double]$DurationSeconds,
        [double]$BeatSeconds,
        [double]$Amplitude,
        [string]$Wave = 'saw'
    )

    for ($beat = 0; $beat -lt [Math]::Floor($DurationSeconds / $BeatSeconds); $beat++) {
        $beatStart = $StartSeconds + ($beat * $BeatSeconds)
        Add-Voice -Samples $Samples -Frequency (Get-Frequency -Midi $Midi) -StartSeconds $beatStart -DurationSeconds ($BeatSeconds * 0.72) -Amplitude $Amplitude -Wave $Wave -Attack 0.01 -Release 0.12
    }
}

function Add-Arpeggio {
    param(
        [double[]]$Samples,
        [int[]]$MidiNotes,
        [double]$StartSeconds,
        [double]$DurationSeconds,
        [double]$StepSeconds,
        [double]$Amplitude,
        [string]$Wave = 'square'
    )

    $steps = [Math]::Floor($DurationSeconds / $StepSeconds)
    for ($step = 0; $step -lt $steps; $step++) {
        $midi = $MidiNotes[$step % $MidiNotes.Count]
        $voiceStart = $StartSeconds + ($step * $StepSeconds)
        Add-Voice -Samples $Samples -Frequency (Get-Frequency -Midi $midi) -StartSeconds $voiceStart -DurationSeconds ($StepSeconds * 0.86) -Amplitude $Amplitude -Wave $Wave -Attack 0.005 -Release 0.03 -PhaseOffset ([Math]::PI / 8.0)
    }
}

function Add-NoiseHits {
    param(
        [double[]]$Samples,
        [double]$StartSeconds,
        [double]$DurationSeconds,
        [double]$StepSeconds,
        [double]$Amplitude
    )

    $rng = [System.Random]::new(42 + [Math]::Floor($StartSeconds * 100))
    $steps = [Math]::Floor($DurationSeconds / $StepSeconds)
    for ($step = 0; $step -lt $steps; $step++) {
        $hitStart = $StartSeconds + ($step * $StepSeconds)
        $startIndex = [Math]::Floor($hitStart * $SampleRate)
        $length = [Math]::Floor(0.04 * $SampleRate)
        for ($offset = 0; $offset -lt $length; $offset++) {
            $sampleIndex = $startIndex + $offset
            if ($sampleIndex -ge $Samples.Length) {
                break
            }
            $envelope = [Math]::Max(0.0, 1.0 - ($offset / [double]$length))
            $noise = ($rng.NextDouble() * 2.0) - 1.0
            $Samples[$sampleIndex] += $noise * $Amplitude * $envelope
        }
    }
}

function Write-WavFile {
    param(
        [string]$Path,
        [double[]]$Samples
    )

    $peak = 0.0
    foreach ($sample in $Samples) {
        $peak = [Math]::Max($peak, [Math]::Abs($sample))
    }
    $normalizer = if ($peak -gt 0.98) { 0.98 / $peak } else { 1.0 }

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $bitsPerSample = 16
        $channels = 1
        $byteRate = $SampleRate * $channels * ($bitsPerSample / 8)
        $blockAlign = $channels * ($bitsPerSample / 8)
        $dataSize = $Samples.Length * $blockAlign

        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]$channels)
        $writer.Write([int]$SampleRate)
        $writer.Write([int]$byteRate)
        $writer.Write([int16]$blockAlign)
        $writer.Write([int16]$bitsPerSample)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataSize)

        foreach ($sample in $Samples) {
            $value = [Math]::Max(-1.0, [Math]::Min(1.0, $sample * $normalizer))
            $writer.Write([int16][Math]::Round($value * 32767.0))
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Render-Track {
    param(
        [string]$FileName,
        [double]$DurationSeconds,
        [double]$BeatsPerMinute,
        [int[][]]$ChordProgression,
        [int[]]$BassLine,
        [int[]]$LeadPattern,
        [string]$PadWave,
        [string]$LeadWave,
        [string]$BassWave,
        [double]$NoiseAmplitude
    )

    $samples = New-Object double[] ([Math]::Floor($DurationSeconds * $SampleRate))
    $beatSeconds = 60.0 / $BeatsPerMinute
    $sectionDuration = $DurationSeconds / $ChordProgression.Count

    for ($sectionIndex = 0; $sectionIndex -lt $ChordProgression.Count; $sectionIndex++) {
        $sectionStart = $sectionIndex * $sectionDuration
        $chord = $ChordProgression[$sectionIndex]
        $bassMidi = $BassLine[$sectionIndex % $BassLine.Count]
        Add-ChordPad -Samples $samples -MidiNotes $chord -StartSeconds $sectionStart -DurationSeconds $sectionDuration -Amplitude 0.45 -Wave $PadWave
        Add-BassPulse -Samples $samples -Midi $bassMidi -StartSeconds $sectionStart -DurationSeconds $sectionDuration -BeatSeconds $beatSeconds -Amplitude 0.22 -Wave $BassWave
        Add-Arpeggio -Samples $samples -MidiNotes $LeadPattern -StartSeconds $sectionStart -DurationSeconds $sectionDuration -StepSeconds ($beatSeconds / 2.0) -Amplitude 0.08 -Wave $LeadWave
        Add-NoiseHits -Samples $samples -StartSeconds $sectionStart -DurationSeconds $sectionDuration -StepSeconds ($beatSeconds / 2.0) -Amplitude $NoiseAmplitude
    }

    Add-Voice -Samples $samples -Frequency 880.0 -StartSeconds 0.0 -DurationSeconds $DurationSeconds -Amplitude 0.015 -Wave 'sine' -Attack 0.2 -Release 0.2 -PitchDrift 0.35
    Write-WavFile -Path (Join-Path $targetDir $FileName) -Samples $samples
}

Render-Track -FileName 'classic_night_city.wav' -DurationSeconds 16.0 -BeatsPerMinute 108.0 -ChordProgression @(
    @(57, 60, 64), @(53, 57, 60), @(50, 53, 57), @(55, 59, 62), @(57, 60, 64), @(53, 57, 60)
) -BassLine @(33, 29, 26, 31, 33, 29) -LeadPattern @(69, 72, 76, 72, 74, 76, 81, 76) -PadWave 'triangle' -LeadWave 'square' -BassWave 'saw' -NoiseAmplitude 0.016
Render-Track -FileName 'canyon_run.wav' -DurationSeconds 16.0 -BeatsPerMinute 114.0 -ChordProgression @(
    @(50, 57, 62), @(48, 55, 60), @(45, 52, 57), @(43, 50, 55), @(50, 57, 62), @(52, 59, 64)
) -BassLine @(26, 24, 21, 19, 26, 28) -LeadPattern @(74, 76, 79, 81, 79, 76, 74, 72) -PadWave 'saw' -LeadWave 'triangle' -BassWave 'square' -NoiseAmplitude 0.02
Render-Track -FileName 'alien_cavern.wav' -DurationSeconds 16.0 -BeatsPerMinute 92.0 -ChordProgression @(
    @(45, 52, 57), @(47, 54, 59), @(43, 50, 55), @(40, 47, 52), @(45, 52, 57), @(38, 45, 50)
) -BassLine @(21, 23, 19, 16, 21, 14) -LeadPattern @(81, 79, 76, 72, 74, 76, 79, 84) -PadWave 'triangle' -LeadWave 'sine' -BassWave 'saw' -NoiseAmplitude 0.012

Write-Host "Generated level music in $targetDir"
