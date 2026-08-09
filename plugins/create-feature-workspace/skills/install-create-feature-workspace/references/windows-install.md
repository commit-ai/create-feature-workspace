# Windows Installation & Usage Reference

## Installing

The installer script is at `scripts\install-create-feature-workspace.ps1` inside this skill folder.

```powershell
powershell.exe -ExecutionPolicy RemoteSigned -File <skill-dir>\scripts\install-create-feature-workspace.ps1 [-BinDir PATH]
```

Or from within PowerShell:
```powershell
& "<skill-dir>\scripts\install-create-feature-workspace.ps1" [-BinDir PATH]
```

**Parameters:**
- `-BinDir PATH` — directory where the files are installed (default: `~\.local\bin`)
- `-Help` — show usage

**What the installer does:**
1. Copies `create-feature-workspace.ps1` (co-located in `scripts\`) to the bin directory.
2. Writes a `create-feature-workspace.cmd` wrapper in the same directory.
3. The `.cmd` wrapper lets you invoke `create-feature-workspace` without the `.ps1` extension from any terminal (cmd, PowerShell, Windows Terminal).
4. If both files are already present and up to date (content equality check), prints "Already up to date" and exits 0 (idempotent).
5. Detects and replaces any legacy symlink left by an older installer version.
6. If the bin dir is not in `%PATH%`, prints a note telling the user to add it.

**No Administrator rights or Developer Mode required.**

**Adding the bin dir to PATH (if needed):**

Run this once in PowerShell (adds to your user profile permanently):

```powershell
$binDir = "$HOME\.local\bin"
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$binDir;$currentPath",
        "User"
    )
    Write-Host "Added $binDir to PATH. Restart your terminal."
}
```

Or add it manually via: **System Properties → Environment Variables → User Variables → Path → New**.

**If PowerShell refuses to run the script (execution policy):**

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## The `.cmd` Wrapper

The installer places `create-feature-workspace.cmd` alongside the `.ps1` file. This wrapper is what makes `create-feature-workspace` invocable without an extension. Its contents:

```cmd
@echo off
powershell.exe -ExecutionPolicy RemoteSigned -File "%~dp0create-feature-workspace.ps1" %*
```

- `%~dp0` resolves to the `.cmd` file's own directory, so the `.ps1` is always found regardless of where you run the command from.
- `-ExecutionPolicy RemoteSigned` bypasses the default `Restricted` policy.
- `.cmd` is in `PATHEXT` by default, so Windows resolves it automatically.

**Known quirk — double-dash flags via `.cmd`:**

When passing `--help` through the `.cmd` wrapper, PowerShell's `-File` mode strips the dashes and passes `help` as the first positional argument. The script handles this transparently, so `create-feature-workspace --help` works correctly from `cmd.exe`.

---

## Usage

```
create-feature-workspace [-Command COMMAND] [OPTIONS]
```

### Commands (`-Command`, optional — default: `create`)

| Command | Description |
|---------|-------------|
| `create` | Create a new workspace |
| `sync` | Reconcile the manifest with the filesystem |
| `add` | Add a new entry to an existing workspace |
| `remove` | Remove an entry from an existing workspace |

### Options for `create`

| Parameter | Description |
|-----------|-------------|
| `-FeatureName NAME` | Name of the workspace (required) |
| `-ConfigFile PATH` | INI config file listing repositories/folders (required) |
| `-WorkspacesRoot PATH` | Root directory for workspaces (default: `~/workspaces`) |
| `-NoWorktrees` | Use symlinks instead of git worktrees |
| `-Help` | Show usage |

### Options for `add`

| Parameter | Description |
|-----------|-------------|
| `-FolderName NAME` | Entry name (required) |
| `-FolderPath PATH` | Path to the repo or folder (required) |
| `-Branch BRANCH` | Branch to use; auto-detected from current HEAD if omitted |
| `-Type repository\|folder` | Entry type (default: `repository`) |

### Options for `remove`

| Parameter | Description |
|-----------|-------------|
| `-FolderName NAME` | Entry name to remove (required) |

### Examples

```powershell
# Create a new workspace
create-feature-workspace -FeatureName my-feature -ConfigFile ~/repos.ini

# Create with a custom workspaces root
create-feature-workspace -FeatureName my-feature -ConfigFile ~/repos.ini -WorkspacesRoot D:\workspaces

# Create with symlinks instead of worktrees
create-feature-workspace -FeatureName my-feature -ConfigFile ~/repos.ini -NoWorktrees

# Sync an existing workspace (run from inside the workspace dir)
Set-Location ~/workspaces/my-feature
create-feature-workspace -Command sync

# Add a repository entry
create-feature-workspace -Command add `
  -FolderName backend `
  -FolderPath ~/src/backend `
  -Branch feature/my-feature

# Add a folder (non-git) entry
create-feature-workspace -Command add `
  -FolderName docs `
  -FolderPath ~/Documents/project-docs `
  -Type folder

# Remove an entry
create-feature-workspace -Command remove -FolderName backend

# Show help
create-feature-workspace -Help
# or from cmd.exe:
create-feature-workspace --help
```

---

## Workspace Files

Two files are created inside the workspace directory:

| File | Description |
|------|-------------|
| `.create-feature-workspace.desired.ini` | Desired state manifest — edit this, then run `sync` |
| `.create-feature-workspace.provisioned.ini` | Provisioned state record — managed automatically; do not edit |

---

## Config File Format

Source config passed to `-ConfigFile` on `create`:

```ini
[section-name]
name = display-name
path = ~/src/my-repo
branch = main

[another]
name = another
path = ~/src/another
branch = feature/xyz
type = repository

[docs]
name = docs
path = ~/shared/docs
type = folder
```

- `type` is optional, defaults to `repository`.
- `branch` is required for `repository` entries in `worktree` mode; optional in `symlink` mode.
- Section names are arbitrary; `name` inside the section is what appears in the workspace.
- Paths can use `~` (expanded to `$HOME` / `$USERPROFILE`) or absolute Windows paths.

---

## Symlinks on Windows

Symlink creation (`New-Item -ItemType SymbolicLink`) requires either Developer Mode
or Administrator rights on Windows. The workspace script uses symlinks for:
- All entries when `-NoWorktrees` is specified.
- `type = folder` entries regardless of mode.

If symlink creation fails, either:
1. Enable Developer Mode: **Settings → For developers → Developer Mode → On**.
2. Run the terminal as Administrator.
3. Use worktree mode (the default) for repository entries to avoid symlinks entirely.
