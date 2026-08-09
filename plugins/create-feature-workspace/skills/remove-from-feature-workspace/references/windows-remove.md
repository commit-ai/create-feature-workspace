# remove-from-feature-workspace — Windows Syntax Reference

## Invocation

The `.cmd` wrapper is on PATH — invoke it from `cmd.exe`, PowerShell, or Windows
Terminal without typing an extension or `pwsh` prefix.

Run from **inside** the workspace directory:

```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command remove `
  -FolderName NAME
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Command remove` | Yes | Selects the `remove` action |
| `-FolderName NAME` | Yes | Exact name of the entry to remove (as it appears in the manifest) |

`-Command remove` accepts only `-FolderName`. Passing `-FolderPath`, `-Branch`,
`-FeatureName`, `-WorkspacesRoot`, `-ConfigFile`, or `-NoWorktrees` will produce an
error.

## Examples

**Remove a repository entry — PowerShell:**
```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command remove -FolderName payments
```

**Remove a repository entry — cmd.exe:**
```cmd
cd C:\workspaces\my-feature
create-feature-workspace -Command remove -FolderName payments
```

**Remove a plain-folder entry — PowerShell:**
```powershell
cd C:\workspaces\my-feature
create-feature-workspace -Command remove -FolderName shared-docs
```

## Finding Valid Entry Names

List the entries in the manifest before running `remove`:

```powershell
Get-Content .create-feature-workspace.desired.ini
```

Look for lines that begin with `name =` — those values are the valid names.
Names are **case-insensitive** on Windows (the filesystem is case-insensitive).

## What Gets Removed

| Entry type | What `remove` does |
|------------|-------------------|
| `repository` in **worktree** mode | Calls `git worktree remove <workspace-dir>\<name>` — removes the checkout, not the branch |
| `repository` in **symlink** mode | Deletes the symlink at `<workspace-dir>\<name>` |
| `folder` (any mode) | Deletes the symlink at `<workspace-dir>\<name>` |

The underlying repository and all its branches are **not affected**.

## Failure Behavior

- If the worktree has uncommitted changes, `git worktree remove` will refuse and the
  manifest is left unchanged. Commit or stash the changes, then retry.
- If `-FolderName` does not match any entry in the manifest, the command exits with
  an error immediately.

## Symlink Note

Symlink deletion (for `type = folder` entries and repository entries in symlink mode)
requires **Developer Mode** enabled or **Administrator** rights. Worktree-mode
repository entries use `git worktree remove` and have no such requirement.
