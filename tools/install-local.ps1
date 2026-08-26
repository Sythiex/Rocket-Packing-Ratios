[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param()

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$localConfigPath = Join-Path $projectRoot ".factorio-local.json"
if (-not (Test-Path -LiteralPath $localConfigPath -PathType Leaf)) {
    throw "Create .factorio-local.json from .factorio-local.example.json and set factorio_root."
}

$localConfig = Get-Content -LiteralPath $localConfigPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($localConfig.factorio_root)) {
    throw "factorio_root is missing from .factorio-local.json."
}

$factorioRoot = [System.IO.Path]::GetFullPath([string]$localConfig.factorio_root)
$factorioExe = Join-Path $factorioRoot "bin\x64\factorio.exe"
$factorioData = Join-Path $factorioRoot "data"
if (-not (Test-Path -LiteralPath $factorioExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $factorioData -PathType Container)) {
    throw "The configured factorio_root is not a Factorio installation: $factorioRoot"
}

$testRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".factorio-test"))
$workRoot = [System.IO.Path]::GetFullPath((Join-Path $testRoot "local-package"))
$stagingRoot = [System.IO.Path]::GetFullPath((Join-Path $workRoot "staging"))
$package = & (Join-Path $PSScriptRoot "package-mod.ps1") `
    -DestinationDirectory $workRoot `
    -StagingDirectory $stagingRoot

$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $factorioRoot "mods"))
$destinationZip = [System.IO.Path]::GetFullPath((Join-Path $modsRoot "$($package.PackageName).zip"))
$factorioPrefix = $factorioRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
    [System.IO.Path]::DirectorySeparatorChar
if (-not $destinationZip.StartsWith($factorioPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to install outside the configured Factorio root: $destinationZip"
}

$staleArchives = @()
if (Test-Path -LiteralPath $modsRoot -PathType Container) {
    $archivePrefix = "$($package.ModName)_"
    $staleArchives = @(Get-ChildItem -LiteralPath $modsRoot -File | Where-Object {
        $_.Extension.Equals(".zip", [System.StringComparison]::OrdinalIgnoreCase) -and
        $_.Name.StartsWith($archivePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $_.FullName.Equals($destinationZip, [System.StringComparison]::OrdinalIgnoreCase)
    })
}

$action = "Install packaged mod and remove $($staleArchives.Count) stale version ZIP(s)"
if ($PSCmdlet.ShouldProcess($destinationZip, $action)) {
    New-Item -ItemType Directory -Path $modsRoot -Force | Out-Null
    Copy-Item -LiteralPath $package.ZipPath -Destination $destinationZip -Force
    foreach ($archive in $staleArchives) {
        Remove-Item -LiteralPath $archive.FullName -Force
    }
    Write-Output "Installed $destinationZip"
}
else {
    Write-Output "Created $($package.ZipPath); installation would remove $($staleArchives.Count) stale ZIP(s)."
}
