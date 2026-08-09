# create-feature-workspace — Windows Usage Reference

## Invocation

After installation, `create-feature-workspace` is on PATH as a `.cmd` wrapper that
calls the underlying `.ps1` script. You can invoke it from `cmd.exe`, PowerShell, or
Windows Terminal without typing the extension or the `pwsh` prefix.

The action is selected by the `-Command` parameter (default `create`):

```powershell
create-feature-workspace [-Command ACTION] [PARAMETERS]
```

---

## create (default action)

Creates a new workspace directory, writes the manifest, and provisions all entries.

```powershell
create-feature-workspace `
  -FeatureName NAME `
  -ConfigFile PATH `
  [-WorkspacesRoot PATH] `
  [-NoWorktrees]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-FeatureName NAME` | Yes | — | Name of the workspace; becomes the directory name |
| `-ConfigFile PATH` | Yes | — | Path to the INI source config file |
| `-WorkspacesRoot PATH` | No | `~/workspaces` | Parent directory for the workspace |
| `-NoWorktrees` | No | off | Use symlinks for all entries instead of git worktrees |
| `-Help` | No | — | Print usage and exit |

Example:

```powershell
create-feature-workspace `
  -FeatureName my-feature `
  -ConfigFile C:\projects\repos.ini `
  -WorkspacesRoot C:\workspaces
```

Creates `C:\workspaces\my-feature\` with one worktree per repository entry.

> **Note:** Windows symlinks (used by `-NoWorktrees` and `type = folder` entries)
> require Developer Mode enabled or Administrator rights. Worktree mode (the default)
> has no such requirement.

---

## sync

Reconcile the workspace with its manifest. Run from **inside** the workspace directory.

```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command sync
```

No additional parameters. Reads `.create-feature-workspace.desired.ini` and brings the
filesystem in line with it.

---

## add

Add a new entry to an existing workspace. Run from **inside** the workspace directory.

```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command add `
  -FolderName NAME `
  -FolderPath PATH `
  [-Branch BRANCH] `
  [-Type repository|folder]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-FolderName NAME` | Yes | — | Name of the new entry (subdirectory in the workspace) |
| `-FolderPath PATH` | Yes | — | Absolute or `~`-prefixed path to the repo or folder |
| `-Branch BRANCH` | No | auto-detected | Branch to use (repository entries in worktree mode only) |
| `-Type repository\|folder` | No | `repository` | Entry type |

If `-Branch` is omitted for a repository entry in worktree mode, the current HEAD
branch of that repository is detected automatically via `git symbolic-ref`.

Example:

```powershell
create-feature-workspace -Command add `
  -FolderName payments `
  -FolderPath C:\src\payments-service `
  -Branch main
```

---

## remove

Remove an entry from an existing workspace. Run from **inside** the workspace directory.

```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command remove -FolderName NAME
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-FolderName NAME` | Yes | Name of the entry to remove |

If the entry is a git worktree with uncommitted changes, `git worktree remove` will fail
and the manifest is left unchanged. Commit or stash before removing.

---

## Path Expansion

- Leading `~` and `~\…` are expanded to the user's home directory.
- `-WorkspacesRoot` values support `~` expansion.
- `-FolderPath` values support the same `~` expansion.
- Relative `-WorkspacesRoot` is resolved from `$PWD` at invocation time.

---

## Guards

These parameters are only accepted by `create` and will error on `add`, `remove`, or `sync`:
`-FeatureName`, `-WorkspacesRoot`, `-ConfigFile`, `-NoWorktrees`.

---

## Invoking from cmd.exe vs PowerShell

The `.cmd` wrapper is what's on PATH — it forwards all arguments to `pwsh -File …`.
Both of these work identically:

```cmd
REM cmd.exe
create-feature-workspace -FeatureName my-feature -ConfigFile repos.ini
```

```powershell
# PowerShell
create-feature-workspace -FeatureName my-feature -ConfigFile repos.ini
```

`--help` and `/?` also work from `cmd.exe` thanks to the wrapper's argument
normalization.
