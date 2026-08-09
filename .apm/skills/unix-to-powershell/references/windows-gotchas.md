# Additional Windows / PowerShell Gotchas

These come up less frequently than the main traps but matter for a polished port.

## Line endings

`Set-Content` writes with the system's default line ending (CRLF on Windows). If the file will be read on Unix too (e.g. a shared config), use `[System.IO.File]::WriteAllText($path, $content)` with explicit `\r\n` or `\n` as needed.

The `.cmd` wrapper must use CRLF — write it with `[System.IO.File]::WriteAllText` and `\r\n` explicitly so it survives being copied between machines.

## Console encoding

PowerShell 5.x defaults to the system's OEM codepage for console output. If your script outputs non-ASCII characters, set:
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```
PowerShell 7+ defaults to UTF-8 and this is usually not needed.

## `$LASTEXITCODE` vs exceptions

External commands (like `git`) set `$LASTEXITCODE` but do not throw even on failure when `$ErrorActionPreference = "Stop"`. Always check explicitly:
```powershell
git -C $path worktree add ...
if ($LASTEXITCODE -ne 0) { throw "git worktree add failed" }
```

## Redirection of stderr

`2>$null` works in PowerShell but suppresses all stderr. For capturing stderr to a variable:
```powershell
$output = git symbolic-ref --short HEAD 2>&1
```
Or redirect stderr to the success stream selectively:
```powershell
$result = & git ... 2>$null
```

## `-LiteralPath` vs `-Path`

`-Path` interprets wildcards (`[`, `]`, `*`, `?`). If paths come from user input or config files, always use `-LiteralPath` to avoid surprises with directory names containing brackets.

## `Test-Path` and race conditions

`Test-Path` followed by an operation is not atomic. For installer idempotency, prefer content comparison over existence checks — this also catches stale installs where the file exists but has old content.

## PowerShell version differences

- `??` (null coalescing) and `?.` (null conditional) require PowerShell 7+.
- `$env:HOME` is not set on Windows PowerShell 5.x — always fall back to `$env:USERPROFILE`.
- `[System.IO.Path]::PathSeparator` is `;` on Windows, `:` on Unix — use it instead of hardcoding.

## Pasting multi-line scripts

Multi-line PowerShell pasted into a CMD or PowerShell prompt fails because each line is submitted as a separate command. When writing diagnostic snippets for users to paste, either:
- Flatten to a single line using semicolons (`;`) as statement separators, OR
- Save to a `.ps1` file and dot-source it

Avoid newlines in copy-paste instructions destined for a Windows terminal.

## `which` is not `where` in PowerShell

In Bash, `which git` prints the path to `git`. The naive Windows translation is `where git` — but in PowerShell, `where` is an alias for `Where-Object` (the pipeline filter cmdlet). Typing `where git` silently produces no output and no error; it just waits for pipeline input.

The correct PowerShell equivalent of `which` is `Get-Command`:

```powershell
Get-Command git                                        # shows type, name, version, source
(Get-Command git).Source                               # path only — closest to `which` output
Get-Command git -ErrorAction SilentlyContinue          # returns $null if not found
```

To check whether a command is on PATH:
```powershell
if (-not (Get-Command create-feature-workspace -ErrorAction SilentlyContinue)) {
    throw "create-feature-workspace is not installed or not on PATH"
}
```

If you need the Windows executable for scripts that also run in `cmd.exe`, use `where.exe` (explicit extension) to bypass the alias.

## Executable bit has no equivalent

`chmod +x` is meaningless on Windows. Execution is controlled by ExecutionPolicy and file extension, not a permission bit. The installer does not need to set any permissions — just copy the file.
