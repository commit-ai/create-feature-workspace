# add-to-feature-workspace — Windows Syntax Reference

## Invocation

The `.cmd` wrapper is on PATH — invoke it from `cmd.exe`, PowerShell, or Windows
Terminal without typing an extension or `pwsh` prefix.

Run from **inside** the workspace directory:

```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command add `
  -FolderName NAME `
  -FolderPath PATH `
  [-Branch BRANCH] `
  [-Type repository|folder]
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Command add` | Yes | — | Selects the `add` action |
| `-FolderName NAME` | Yes | — | Entry name; becomes the subdirectory in the workspace |
| `-FolderPath PATH` | Yes | — | Path to the repo or folder; supports leading `~` |
| `-Branch BRANCH` | No | auto-detected | Branch to use for repository entries in worktree mode |
| `-Type repository\|folder` | No | `repository` | `repository` for a git repo; `folder` for a plain directory |

## Examples

**Add a git repository (branch explicit) — PowerShell:**
```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command add `
  -FolderName payments `
  -FolderPath C:\src\payments-service `
  -Branch main
```

**Add a git repository (branch explicit) — cmd.exe:**
```cmd
cd C:\workspaces\my-feature
create-feature-workspace -Command add -FolderName payments -FolderPath C:\src\payments-service -Branch main
```

**Add a git repository (branch auto-detected from HEAD):**
```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command add `
  -FolderName payments `
  -FolderPath C:\src\payments-service
```

**Add a plain folder (no git, no branch):**
```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command add `
  -FolderName shared-docs `
  -FolderPath C:\Users\me\Dropbox\project-docs `
  -Type folder
```

## Path Expansion

- Leading `~` and `~\…` in `-FolderPath` are expanded to the user's home directory.
- Relative paths in `-FolderPath` are resolved from `$PWD` at invocation time.

## Notes

- `-FolderName`, `-FolderPath`, `-Branch`, and `-Type` are the only parameters
  accepted by `add`. Passing `-FeatureName`, `-WorkspacesRoot`, `-ConfigFile`, or
  `-NoWorktrees` will produce an error.
- The operation is atomic: the manifest is only updated if provisioning succeeds.

## Symlink Warning

`-Type folder` entries (and repository entries under `-NoWorktrees`) use Windows
symlinks. These require **Developer Mode** enabled or **Administrator** rights.
Worktree mode (the default for repository entries) has no such requirement.
