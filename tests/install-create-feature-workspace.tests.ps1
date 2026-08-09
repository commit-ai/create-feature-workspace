
Describe "install-create-feature-workspace.ps1" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\install-create-feature-workspace.ps1"
        $tempRoot = Join-Path $PSScriptRoot "temp-installer"
    }

    AfterAll {
        if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
    }

    It "Creates a symlink in the requested bin directory" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        try {
            & $scriptPath -BinDir $binDir
            $linkPath = Join-Path $binDir "create-feature-workspace.ps1"
            Test-Path $linkPath | Should -Be $true
            $item = Get-Item $linkPath -Force
            $item.LinkType | Should -Be "SymbolicLink"
            $expectedTarget = (Get-Item (Join-Path $PSScriptRoot "..\create-feature-workspace.ps1")).FullName
            $item.Target | Should -Be $expectedTarget
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }

    It "Fails when target path is a regular file" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        $linkPath = Join-Path $binDir "create-feature-workspace.ps1"
        "placeholder" | Set-Content $linkPath
        try {
            { & $scriptPath -BinDir $binDir } | Should -Throw
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
            $expectedLink = Join-Path $fakeHome ".local\bin\create-feature-workspace.ps1"
            Test-Path $expectedLink | Should -Be $true
            (Get-Item $expectedLink -Force).LinkType | Should -Be "SymbolicLink"
            $output | Should -Match "Installed symlink at:"
            $output | Should -Match "is not currently in PATH"
            $output | Should -Not -Match "Created symlink:"
        } finally {
            $env:HOME = $originalHome
            $env:PATH = $originalPath
            if (Test-Path $fakeHome) { Remove-Item -Recurse -Force $fakeHome }
        }
    }

    It "Is idempotent when symlink already points to correct target" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        try {
            & $scriptPath -BinDir $binDir | Out-Null
            $output = & $scriptPath -BinDir $binDir *>&1 | Out-String
            $output | Should -Match "Symlink already configured"
        } finally {
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }

    It "Replaces an outdated symlink pointing to a different target" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        $linkPath = Join-Path $binDir "create-feature-workspace.ps1"
        $fakeTarget = Join-Path $tempRoot "fake-$(Get-Random).ps1"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        "# fake" | Set-Content $fakeTarget
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $fakeTarget | Out-Null
        try {
            & $scriptPath -BinDir $binDir
            $item = Get-Item $linkPath -Force
            $item.LinkType | Should -Be "SymbolicLink"
            $expectedTarget = (Get-Item (Join-Path $PSScriptRoot "..\create-feature-workspace.ps1")).FullName
            $item.Target | Should -Be $expectedTarget
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

    It "Prints 'Created symlink' when bin dir is in PATH" {
        $binDir = Join-Path $tempRoot "bin-$(Get-Random)"
        $originalPath = $env:PATH
        try {
            $env:PATH = $binDir + [System.IO.Path]::PathSeparator + $env:PATH
            $output = & $scriptPath -BinDir $binDir *>&1 | Out-String
            $output | Should -Match "Created symlink:"
            $output | Should -Not -Match "is not currently in PATH"
        } finally {
            $env:PATH = $originalPath
            if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
        }
    }
}
