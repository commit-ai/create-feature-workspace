
# ---------------------------------------------------------------------------
# Helpers shared across all Pester tests in this file
# ---------------------------------------------------------------------------

function New-GitShim {
    param(
        [string]$ShimDir,
        [string]$Body
    )
    if (-not (Test-Path $ShimDir)) { New-Item -ItemType Directory -Force -Path $ShimDir | Out-Null }
    $gitShim = Join-Path $ShimDir "git.ps1"
    $Body | Set-Content $gitShim
    return $ShimDir
}

function New-AddRemoveShim {
    param([string]$ShimDir)
    $body = @'
$argsStr = $args -join " "
Write-Host "MOCK GIT CALLED: $argsStr"
if ($argsStr -match "worktree add") {
    $dest = $args[-2]
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
} elseif ($argsStr -match "worktree remove") {
    $dest = $args[-1]
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
}
exit 0
'@
    return New-GitShim $ShimDir $body
}

function New-DirtyShim {
    param([string]$ShimDir)
    $body = @'
$argsStr = $args -join " "
if ($argsStr -match "worktree add") {
    $dest = $args[-2]
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    exit 0
}
if ($argsStr -match "worktree remove") {
    Write-Error "fatal: working tree has modifications"
    exit 1
}
exit 0
'@
    return New-GitShim $ShimDir $body
}

Describe "create-feature-workspace.ps1" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\create-feature-workspace.ps1"
        $testConfig = Join-Path $PSScriptRoot "test_data\test-config.ini"
        $workspacesRoot = Join-Path $PSScriptRoot "temp-workspaces"

        @"
[repo1]
name = repo-alpha
path = C:\Users\galzi\src\demo-repo-1
branch = master
"@ | Set-Content $testConfig
    }

    AfterAll {
        if (Test-Path $testConfig) { Remove-Item $testConfig }
        if (Test-Path $workspacesRoot) { Remove-Item -Recurse -Force $workspacesRoot }
    }

    It "Successfully calls git worktree add for a valid config" {
        $feature = "new-feature-unique-3"
        $mockedRepo = "C:\Users\galzi\src\create-feature-workspace"

        @"
[repo1]
name = repo-alpha
path = $mockedRepo
branch = main
"@ | Set-Content $testConfig

        # Create a proxy for git that doesn't fail
        $tempDir = Join-Path $PSScriptRoot "temp-bin"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory $tempDir }
        $gitShim = Join-Path $tempDir "git.ps1"
        '$argsString = $args -join " "
Write-Host "MOCK GIT CALLED with args: $argsString"
if ($argsString -match "worktree add") {
    $dest = $args[-2]
    Write-Host "Mock creating directory $dest"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}
