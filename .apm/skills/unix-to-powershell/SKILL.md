---
name: unix-to-powershell
description: >
  Translates a Unix shell script into a working Windows PowerShell script, covering all the
  common traps that cause silent failures on real Windows machines: symlink privilege requirements,
  PATHEXT limitations, PowerShell -File invocation quirks (stop-parsing operator stripping dashes
  from --flag arguments), path separator differences, and installer idempotency patterns.
  Use this skill whenever the task involves porting, mirroring, or writing a Windows equivalent
  of a Bash/sh script — including installers, CLI entry points, setup scripts, and workspace tools.
  Also use it when a PowerShell script is "not working on Windows" and the root cause is unclear.
---

# Unix to PowerShell Porting Guide

## Purpose

Porting a Unix shell script to PowerShell is not a line-by-line translation — the two environments have fundamentally different assumptions about file types, invocation, permissions, and PATH resolution. This skill captures the concrete failure modes that bite real users on real Windows machines, and the patterns that reliably fix them.

## Before You Begin

Read the source Bash script completely before writing a single line of PowerShell. Identify:
- What the script installs, creates, or configures
- How it gets invoked (direct, via PATH, via wrapper)
- What idempotency guarantees it makes ("safe to run twice")
- What permissions it assumes

If there's an existing PowerShell counterpart that "isn't working," read both scripts and the error before diagnosing — the failure message usually names the exact line and reason.

## The Critical Traps (read these even if you think you know them)

These are ordered by how silently they fail — the worst ones produce no error at all.

### 1. Symlinks require elevated privileges on Windows

`New-Item -ItemType SymbolicLink` silently fails (access denied) unless Developer Mode is enabled or the shell is running as Administrator. Most users have neither.

**Never use symlinks in an installer.** Instead:
- Copy the script file with `Copy-Item`
- Write a `.cmd` wrapper alongside it (see trap 2)

Idempotency for copies: compare file content, not existence. Use `Get-Content -Raw` and string equality to detect "already up to date."

If the old version of a script used symlinks, detect and replace them on re-run:
```powershell
$existing = Get-Item $path -Force -ErrorAction SilentlyContinue
if ($existing -and $existing.LinkType -eq "SymbolicLink") {
    Remove-Item $path -Force
}
Copy-Item -Path $source -Destination $path -Force
```

### 2. `.ps1` is not in PATHEXT — users can't invoke it without the extension

On Windows, only extensions in `$env:PATHEXT` (`.COM .EXE .BAT .CMD` etc.) are resolved automatically. A `.ps1` file on PATH requires the user to type `script.ps1`, never just `script`.

**Always install a `.cmd` wrapper alongside the `.ps1`**:
```cmd
@echo off
powershell.exe -ExecutionPolicy RemoteSigned -File "%~dp0script-name.ps1" %*
```

- `%~dp0` expands to the `.cmd` file's own directory, so it finds the co-located `.ps1` regardless of the caller's working directory.
- `.cmd` is in `PATHEXT` by default — no privilege or Developer Mode required to create one.
- `-ExecutionPolicy RemoteSigned` prevents execution policy from blocking the script on machines with the default `Restricted` policy.

The installer copies both files and checks idempotency for both independently.

### 3. `--flag` arguments are mangled when called via `.cmd` → `powershell -File`

This is the subtlest trap and the hardest to diagnose.

When a user runs `myscript --help` via the `.cmd` wrapper, the chain is:
```
cmd.exe → powershell.exe -File myscript.ps1 --help
```

In PowerShell's `-File` invocation mode, `--` is a **stop-parsing operator**: it strips the leading dashes from everything that follows. So `--help` arrives as the bare string `help` (no dashes), which PowerShell then binds to the **first positional parameter** (whatever `$param` is at position 0). The `-Help` switch is never set.

The script then falls through to its default behavior and fails on a missing required parameter — with an error that points to a line far from the actual cause. This is extremely confusing to diagnose.

