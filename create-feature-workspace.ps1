param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFile,

    [string]$WorkspacesRoot = "~/workspaces",

    [switch]$NoWorktrees
)

$ErrorActionPreference = "Stop"

function Expand-PathValue {
    param([string]$Value)

    if ($Value -eq "~") { return $HOME }
    if ($Value.StartsWith("~/") -or $Value.StartsWith("~\")) {
        return Join-Path $HOME $Value.Substring(2)
    }
    return $Value
}

$WorkspacesRoot = Expand-PathValue $WorkspacesRoot
if (-not [System.IO.Path]::IsPathRooted($WorkspacesRoot)) {
    $WorkspacesRoot = Join-Path (Get-Location) $WorkspacesRoot
}
$WorkspaceDir = Join-Path $WorkspacesRoot $FeatureName
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null

$section = $null
$name = $null
$path = $null
$branch = $null

function Add-RepoWorktree {
    param(
        [string]$Section,
        [string]$Name,
        [string]$Path,
        [string]$Branch,
        [switch]$NoWorktrees
    )

    if (-not $Section) { return }

    if ($NoWorktrees) {
        if (-not $Name -or -not $Path) {
            throw "Missing name/path in section [$Section]"
        }
        $RepoPath = Expand-PathValue $Path
        $Destination = Join-Path $WorkspaceDir $Name
        New-Item -ItemType SymbolicLink -Path $Destination -Target $RepoPath | Out-Null
    } else {
        if (-not $Name -or -not $Path -or -not $Branch) {
            throw "Missing name/path/branch in section [$Section]"
        }
        $RepoPath = Expand-PathValue $Path
        $Destination = Join-Path $WorkspaceDir $Name
        git -C $RepoPath worktree add -b $FeatureName $Destination $Branch
        if ($LASTEXITCODE -ne 0) {
            throw "git worktree add failed for section [$Section]"
        }
    }
}

foreach ($rawLine in Get-Content -LiteralPath $ConfigFile) {
    $line = $rawLine.Trim()

    if (-not $line -or $line.StartsWith("#") -or $line.StartsWith(";")) {
        continue
    }

    if ($line -match '^\[(.+)\]$') {
        Add-RepoWorktree $section $name $path $branch -NoWorktrees:$NoWorktrees
        $section = $matches[1]
        $name = $null
        $path = $null
        $branch = $null
        continue
    }

    if ($line -match '^(.*?)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()

        switch ($key) {
            "name"   { $name = $value }
            "path"   { $path = $value }
            "branch" { $branch = $value }
        }
    }
}

Add-RepoWorktree $section $name $path $branch -NoWorktrees:$NoWorktrees