exit 0' | Set-Content $gitShim

        $oldPath = $env:PATH
        $env:PATH = "$tempDir;$oldPath"

        try {
            & $scriptPath -FeatureName $feature -ConfigFile $testConfig -WorkspacesRoot $workspacesRoot
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $tempDir
        }

        $expectedPath = Join-Path $workspacesRoot $feature | Join-Path -ChildPath "repo-alpha"
        Test-Path $expectedPath | Should Be $true
    }

    It "Handles relative -WorkspacesRoot correctly" {
        $feature = "rel-feat-unique"
        $runDir = Join-Path $PSScriptRoot "temp-run-cwd"
        New-Item -ItemType Directory -Force -Path $runDir | Out-Null

        $tempDir = Join-Path $PSScriptRoot "temp-bin-rel"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        $gitShim = Join-Path $tempDir "git.ps1"
        '$argsString = $args -join " "
if ($argsString -match "worktree add") {
    $dest = $args[-2]
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}
exit 0' | Set-Content $gitShim

        $oldPath = $env:PATH
        $env:PATH = "$tempDir;$oldPath"
        $oldLocation = Get-Location
        Set-Location $runDir

        try {
            & $scriptPath -FeatureName $feature -ConfigFile $testConfig -WorkspacesRoot "rel-ws"
        } finally {
            Set-Location $oldLocation
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $tempDir
            if (Test-Path $runDir) { Remove-Item -Recurse -Force $runDir }
        }

        $expectedPath = Join-Path $runDir "rel-ws" | Join-Path -ChildPath $feature | Join-Path -ChildPath "repo-alpha"
        Test-Path $expectedPath | Should Be $true
    }

    It "Expands tilde (~) in workspaces root" {
        $uniqueTilde = "test-tilde-$(Get-Random)"
        $tempDir = Join-Path $PSScriptRoot "temp-bin-2"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory $tempDir }
        $gitShim = Join-Path $tempDir "git.ps1"
        'exit 0' | Set-Content $gitShim
        $oldPath = $env:PATH
        $env:PATH = "$tempDir;$oldPath"

        try {
            & $scriptPath -FeatureName $uniqueTilde -ConfigFile $testConfig -WorkspacesRoot "~/ws-$uniqueTilde"
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $tempDir
            $createdWs = Join-Path $HOME "ws-$uniqueTilde"
            if (Test-Path $createdWs) { Remove-Item -Recurse -Force $createdWs }
        }
    }

    It "-NoWorktrees creates a symlink to the repo path without invoking git" {
        $feature = "no-wt-$(Get-Random)"
        $repoPath = Join-Path $PSScriptRoot "fake-repo-$feature"
        New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
        $config = Join-Path $PSScriptRoot "temp-nwt-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = $repoPath
branch = some-branch
"@ | Set-Content $config
        $markerFile = Join-Path $PSScriptRoot "git-called-$feature.marker"
        $tempDir = Join-Path $PSScriptRoot "temp-bin-nwt-$feature"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        $gitShim = Join-Path $tempDir "git.ps1"
        "New-Item -ItemType File -Force -Path '$markerFile' | Out-Null; exit 0" | Set-Content $gitShim
        $oldPath = $env:PATH
        $env:PATH = "$tempDir;$oldPath"
        try {
            & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot -NoWorktrees
            $linkPath = Join-Path (Join-Path $workspacesRoot $feature) "repo-alpha"
            $item = Get-Item $linkPath -ErrorAction Stop
            $item.LinkType | Should Be "SymbolicLink"
            Test-Path $markerFile | Should Be $false
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $tempDir
            if (Test-Path $config) { Remove-Item $config }
            if (Test-Path $repoPath) { Remove-Item -Recurse -Force $repoPath }
            if (Test-Path $markerFile) { Remove-Item $markerFile }
        }
    }

    It "-NoWorktrees succeeds when branch is absent" {
        $feature = "no-wt-nobranch-$(Get-Random)"
        $repoPath = Join-Path $PSScriptRoot "fake-repo-$feature"
        New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
        $config = Join-Path $PSScriptRoot "temp-nwt-nobranch-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = $repoPath
"@ | Set-Content $config
        try {
            { & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot -NoWorktrees } | Should Not Throw
            $linkPath = Join-Path (Join-Path $workspacesRoot $feature) "repo-alpha"
            Test-Path $linkPath | Should Be $true
        } finally {
            if (Test-Path $config) { Remove-Item $config }
            if (Test-Path $repoPath) { Remove-Item -Recurse -Force $repoPath }
        }
    }

    # -----------------------------------------------------------------------
    # Phase 0b: manifest and state file creation
    # -----------------------------------------------------------------------

    It "create writes manifest with [workspace] and mode=worktree" {
        $feature = "mani-feat-$(Get-Random)"
        $config = Join-Path $PSScriptRoot "temp-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
"@ | Set-Content $config
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot
            $manifest = Join-Path (Join-Path $workspacesRoot $feature) ".create-feature-workspace.ini"
            Test-Path $manifest | Should Be $true
            Get-Content $manifest | Where-Object { $_ -match '\[workspace\]' } | Should Not BeNullOrEmpty
            Get-Content $manifest | Where-Object { $_ -match 'mode = worktree' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
            Remove-Item $config -ErrorAction SilentlyContinue
        }
    }

    It "create -NoWorktrees writes manifest with mode=symlink" {
        $feature = "sym-feat-$(Get-Random)"
        $config = Join-Path $PSScriptRoot "temp-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
"@ | Set-Content $config
        try {
            & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot -NoWorktrees
            $manifest = Join-Path (Join-Path $workspacesRoot $feature) ".create-feature-workspace.ini"
            Get-Content $manifest | Where-Object { $_ -match 'mode = symlink' } | Should Not BeNullOrEmpty
        } finally {
            Remove-Item $config -ErrorAction SilentlyContinue
        }
    }

    It "create writes state file listing provisioned entries" {
        $feature = "state-feat-$(Get-Random)"
        $config = Join-Path $PSScriptRoot "temp-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
"@ | Set-Content $config
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot
            $state = Join-Path (Join-Path $workspacesRoot $feature) ".create-feature-workspace.state.ini"
            Test-Path $state | Should Be $true
            Get-Content $state | Where-Object { $_ -match 'name = repo-alpha' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
            Remove-Item $config -ErrorAction SilentlyContinue
        }
    }

    It "create fails when manifest already exists" {
        $feature = "dup-feat-$(Get-Random)"
        $config = Join-Path $PSScriptRoot "temp-$feature.ini"
        @"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
"@ | Set-Content $config
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot
            { & $scriptPath -FeatureName $feature -ConfigFile $config -WorkspacesRoot $workspacesRoot } | Should Throw
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
            Remove-Item $config -ErrorAction SilentlyContinue
        }
    }

    # -----------------------------------------------------------------------
    # Phase 0c: manifest validation
    # -----------------------------------------------------------------------

    It "manifest rejects duplicate entry name" {
        $feature = "val-dup-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository

[entry-1]
name = repo-alpha
path = /fake/repo2
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects entry missing name" {
        $feature = "val-noname-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects repository entry missing branch in worktree mode" {
        $feature = "val-nobranch-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects unknown key" {
        $feature = "val-unknownkey-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
unknown = something
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects duplicate key within a section" {
        $feature = "val-dupkey-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects file that does not begin with [workspace]" {
        $feature = "val-noworkspace-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects invalid mode value" {
        $feature = "val-badmode-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = invalid

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "manifest rejects malformed section header" {
        $feature = "val-badheader-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        "[workspace]`nmode = worktree`n`n[entry-0`nname = repo-alpha`npath = /fake/repo`nbranch = main`ntype = repository" |
            Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    # -----------------------------------------------------------------------
    # Phase 0d: sync command
    # -----------------------------------------------------------------------

    It "sync creates a missing worktree entry declared in the manifest" {
        $feature = "sync-add-wt-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $true
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "sync creates a missing symlink entry declared in the manifest" {
        $feature = "sync-add-sym-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = symlink

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
        $item = Get-Item (Join-Path $ws "repo-alpha") -ErrorAction SilentlyContinue -Force
        $item.LinkType | Should Be "SymbolicLink"
    }

    It "sync removes a managed worktree entry absent from the manifest" {
        $feature = "sync-rm-wt-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        $dest = Join-Path $ws "repo-alpha"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path $dest | Should Be $false
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "sync removes a managed symlink entry absent from the manifest" {
        $feature = "sync-rm-sym-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        $dest = Join-Path $ws "repo-alpha"
        New-Item -ItemType SymbolicLink -Path $dest -Target "/fake/repo" | Out-Null
        @"
[workspace]
mode = symlink
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = symlink

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
        Test-Path $dest | Should Be $false
    }

    It "sync replaces a managed entry whose branch has changed" {
        $feature = "sync-replace-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = new-branch
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = old-branch
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $true
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "sync is a no-op when workspace already matches the manifest" {
        $feature = "sync-noop-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        $manifestContent = @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@
        $manifestContent | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        # state must also use [workspace] header for the manifest mode
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $markerFile = Join-Path $PSScriptRoot "git-called-$feature.marker"
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
        "New-Item -ItemType File -Force -Path '$markerFile' | Out-Null; exit 0" | Set-Content (Join-Path $shimDir "git.ps1")
        $oldPath = $env:PATH
        $env:PATH = "$shimDir;$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path $markerFile | Should Be $false
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
            Remove-Item $markerFile -ErrorAction SilentlyContinue
        }
    }

    It "sync updates state file after each successful operation" {
        $feature = "sync-stateupdate-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            $state = Join-Path $ws ".create-feature-workspace.state.ini"
            Test-Path $state | Should Be $true
            Get-Content $state | Where-Object { $_ -match 'name = repo-alpha' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "sync refuses to touch an unmanaged path at a conflicting destination" {
        $feature = "sync-conflict-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        # no state file — repo-alpha is unmanaged
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
    }

    It "sync does not force-delete a dirty worktree and does not update state" {
        $feature = "sync-dirty-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-DirtyShim $shimDir);$oldPath"
        try {
            { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
            Get-Content (Join-Path $ws ".create-feature-workspace.state.ini") |
                Where-Object { $_ -match 'name = repo-alpha' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "sync rejects -NoWorktrees flag" {
        $feature = "sync-nowt-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot -NoWorktrees } | Should Throw
    }

    # -----------------------------------------------------------------------
    # Phase 0e: add command
    # -----------------------------------------------------------------------

    It "add appends entry to manifest and provisions it" {
        $feature = "add-basic-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name repo-alpha -Path /fake/repo -Branch main
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $true
            Get-Content (Join-Path $ws ".create-feature-workspace.ini") |
                Where-Object { $_ -match 'name = repo-alpha' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "add rejects a duplicate entry name before modifying the manifest" {
        $feature = "add-dup-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name repo-alpha -Path /fake/repo2 -Branch develop } |
            Should Throw
    }

    It "add of a folder entry creates a symlink even in worktree-mode workspace" {
        $feature = "add-folder-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name shared-libs -Path /fake/libs -Type folder
        $item = Get-Item (Join-Path $ws "shared-libs") -Force -ErrorAction Stop
        $item.LinkType | Should Be "SymbolicLink"
    }

    It "add of repository entry in worktree mode rejects missing branch" {
        $feature = "add-nobranch-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name repo-alpha -Path /fake/repo } |
            Should Throw
    }

    # -----------------------------------------------------------------------
    # Phase 0f: remove command
    # -----------------------------------------------------------------------

    It "remove deletes entry from manifest and removes it from workspace" {
        $feature = "remove-basic-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command remove -WorkspacesRoot $workspacesRoot -Name repo-alpha
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $false
            Get-Content (Join-Path $ws ".create-feature-workspace.ini") |
                Where-Object { $_ -match 'name = repo-alpha' } | Should BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "remove of an unrecognized name is rejected with a visible error" {
        $feature = "remove-notfound-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command remove -WorkspacesRoot $workspacesRoot -Name nonexistent } |
            Should Throw
    }

    It "remove does not force-delete a dirty worktree and leaves manifest unchanged" {
        $feature = "remove-dirty-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-DirtyShim $shimDir);$oldPath"
        try {
            { & $scriptPath -FeatureName $feature -Command remove -WorkspacesRoot $workspacesRoot -Name repo-alpha } | Should Throw
            Get-Content (Join-Path $ws ".create-feature-workspace.ini") |
                Where-Object { $_ -match 'name = repo-alpha' } | Should Not BeNullOrEmpty
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    # -----------------------------------------------------------------------
    # Phase 0g: manual manifest edit + sync
    # -----------------------------------------------------------------------

    It "manually adding an entry to the manifest and running sync provisions it" {
        $feature = "manual-add-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        # Manually append an entry
        @"

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Add-Content (Join-Path $ws ".create-feature-workspace.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $true
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "manually removing an entry from the manifest and running sync removes the artifact" {
        $feature = "manual-rm-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path "$ws\repo-alpha" -Force | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        $shimDir = Join-Path $PSScriptRoot "shim-$feature"
        $oldPath = $env:PATH
        $env:PATH = "$(New-AddRemoveShim $shimDir);$oldPath"
        try {
            & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot
            Test-Path (Join-Path $ws "repo-alpha") | Should Be $false
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
        }
    }

    It "manually introduced invalid section causes sync to reject before changing anything" {
        $feature = "manual-invalid-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
unknown = bad
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.state.ini")
        { & $scriptPath -FeatureName $feature -Command sync -WorkspacesRoot $workspacesRoot } | Should Throw
        Test-Path (Join-Path $ws "repo-alpha") | Should Be $false
    }

    # -----------------------------------------------------------------------
    # Phase 1a / 0h: entry name validation
    # -----------------------------------------------------------------------

    It "entry name containing / is rejected" {
        $feature = "name-slash-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name "bad/name" -Path /fake/repo -Branch main } |
            Should Throw
    }

    It "entry name containing backslash is rejected" {
        $feature = "name-bs-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name "bad\name" -Path /fake/repo -Branch main } |
            Should Throw
    }

    It "entry name of . is rejected" {
        $feature = "name-dot-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name "." -Path /fake/repo -Branch main } |
            Should Throw
    }

    It "entry name of .. is rejected" {
        $feature = "name-dotdot-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name ".." -Path /fake/repo -Branch main } |
            Should Throw
    }

    It "entry name equal to .create-feature-workspace.ini is rejected" {
        $feature = "name-reserved1-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name ".create-feature-workspace.ini" -Path /fake/repo -Branch main } |
            Should Throw
    }

    It "entry name equal to .create-feature-workspace.state.ini is rejected" {
        $feature = "name-reserved2-$(Get-Random)"
        $ws = Join-Path $workspacesRoot $feature
        New-Item -ItemType Directory -Force -Path $ws | Out-Null
        @"
[workspace]
mode = worktree
"@ | Set-Content (Join-Path $ws ".create-feature-workspace.ini")
        { & $scriptPath -FeatureName $feature -Command add -WorkspacesRoot $workspacesRoot -Name ".create-feature-workspace.state.ini" -Path /fake/repo -Branch main } |
            Should Throw
    }
}
