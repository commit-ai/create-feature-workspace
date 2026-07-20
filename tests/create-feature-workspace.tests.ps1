
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
}
