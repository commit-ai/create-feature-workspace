param(
    [string]$BinDir = "",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    @"
Usage: install-create-feature-workspace.ps1 [-BinDir PATH]

Copies the script and creates a .cmd wrapper so you can run:
  create-feature-workspace <args...>

Options:
  -BinDir PATH  Directory where the files will be installed (default: ~/.local/bin)
  -Help         Show this help message
"@
    exit 0
}

$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

if ([string]::IsNullOrWhiteSpace($BinDir)) {
    $BinDir = Join-Path $homeDir ".local\bin"
} elseif ($BinDir -eq "~") {
    $BinDir = $homeDir
} elseif ($BinDir.StartsWith("~/") -or $BinDir.StartsWith("~\")) {
    $BinDir = Join-Path $homeDir $BinDir.Substring(2)
}

$sourceScript = Join-Path $PSScriptRoot "create-feature-workspace.ps1"
$psPath  = Join-Path $BinDir "create-feature-workspace.ps1"
$cmdPath = Join-Path $BinDir "create-feature-workspace.cmd"
$cmdContent = "@echo off`r`npowershell.exe -ExecutionPolicy RemoteSigned -File `"%~dp0create-feature-workspace.ps1`" %*`r`n"

if (-not (Test-Path $sourceScript)) {
    Write-Error "Source script not found: $sourceScript"
    exit 1
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$sourceContent = Get-Content $sourceScript -Raw

# Replace a legacy symlink from the old installer with a plain copy
if (Test-Path $psPath) {
    $existing = Get-Item $psPath -Force
    if ($existing.LinkType -eq "SymbolicLink") {
        Remove-Item $psPath -Force
    }
}

# Check idempotency: both files present and up to date
$psUpToDate  = (Test-Path $psPath)  -and ((Get-Content $psPath  -Raw) -eq $sourceContent)
$cmdUpToDate = (Test-Path $cmdPath) -and ((Get-Content $cmdPath -Raw) -eq $cmdContent)

if ($psUpToDate -and $cmdUpToDate) {
    Write-Host "Already up to date: $psPath"
    exit 0
}

Copy-Item -Path $sourceScript -Destination $psPath -Force
[System.IO.File]::WriteAllText($cmdPath, $cmdContent)

$pathEntries = $env:PATH -split [System.IO.Path]::PathSeparator
if ($pathEntries -notcontains $BinDir) {
    Write-Host "Installed: $psPath and $cmdPath"
    Write-Host "Note: $BinDir is not currently in PATH. Add it to your profile and restart your shell."
} else {
    Write-Host "Installed: $psPath and $cmdPath"
}
