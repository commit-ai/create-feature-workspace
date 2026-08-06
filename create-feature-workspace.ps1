param(
    [string]$FeatureName = "",

    [string]$ConfigFile,

    [string]$WorkspacesRoot = "",

    [switch]$NoWorktrees,

    [ValidateSet("create", "sync", "add", "remove")]
    [string]$Command = "create",

    [string]$FolderName,

    [string]$FolderPath,

    [string]$Branch,

    [ValidateSet("repository", "folder")]
    [string]$Type = "repository"
)

$ErrorActionPreference = "Stop"

function Expand-PathValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "A path value cannot be empty"
    }

    if ($Value -eq "~") { return $HOME }
    if ($Value.StartsWith("~/") -or $Value.StartsWith("~\")) {
        return Join-Path $HOME $Value.Substring(2)
    }
    return $Value
}

function Resolve-WorkspaceRoot {
    param([string]$Value)

    $expanded = Expand-PathValue $Value
    if (-not [System.IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path (Get-Location).Path $expanded
    }
    return [System.IO.Path]::GetFullPath($expanded)
}

function Assert-EntryName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or
        $Value -eq "." -or $Value -eq ".." -or
        $Value.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Value.Contains("/") -or $Value.Contains("\") -or
        $Value -eq ".create-feature-workspace.desired.ini" -or
        $Value -eq ".create-feature-workspace.provisioned.ini") {
        throw "Invalid workspace entry name [$Value]"
    }
}

function New-Entry {
    param(
        [string]$Section,
        [hashtable]$Values,
        [switch]$AllowWorkspaceSection,
        [switch]$NoWorktrees
    )

    if ($AllowWorkspaceSection -and $Section -eq "workspace") {
        return $null
    }

    $entryName = $Values["name"]
    $entryPath = $Values["path"]
    $entryBranch = $Values["branch"]
    $entryType = $Values["type"]
    if ([string]::IsNullOrWhiteSpace($entryType)) {
        $entryType = "repository"
    }

    if ($entryType -ne "repository" -and $entryType -ne "folder") {
        throw "Invalid type [$entryType] in section [$Section]"
    }
    if ([string]::IsNullOrWhiteSpace($entryName) -or [string]::IsNullOrWhiteSpace($entryPath)) {
        throw "Missing name/path in section [$Section]"
    }
    if ($entryType -eq "repository" -and -not $NoWorktrees -and
        [string]::IsNullOrWhiteSpace($entryBranch)) {
        throw "Missing name/path/branch in section [$Section]"
    }
    Assert-EntryName $entryName

    return [PSCustomObject]@{
        Section = $Section
        Name = $entryName
        Path = $entryPath
        Branch = $entryBranch
        Type = $entryType
    }
}

function Read-WorkspaceIni {
    param(
        [string]$IniPath,
        [switch]$Manifest,
        [switch]$NoWorktreesForValidation
    )

    if (-not (Test-Path -LiteralPath $IniPath -PathType Leaf)) {
        throw "Configuration file does not exist: $IniPath"
    }

    $entries = New-Object System.Collections.ArrayList
    $section = $null
    $values = $null
    $mode = $null

    function Complete-Section {
        if ($null -eq $section) { return }
        if ($Manifest -and $section -eq "workspace") {
            if ($values.Count -ne 1 -or -not $values.ContainsKey("mode")) {
                throw "Invalid [workspace] section in $IniPath"
            }
            Set-Variable -Name mode -Value $values["mode"] -Scope 1
            return
        }
        $entry = New-Entry $section $values -NoWorktrees:($NoWorktreesForValidation -or $mode -eq "symlink")
        [void]$entries.Add($entry)
    }

    foreach ($rawLine in Get-Content -LiteralPath $IniPath) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#") -or $line.StartsWith(";")) {
            continue
        }
        if ($line -match '^\[(.+)\]$') {
            Complete-Section
            $section = $matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($section)) {
                throw "Empty section name in $IniPath"
            }
            if ($Manifest -and $null -eq $mode -and $section -ne "workspace") {
                throw "Manifest must begin with a [workspace] section"
            }
            $values = @{}
            continue
        }
        if ($line -notmatch '^(.*?)=(.*)$') {
            throw "Malformed configuration line in ${IniPath}: $rawLine"
        }
        if ($null -eq $section) {
            throw "Configuration key outside a section in $IniPath"
        }
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        if ($key -notin @("name", "path", "branch", "type", "mode") -or
            ($key -eq "mode" -and (-not $Manifest -or $section -ne "workspace"))) {
            throw "Unknown key [$key] in section [$section]"
        }
        if ($values.ContainsKey($key)) {
            throw "Duplicate key [$key] in section [$section]"
        }
        $values[$key] = $value
    }
    Complete-Section

    if ($null -eq $section) {
        throw "Configuration file contains no sections: $IniPath"
    }
    if ($Manifest) {
        if ($mode -ne "worktree" -and $mode -ne "symlink") {
            throw "Manifest must define mode = worktree or mode = symlink"
        }
    }

    $names = @{}
    foreach ($entry in $entries) {
        if ($names.ContainsKey($entry.Name)) {
            throw "Duplicate workspace entry name [$($entry.Name)]"
        }
        $names[$entry.Name] = $true
    }

    return [PSCustomObject]@{ Mode = $mode; Entries = @($entries) }
}

