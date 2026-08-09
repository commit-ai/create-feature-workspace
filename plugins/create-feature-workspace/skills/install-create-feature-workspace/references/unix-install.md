# Unix Installation & Usage Reference

## Installing

The installer script is at `scripts/install-create-feature-workspace.sh` inside this skill folder.

```bash
bash <skill-dir>/scripts/install-create-feature-workspace.sh [--bin-dir PATH]
```

**Options:**
- `--bin-dir PATH` — directory where the symlink is created (default: `~/.local/bin`)
- `-h`, `--help` — show usage

**What the installer does:**
1. Resolves the absolute path to `create-feature-workspace.sh` (co-located in `scripts/`).
2. Creates the bin directory if it doesn't exist (`mkdir -p`).
3. Marks `create-feature-workspace.sh` executable (`chmod +x`).
4. Creates a symlink `<bin-dir>/create-feature-workspace -> <absolute-path>/create-feature-workspace.sh`.
5. If the symlink already points to the same target, prints "Symlink already configured" and exits 0 (idempotent).
6. If the bin dir is not in `$PATH`, prints a note telling the user to add it.
7. Refuses to replace a non-symlink at the target path (safety guard).

**Adding the bin dir to PATH (if needed):**

```bash
# bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

---

## Usage

```
create-feature-workspace [ACTION] [OPTIONS]
```

### Actions (first positional argument, optional — default: `create`)

| Action | Description |
|--------|-------------|
| *(none)* or `create` | Create a new workspace |
| `sync` | Reconcile the manifest with the filesystem |
| `add` | Add a new entry to an existing workspace |
| `remove` | Remove an entry from an existing workspace |

### Options for `create`

| Flag | Description |
|------|-------------|
| `--feature-name NAME` | Name of the workspace (required) |
| `--config-file PATH` | INI config file listing repositories/folders (required) |
| `--workspaces-root PATH` | Root directory for workspaces (default: `~/workspaces`) |
| `--no-worktrees` | Use symlinks instead of git worktrees |
| `-h`, `--help` | Show usage |

### Options for `add`

| Flag | Description |
|------|-------------|
| `--folder-name NAME` | Entry name (required) |
| `--folder-path PATH` | Path to the repo or folder (required) |
| `--branch BRANCH` | Branch to use; auto-detected from current HEAD if omitted |
| `--type repository\|folder` | Entry type (default: `repository`) |

### Options for `remove`

| Flag | Description |
|------|-------------|
| `--folder-name NAME` | Entry name to remove (required) |

### Examples

```bash
# Create a new workspace
create-feature-workspace \
  --feature-name my-feature \
  --config-file ~/repos.ini \
  --workspaces-root ~/workspaces

# Create with symlinks instead of worktrees
create-feature-workspace \
  --feature-name my-feature \
  --config-file ~/repos.ini \
  --no-worktrees

# Sync an existing workspace (run from inside the workspace dir)
cd ~/workspaces/my-feature
create-feature-workspace sync

# Add a repository entry
create-feature-workspace add \
  --folder-name backend \
  --folder-path ~/src/backend \
  --branch feature/my-feature

# Add a folder (non-git) entry
create-feature-workspace add \
  --folder-name docs \
  --folder-path ~/Dropbox/project-docs \
  --type folder

# Remove an entry
create-feature-workspace remove --folder-name backend
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

Source config passed to `--config-file` on `create`:

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