**Fix: intercept the de-dashed values at the top of the script body**, before any logic runs:
```powershell
# --help arrives as "help" when called via .cmd wrapper (PowerShell -File strips dashes)
if ($FirstPositionalParam -in @("help", "/?", "-h")) {
    $Help = $true
    $FirstPositionalParam = ""
}
```

Apply this pattern to every flag that users commonly pass from non-PowerShell terminals (`--help`, `--version`, `--dry-run`, etc.).

Also add a `-Help` switch to the `param()` block so native PowerShell callers can use it properly:
```powershell
param(
    [string]$FeatureName = "",
    # ... other params ...
    [switch]$Help
)
```

### 4. Path separators

- Use `Join-Path` everywhere — never string-concatenate with `/` or `\`.
- `$PSScriptRoot` gives the script's own directory (equivalent to `$(dirname "$0")`).
- Expand `~` manually: PowerShell's `~` works in the console but not reliably in `-File` mode or when passed as a string argument.

```powershell
$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
if ($path -eq "~") { $path = $homeDir }
elseif ($path.StartsWith("~/") -or $path.StartsWith("~\")) {
    $path = Join-Path $homeDir $path.Substring(2)
}
```

### 5. Error handling and fail-fast

Bash's `set -euo pipefail` has no single equivalent. Use:
```powershell
$ErrorActionPreference = "Stop"
```
at the top of every script. This makes terminating errors halt execution. For non-terminating errors (e.g. `Get-Item` on a missing path), use `-ErrorAction Stop` or check return values explicitly.

### 6. Executable bit has no equivalent

`chmod +x` is meaningless on Windows. Execution is controlled by ExecutionPolicy and file extension, not a permission bit. The installer does not need to set any permissions — just copy the file.

## Installer Checklist

When porting a Unix installer (`install-*.sh`) to PowerShell:

- [ ] Copy the script file (never symlink)
- [ ] Write a `.cmd` wrapper in the same directory
- [ ] Idempotency: check content equality for both files; print "Already up to date" and exit if both match
- [ ] Legacy upgrade: detect and replace any existing symlink at the target path
- [ ] Default bin dir: `~/.local/bin` (same as Unix convention); expand `~` manually
- [ ] PATH check: warn if the bin dir is not in `$env:PATH` and explain how to add it
- [ ] Help text: update to describe the new invocation (without `.ps1` extension)

## Main Script Checklist

When porting a CLI script (`do-thing.sh`) to PowerShell:

- [ ] `param()` block with named parameters matching the Bash flags
- [ ] Add `-Help` switch to `param()`
- [ ] Intercept `"help"`, `"/?"`, `"-h"` in the first positional parameter (stop-parsing trap, trap 3 above)
- [ ] `$ErrorActionPreference = "Stop"` at the top
- [ ] `Join-Path` for all path construction
- [ ] `~` expansion with `$env:HOME ?? $env:USERPROFILE` fallback
- [ ] Relative path resolution via `Join-Path (Get-Location).Path $relativePath`
- [ ] Idempotency and state file patterns carried over from Bash version

## Testing

Write Pester integration tests (not unit tests) that exercise the real filesystem:
- Create a temp directory per test, clean it up in `finally`
- Assert file content, not just existence — especially for the `.cmd` wrapper
- Test idempotency explicitly: run the installer twice, assert second run prints "Already up to date"
- Test the legacy-symlink upgrade path if applicable
- Test the `--help` / `/?` path by passing those values as positional arguments to the script

Follow TDD: write the Pester tests first to describe desired behavior, then implement the PowerShell to make them pass.

## Behavioral Alignment

Keep Unix and Windows implementations behaviorally aligned:
- Same validation rules (required params, invalid names, duplicate keys)
- Same error messages where possible
- Same data/config file format so artifacts are portable across OS
- Update both test suites when changing shared behavior