function Write-WorkspaceIni {
    param(
        [string]$IniPath,
        [string]$Mode,
        [object[]]$Entries
    )

    $lines = New-Object System.Collections.ArrayList
    if ($IniPath -like "*.desired.ini*") {
        [void]$lines.Add("; Desired workspace definition. Edit this file, then run sync.")
    } else {
        [void]$lines.Add("; Provisioned workspace record. Managed by create-feature-workspace; do not edit.")
    }
    [void]$lines.Add("[workspace]")
    [void]$lines.Add("mode = $Mode")
    foreach ($entry in $Entries) {
        [void]$lines.Add("")
        [void]$lines.Add("[$($entry.Section)]")
        [void]$lines.Add("name = $($entry.Name)")
        [void]$lines.Add("path = $($entry.Path)")
        if (-not [string]::IsNullOrWhiteSpace($entry.Branch)) {
            [void]$lines.Add("branch = $($entry.Branch)")
        }
        [void]$lines.Add("type = $($entry.Type)")
    }
    Set-Content -LiteralPath $IniPath -Value $lines
}

function Get-ItemAtPath {
    param([string]$LiteralPath)
    return Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
}

function Test-EntryEqual {
    param([object]$Left, [object]$Right)
    return $Left.Name -eq $Right.Name -and
        $Left.Path -eq $Right.Path -and
        $Left.Branch -eq $Right.Branch -and
        $Left.Type -eq $Right.Type
}

function Remove-TrackedArtifact {
    param(
        [object]$Entry,
        [string]$Mode,
        [string]$WorkspaceDir
    )

    $destination = Join-Path $WorkspaceDir $Entry.Name
    $item = Get-ItemAtPath $destination
    if ($null -eq $item) {
        return
    }

    if ($Entry.Type -eq "folder" -or $Mode -eq "symlink") {
        if ($item.LinkType -ne "SymbolicLink") {
            throw "Refusing to remove non-symbolic-link destination: $destination"
        }
        Remove-Item -LiteralPath $destination
        return
    }

    $source = Expand-PathValue $Entry.Path
    git -C $source worktree remove $destination
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree remove failed for entry [$($Entry.Name)]"
    }
}

function Add-TrackedArtifact {
    param(
        [object]$Entry,
        [string]$Mode,
        [string]$WorkspaceDir
    )

    $destination = Join-Path $WorkspaceDir $Entry.Name
    if ($null -ne (Get-ItemAtPath $destination)) {
        throw "Unmanaged destination conflict: $destination"
    }

    $source = Expand-PathValue $Entry.Path
    if ($Entry.Type -eq "folder" -or $Mode -eq "symlink") {
        New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
        return
    }

    git -C $source rev-parse --verify $FeatureName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git -C $source worktree add $destination $FeatureName
    } else {
        git -C $source worktree add -b $FeatureName $destination $Entry.Branch
    }
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree add failed for entry [$($Entry.Name)]"
    }
}

function Sync-Workspace {
    param(
        [object]$Desired,
        [string]$DesiredPath,
        [string]$StatePath,
        [string]$WorkspaceDir
    )

    if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
        $state = Read-WorkspaceIni $StatePath -Manifest
        if ($state.Mode -ne $Desired.Mode) {
            throw "State mode does not match the desired manifest mode"
        }
    } else {
        $state = [PSCustomObject]@{ Mode = $Desired.Mode; Entries = @() }
    }

    $remaining = New-Object System.Collections.ArrayList
    foreach ($entry in $state.Entries) { [void]$remaining.Add($entry) }

    foreach ($current in @($state.Entries)) {
        $desiredEntry = @($Desired.Entries | Where-Object { $_.Name -eq $current.Name }) | Select-Object -First 1
        if ($null -eq $desiredEntry -or -not (Test-EntryEqual $current $desiredEntry)) {
            Remove-TrackedArtifact $current $state.Mode $WorkspaceDir
            [void]$remaining.Remove($current)
            Write-WorkspaceIni $StatePath $Desired.Mode @($remaining)
        }
    }

    foreach ($entry in $Desired.Entries) {
        $tracked = @($remaining | Where-Object { Test-EntryEqual $_ $entry }) | Select-Object -First 1
        if ($null -eq $tracked) {
            Add-TrackedArtifact $entry $Desired.Mode $WorkspaceDir
            [void]$remaining.Add($entry)
            Write-WorkspaceIni $StatePath $Desired.Mode @($remaining)
        }
    }

    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        Write-WorkspaceIni $StatePath $Desired.Mode @($remaining)
    }
}

