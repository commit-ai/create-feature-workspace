param(
    [string]$BinDir = "",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    @"
Usage: install-create-feature-workspace.ps1 [-BinDir PATH]

Creates a symlink so you can run:
  create-feature-workspace.ps1 <args...>

Options:
  -BinDir PATH  Directory where the symlink will be created (default: ~/.local/bin)
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

$linkName = "create-feature-workspace.ps1"
$sourceScript = Join-Path $PSScriptRoot "create-feature-workspace.ps1"
$linkPath = Join-Path $BinDir $linkName

if (-not (Test-Path $sourceScript)) {
    Write-Error "Source script not found: $sourceScript"
    exit 1
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

if (Test-Path $linkPath) {
    $existing = Get-Item $linkPath -Force
    if ($existing.LinkType -ne "SymbolicLink") {
        Write-Error "Refusing to replace non-symlink path: $linkPath"
        exit 1
    }
    if ($existing.Target -eq $sourceScript) {
        Write-Host "Symlink already configured: $linkPath -> $sourceScript"
        exit 0
    }
    Remove-Item $linkPath -Force
}

New-Item -ItemType SymbolicLink -Path $linkPath -Target $sourceScript | Out-Null

$pathEntries = $env:PATH -split [System.IO.Path]::PathSeparator
if ($pathEntries -notcontains $BinDir) {
    Write-Host "Installed symlink at: $linkPath"
    Write-Host "Note: $BinDir is not currently in PATH. Add it to your profile and restart your shell."
} else {
    Write-Host "Created symlink: $linkPath -> $sourceScript"
}
