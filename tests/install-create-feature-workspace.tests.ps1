
Describe "install-create-feature-workspace.ps1" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\install-create-feature-workspace.ps1"
        $tempRoot = Join-Path $PSScriptRoot "temp-installer"
        $expectedPsContent = Get-Content (Join-Path $PSScriptRoot "..\create-feature-workspace.ps1") -Raw
        $expectedCmdContent = "@echo off`r`npowershell.exe -ExecutionPolicy RemoteSigned -File `"%~dp0create-feature-workspace.ps1`" %*`r`n"
    }

    AfterAll {
        if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
    }

    It "Copies script and creates .cmd wrapper in the requested bin directory" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        try {
            & $scriptPath -BinDir $binDir
            $psPath  = Join-Path $binDir "create-feature-workspace.ps1"
            $cmdPath = Join-Path $binDir "create-feature-workspace.cmd"
            Test-Path $psPath  | Should -Be $true
            Test-Path $cmdPath | Should -Be $true
            (Get-Item $psPath -Force).LinkType | Should -BeNullOrEmpty
            Get-Content $psPath -Raw | Should -Be $expectedPsContent
            Get-Content $cmdPath -Raw | Should -Be $expectedCmdContent
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }

    It "Uses HOME for the default bin dir and explains PATH setup" {
        $fakeHome = Join-Path $tempRoot "home-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $fakeHome | Out-Null
        $originalHome = $env:HOME
        $originalPath = $env:PATH
        try {
            $env:HOME = $fakeHome
            $env:PATH = "C:\Windows\System32"
            $output = & $scriptPath *>&1 | Out-String
            $psPath  = Join-Path $fakeHome ".local\bin\create-feature-workspace.ps1"
            $cmdPath = Join-Path $fakeHome ".local\bin\create-feature-workspace.cmd"
            Test-Path $psPath  | Should -Be $true
            Test-Path $cmdPath | Should -Be $true
            (Get-Item $psPath -Force).LinkType | Should -BeNullOrEmpty
            $output | Should -Match "Installed:"
            $output | Should -Match "is not currently in PATH"
        } finally {
            $env:HOME = $originalHome
            $env:PATH = $originalPath
            if (Test-Path $fakeHome) { Remove-Item -Recurse -Force $fakeHome }
        }
    }

    It "Is idempotent: second run prints 'Already up to date'" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        try {
            & $scriptPath -BinDir $binDir | Out-Null
            $output = & $scriptPath -BinDir $binDir *>&1 | Out-String
            $output | Should -Match "Already up to date"
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }

    It "Overwrites stale copy when .ps1 content differs" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        $psPath = Join-Path $binDir "create-feature-workspace.ps1"
        "# stale content" | Set-Content $psPath
        try {
            & $scriptPath -BinDir $binDir
            Get-Content $psPath -Raw | Should -Be $expectedPsContent
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }

    It "Replaces an old symlink with a copy" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        $psPath = Join-Path $binDir "create-feature-workspace.ps1"
        $fakeTarget = Join-Path $tempRoot "fake-$(Get-Random).ps1"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        "# fake" | Set-Content $fakeTarget
        New-Item -ItemType SymbolicLink -Path $psPath -Target $fakeTarget | Out-Null
        try {
            & $scriptPath -BinDir $binDir
            $item = Get-Item $psPath -Force
            $item.LinkType | Should -BeNullOrEmpty
            Get-Content $psPath -Raw | Should -Be $expectedPsContent
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
            if (Test-Path $fakeTarget) { Remove-Item $fakeTarget }
        }
    }

    It "Fails when source script does not exist" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        $fakeInstallerDir = Join-Path $tempRoot "fakedir-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $fakeInstallerDir | Out-Null
        $fakeInstaller = Join-Path $fakeInstallerDir "install-create-feature-workspace.ps1"
        Get-Content $scriptPath | Set-Content $fakeInstaller
        try {
            { & $fakeInstaller -BinDir $binDir } | Should -Throw
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
            if (Test-Path $fakeInstallerDir) { Remove-Item -Recurse -Force $fakeInstallerDir }
        }
    }

    It "Creates bin dir if it does not exist" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)\nested"
        try {
            Test-Path $binDir | Should -Be $false
            & $scriptPath -BinDir $binDir
            Test-Path $binDir | Should -Be $true
        } finally {
            if (Test-Path (Split-Path $binDir)) { Remove-Item -Recurse -Force (Split-Path $binDir) }
        }
    }

    It "Prints 'Installed:' when bin dir is in PATH" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        $originalPath = $env:PATH
        try {
            $env:PATH = $binDir + [System.IO.Path]::PathSeparator + $env:PATH
            $output = & $scriptPath -BinDir $binDir *>&1 | Out-String
            $output | Should -Match "Installed:"
            $output | Should -Not -Match "is not currently in PATH"
        } finally {
            $env:PATH = $originalPath
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }
}
