---
name: install-create-feature-workspace
description: >
  Install and use the `create-feature-workspace` script, which creates and manages
  feature workspaces (similar to Cursor workspaces): a directory that collects git
  worktrees or symlinks for all repositories involved in a feature branch.
  Use this skill whenever the user wants to install the script, create a workspace,
  or run any workspace command (sync, add, remove). Also use it when the user
  asks about managing multi-repo feature branches, Cursor-style workspaces, or
  when `create-feature-workspace` fails and a fresh installation might help.
  This skill fully supports Unix (macOS/Linux) and Windows.
---

# create-feature-workspace

## What It Does

`create-feature-workspace` creates a workspace directory that aggregates all the
repositories you need for a feature branch into a single folder — one git worktree
(or symlink) per repository. This is the same concept as Cursor workspaces but
works from the command line and tracks state across machines.

Typical flow:
1. Write a config INI listing your repositories and branches.
2. Run `create-feature-workspace --feature-name my-feature --config-file repos.ini`.
3. Open the resulting folder in your editor as a multi-root workspace.
4. Use `create-feature-workspace sync/add/remove` from inside the workspace to keep it current.

---

## Installing the Script

The skill bundles the platform installer scripts. Run the one that matches the OS.

### Unix (macOS / Linux)

Run the bundled shell installer — it marks the main script executable and creates a
symlink in the bin directory so you can invoke `create-feature-workspace` from anywhere.

```
bash <skill-dir>/scripts/install-create-feature-workspace.sh [--bin-dir ~/.local/bin]
```

For the exact installation logic and idempotency rules, read:
`references/unix-install.md`

### Windows (PowerShell)

Run the bundled PowerShell installer — it copies the script and writes a `.cmd` wrapper
so you can invoke `create-feature-workspace` from `cmd.exe`, PowerShell, or any terminal
without typing the `.ps1` extension.

```powershell
pwsh -ExecutionPolicy RemoteSigned -File <skill-dir>\scripts\install-create-feature-workspace.ps1 [-BinDir ~\.local\bin]
```

For the exact installation logic, `.cmd` wrapper details, and PATH setup, read:
`references/windows-install.md`

---

## Running the Script

After installation, `create-feature-workspace` is on PATH and works the same on
both platforms — Unix flags use `--long-name`, PowerShell uses `-PascalCase`.

See the platform reference for the exact invocation syntax:
- Unix: `references/unix-install.md` (Usage section)
- Windows: `references/windows-install.md` (Usage section)

### Quick reference

| Action | Unix | PowerShell |
|--------|------|------------|
| Create workspace | `create-feature-workspace --feature-name NAME --config-file PATH` | `create-feature-workspace -FeatureName NAME -ConfigFile PATH` |
| Sync workspace | `create-feature-workspace sync` (from workspace dir) | `create-feature-workspace -Command sync` (from workspace dir) |
| Add entry | `create-feature-workspace add --folder-name NAME --folder-path PATH` | `create-feature-workspace -Command add -FolderName NAME -FolderPath PATH` |
| Remove entry | `create-feature-workspace remove --folder-name NAME` | `create-feature-workspace -Command remove -FolderName NAME` |

### Config file format (INI)

```ini
[my-repo]
name = my-repo
path = ~/src/my-repo
branch = main

[another-repo]
name = another-repo
path = ~/src/another-repo
branch = feature/xyz

[docs-folder]
name = docs
path = ~/Dropbox/docs
type = folder
```

- `type` defaults to `repository`; use `type = folder` for non-git directories (creates a symlink regardless of mode).
- `branch` is the worktree base branch for `repository` entries.
- Pass `--no-worktrees` / `-NoWorktrees` to use symlinks for all entries (no git worktrees).

---

## Troubleshooting a Failed Run

If `create-feature-workspace` fails with "command not found" or a script error:

1. **Verify installation** — check whether the script is on PATH:
   - Unix: `which create-feature-workspace`
   - Windows: `where create-feature-workspace`

2. **Re-run the installer** — it is idempotent (safe to run twice). If the bin
   directory is not in PATH, the installer will print a warning with the exact
   `export PATH=...` line to add to your shell profile.

3. **Check script permissions** (Unix only) — if `create-feature-workspace` is
   found but gives "Permission denied", run `chmod +x $(which create-feature-workspace)`.

4. **Windows execution policy** — if PowerShell refuses to run the script, run:
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` then retry the installer.

5. **Inside a managed workspace** — `sync`, `add`, and `remove` must be run from
   inside the workspace directory (the one containing `.create-feature-workspace.desired.ini`).
   `cd` into the workspace first.

---

## Deciding Which Mode to Use

| Mode | When to use |
|------|-------------|
| `worktree` (default) | You want isolated git worktrees per feature; clean git history separation |
| `symlink` (`--no-worktrees`) | You want to share a single checkout across features; faster but less isolated |

The mode is stored in the manifest and cannot be changed after creation. To switch modes, remove the workspace and recreate it.
