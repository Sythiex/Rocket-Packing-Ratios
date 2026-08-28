[CmdletBinding()]
param(
    [ValidateSet("Create", "SmokeTest", "SelfTest", "Gui")]
    [string]$Mode = "SmokeTest"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$factorioRootInput = $env:ROCKET_PACKING_RATIOS_FACTORIO_ROOT
if ([string]::IsNullOrWhiteSpace($factorioRootInput)) {
    $localConfigPath = Join-Path $projectRoot ".factorio-local.json"
    if (Test-Path -LiteralPath $localConfigPath -PathType Leaf) {
        $localConfig = Get-Content -LiteralPath $localConfigPath -Raw | ConvertFrom-Json
        $factorioRootInput = $localConfig.factorio_root
    }
}
if ([string]::IsNullOrWhiteSpace($factorioRootInput)) {
    throw "Set factorio_root in .factorio-local.json or define ROCKET_PACKING_RATIOS_FACTORIO_ROOT."
}

$factorioRoot = [System.IO.Path]::GetFullPath($factorioRootInput)
$factorioExe = Join-Path $factorioRoot "bin\x64\factorio.exe"
$factorioData = Join-Path $factorioRoot "data"
if (-not (Test-Path -LiteralPath $factorioExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $factorioData -PathType Container)) {
    throw "The configured factorio_root is not a Factorio installation: $factorioRoot"
}

$testRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".factorio-test"))
$modsRoot = Join-Path $testRoot "mods"
$stagingRoot = Join-Path $testRoot "staging"
$savesRoot = Join-Path $testRoot "saves"
$configPath = Join-Path $testRoot "config.ini"
$savePath = Join-Path $savesRoot "rocket-packing-ratios-smoke.zip"
$selfTestSavePath = Join-Path $savesRoot "rocket-packing-ratios-self-test.zip"
$testDriverSource = Join-Path $projectRoot "tests\fixture-mod"
$testDriverPackageRoot = Join-Path $stagingRoot "rocket-packing-ratios-test_0.0.1"
$testDriverZipPath = Join-Path $modsRoot "rocket-packing-ratios-test_0.0.1.zip"
$isSelfTest = $Mode -eq "SelfTest"

foreach ($directory in @($testRoot, $modsRoot, $stagingRoot, $savesRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$packageArguments = @{
    DestinationDirectory = $modsRoot
    StagingDirectory = $stagingRoot
}
$package = & (Join-Path $PSScriptRoot "package-mod.ps1") @packageArguments

if (Test-Path -LiteralPath $testDriverZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $testDriverZipPath -Force
}
if ($isSelfTest) {
    if (-not (Test-Path -LiteralPath $testDriverSource -PathType Container)) {
        throw "Self-test fixture mod is missing: $testDriverSource"
    }
    if (Test-Path -LiteralPath $testDriverPackageRoot) {
        Remove-Item -LiteralPath $testDriverPackageRoot -Recurse -Force
    }
    Copy-Item -LiteralPath $testDriverSource -Destination $testDriverPackageRoot -Recurse
    Compress-Archive -LiteralPath $testDriverPackageRoot -DestinationPath $testDriverZipPath `
        -CompressionLevel Optimal
}

$modList = @{
    mods = @(
        @{ name = "base"; enabled = $true },
        @{ name = "elevated-rails"; enabled = $true },
        @{ name = "quality"; enabled = $true },
        @{ name = "recycler"; enabled = $true },
        @{ name = "space-age"; enabled = $true },
        @{ name = $package.ModName; enabled = $true },
        @{ name = "rocket-packing-ratios-test"; enabled = $isSelfTest }
    )
} | ConvertTo-Json -Depth 4
Set-Content -LiteralPath (Join-Path $modsRoot "mod-list.json") -Value $modList -Encoding utf8NoBOM

$readData = $factorioData.Replace("\", "/")
$writeData = $testRoot.Replace("\", "/")
$config = @"
[path]
read-data=$readData
write-data=$writeData

[general]
locale=en
"@
Set-Content -LiteralPath $configPath -Value $config -Encoding utf8NoBOM

$commonArguments = @(
    "--config", $configPath,
    "--mod-directory", $modsRoot
)

function Invoke-FactorioHeadless {
    param([string[]]$Arguments)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $factorioExe
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start isolated Factorio validation."
    }
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        $captured = ($standardOutput.Result + "`n" + $standardError.Result).Trim()
        throw "Factorio exited with code $($process.ExitCode).`n$captured"
    }
}

function New-IsolatedSave {
    if (Test-Path -LiteralPath $savePath -PathType Leaf) {
        Remove-Item -LiteralPath $savePath -Force
    }
    Invoke-FactorioHeadless ($commonArguments + @("--create", $savePath))
}

function Invoke-SelfTest {
    if (Test-Path -LiteralPath $selfTestSavePath -PathType Leaf) {
        Remove-Item -LiteralPath $selfTestSavePath -Force
    }
    Invoke-FactorioHeadless ($commonArguments + @("--create", $selfTestSavePath))
    Invoke-FactorioHeadless ($commonArguments + @(
        "--benchmark", $selfTestSavePath,
        "--benchmark-ticks", "1",
        "--benchmark-runs", "1"
    ))

    $logPath = Join-Path $testRoot "factorio-current.log"
    $logText = Get-Content -LiteralPath $logPath -Raw
    $expectedPass = "[Rocket Packing Ratios test driver] PASS"
    $diagnosticPattern = '(?im)^\s*\d+\.\d+\s+(Error|Warning)\b'
    if (-not $logText.Contains($expectedPass) -or
        $logText.Contains("[Rocket Packing Ratios test driver] FAIL") -or
        $logText -match $diagnosticPattern -or
        -not $logText.Contains("Goodbye")) {
        throw "Self-test did not report a warning-free PASS and clean shutdown. Inspect $logPath"
    }
    Write-Output "PASS: Rocket Packing Ratios fixtures and engine weights passed in isolated Factorio 2.1."
}

switch ($Mode) {
    "Create" {
        New-IsolatedSave
        Write-Output "Created isolated save: $savePath"
    }
    "SmokeTest" {
        New-IsolatedSave
        Invoke-FactorioHeadless ($commonArguments + @(
            "--benchmark", $savePath,
            "--benchmark-ticks", "1",
            "--benchmark-runs", "1"
        ))
        $logPath = Join-Path $testRoot "factorio-current.log"
        $logText = Get-Content -LiteralPath $logPath -Raw
        $expectedLoad = "Loading mod $($package.ModName) $($package.Version)"
        if (-not $logText.Contains($expectedLoad) -or
            -not $logText.Contains("Goodbye")) {
            throw "Smoke test did not confirm the mod load and clean shutdown. Inspect $logPath"
        }
        Write-Output "PASS: Rocket Packing Ratios loaded and reloaded in isolated Factorio 2.1."
    }
    "SelfTest" {
        Invoke-SelfTest
    }
    "Gui" {
        if (-not (Test-Path -LiteralPath $savePath -PathType Leaf)) {
            throw "Create the isolated save first with -Mode Create."
        }
        & $factorioExe @commonArguments "--load-game" $savePath
    }
}