if ($Command -ne "create") {
    if ($PSBoundParameters.ContainsKey('WorkspacesRoot')) {
        throw "-WorkspacesRoot is not accepted for -Command $Command; run this command from inside the workspace directory"
    }
    if ($PSBoundParameters.ContainsKey('FeatureName')) {
        throw "-FeatureName is not accepted for -Command $Command; run this command from inside the workspace directory"
    }
    $WorkspaceDir = (Get-Location).Path
    $FeatureName  = Split-Path -Leaf $WorkspaceDir
} else {
    if ([string]::IsNullOrWhiteSpace($FeatureName)) {
        throw "-FeatureName is required with -Command create"
    }
    if ($FeatureName -eq "." -or $FeatureName -eq ".." -or
        $FeatureName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $FeatureName.Contains("/") -or $FeatureName.Contains("\")) {
        throw "Invalid feature name [$FeatureName]"
    }
    if ([string]::IsNullOrWhiteSpace($WorkspacesRoot)) { $WorkspacesRoot = "~/workspaces" }
    $WorkspacesRoot = Resolve-WorkspaceRoot $WorkspacesRoot
    $WorkspaceDir   = Join-Path $WorkspacesRoot $FeatureName
}

if ($Command -ne "create" -and $NoWorktrees) {
    throw "-NoWorktrees is only valid with -Command create; mode is persisted in the manifest"
}

$DesiredPath = Join-Path $WorkspaceDir ".create-feature-workspace.desired.ini"
$StatePath   = Join-Path $WorkspaceDir ".create-feature-workspace.provisioned.ini"

if ($Command -ne "create" -and -not (Test-Path -LiteralPath $DesiredPath -PathType Leaf)) {
    throw "Not inside a managed workspace. Run this command from inside the workspace directory."
}

switch ($Command) {
    "create" {
        if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
            throw "-ConfigFile is required with -Command create"
        }
        if (Test-Path -LiteralPath $DesiredPath -PathType Leaf) {
            throw "Workspace is already managed; use -Command sync, add, or remove"
        }
        $sourceConfig = Read-WorkspaceIni (Expand-PathValue $ConfigFile) -NoWorktreesForValidation:$NoWorktrees
        $desired = [PSCustomObject]@{
            Mode = $(if ($NoWorktrees) { "symlink" } else { "worktree" })
            Entries = $sourceConfig.Entries
        }
        New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
        Write-WorkspaceIni $DesiredPath $desired.Mode $desired.Entries
        Sync-Workspace $desired $DesiredPath $StatePath $WorkspaceDir
    }
    "sync" {
        $desired = Read-WorkspaceIni $DesiredPath -Manifest
        Sync-Workspace $desired $DesiredPath $StatePath $WorkspaceDir
    }
    "add" {
        $desired = Read-WorkspaceIni $DesiredPath -Manifest
        if ([string]::IsNullOrWhiteSpace($FolderName) -or [string]::IsNullOrWhiteSpace($FolderPath)) {
            throw "-FolderName and -FolderPath are required with -Command add"
        }
        $values = @{ name = $FolderName; path = $FolderPath; type = $Type }
        $resolvedBranch = $Branch
        if ([string]::IsNullOrWhiteSpace($resolvedBranch) -and $desired.Mode -ne "symlink" -and $Type -ne "folder") {
            $expandedPath = Expand-PathValue $FolderPath
            $resolvedBranch = git -C $expandedPath symbolic-ref --short HEAD 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedBranch)) {
                throw "Could not detect current branch for $FolderPath; pass -Branch explicitly"
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($resolvedBranch)) { $values["branch"] = $resolvedBranch }
        $newEntry = New-Entry "entry-$FolderName" $values -NoWorktrees:($desired.Mode -eq "symlink")
        if (@($desired.Entries | Where-Object { $_.Name -eq $newEntry.Name }).Count -ne 0) {
            throw "Workspace entry already exists: $FolderName"
        }
        $updated = @($desired.Entries) + @($newEntry)
        Write-WorkspaceIni $DesiredPath $desired.Mode $updated
        $desired = [PSCustomObject]@{ Mode = $desired.Mode; Entries = $updated }
        Sync-Workspace $desired $DesiredPath $StatePath $WorkspaceDir
    }
    "remove" {
        $desired = Read-WorkspaceIni $DesiredPath -Manifest
        if ([string]::IsNullOrWhiteSpace($FolderName)) {
            throw "-FolderName is required with -Command remove"
        }
        $updated = @($desired.Entries | Where-Object { $_.Name -ne $FolderName })
        if ($updated.Count -eq $desired.Entries.Count) {
            throw "Workspace entry does not exist: $FolderName"
        }
        # Stage the new manifest; promote only after sync succeeds
        $stagedPath = "$DesiredPath.staged"
        Write-WorkspaceIni $stagedPath $desired.Mode $updated
        $stagedDesired = [PSCustomObject]@{ Mode = $desired.Mode; Entries = $updated }
        Sync-Workspace $stagedDesired $stagedPath $StatePath $WorkspaceDir
        Move-Item -LiteralPath $stagedPath -Destination $DesiredPath -Force
    }
}

Write-Host "Workspace metadata:"
Write-Host "  Desired configuration: $DesiredPath"
Write-Host "  Provisioned record: $StatePath"
