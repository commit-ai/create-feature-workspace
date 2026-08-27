# create-feature-workspace

A tool-agnostic script for creating and managing feature workspaces across multiple repositories. It creates a single directory that holds git worktrees (or symlinks) for every repository involved in a feature, so you can open all of them together in any editor or IDE.

Available for Unix (Bash) and Windows (PowerShell). Both implementations behave identically.

## Table of Contents

- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Config File Format](#config-file-format)
- [Workspace Commands](#workspace-commands)
- [Workspace Modes](#workspace-modes)
- [Workspace Metadata Files](#workspace-metadata-files)
- [Claude Code Plugin](#claude-code-plugin)
- [Running Tests](#running-tests)
- [License](#license)

## How It Works

1. You provide a config file listing the repositories (and optional plain folders) that your feature spans.
2. The tool creates a workspace directory at `<workspaces-root>/<feature-name>/`.
3. Inside the workspace, each repository appears as a git worktree checked out to a branch named after the feature. Alternatively, all entries appear as symlinks (`--no-worktrees` / `-NoWorktrees`).
4. Two hidden files track what the workspace should contain (desired state) and what has been successfully provisioned (provisioned state), so later `sync`, `add`, and `remove` commands can reconcile changes safely.

## Requirements

- **Unix**: Bash 4+, Git
- **Windows**: PowerShell 5.1+, Git

## Installation

### Unix

Run the installer once from the directory where you cloned this repository:

```bash
./install-create-feature-workspace.sh
```

This creates a symlink in `~/.local/bin`. To use a different directory, pass `--bin-dir PATH`.

If `~/.local/bin` is not in your `PATH`, add this line to your shell profile:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

Run the installer once from the directory where you cloned this repository:

```powershell
.\install-create-feature-workspace.ps1
```

This copies the script and a `create-feature-workspace.cmd` wrapper to `~\.local\bin`. No Administrator rights or Developer Mode are required. If `~\.local\bin` is not in your `PATH`, the installer will tell you. Add it to your PowerShell profile to persist it across sessions.

## Quick Start

### Step 1: Create a config file

Create a file such as `repos.ini` that lists the repositories for your feature:

```ini
[repo1]
name = my-api
path = ~/src/my-api
branch = main

[repo2]
name = my-frontend
path = ~/src/my-frontend
branch = main
```

### Step 2: Create the workspace

**Unix:**

```bash
create-feature-workspace \
  --feature-name feature-x \
  --config-file ./repos.ini \
  --workspaces-root ~/workspaces
```

**Windows:**

```powershell
create-feature-workspace `
  -FeatureName feature-x `
  -ConfigFile .\repos.ini `
  -WorkspacesRoot ~/workspaces
```

This creates `~/workspaces/feature-x/` with a worktree for each repository, each on a branch named `feature-x`.

To run the script directly without installing it:

```bash
./create-feature-workspace.sh --feature-name feature-x --config-file ./repos.ini
```

```powershell
.\create-feature-workspace.ps1 -FeatureName feature-x -ConfigFile .\repos.ini
```

## Config File Format

Config files use an INI-like format. Each section defines one entry.

| Key | Required | Description |
|-----|----------|-------------|
| `name` | Yes | Directory name inside the workspace |
| `path` | Yes | Absolute or `~/...` path to the repository or folder |
| `branch` | Worktree mode only | Base branch for the new worktree |
| `type` | No | `repository` (default) or `folder` |

Entries with `type = folder` are always symlinked, regardless of workspace mode.

Example with a mix of repositories and a plain folder:

```ini
[repo1]
name = backend
path = ~/src/backend
branch = main

[repo2]
name = frontend
path = ~/src/frontend
branch = main

[shared]
name = shared-config
path = ~/src/shared-config
type = folder
```

## Workspace Commands

Run these commands from inside the workspace directory (the directory that contains `.create-feature-workspace.desired.ini`):

| Action | Unix | PowerShell |
|--------|------|------------|
| Sync desired state to disk | `create-feature-workspace sync` | `create-feature-workspace -Command sync` |
| Add an entry | `create-feature-workspace add --folder-name NAME --folder-path PATH [--branch BRANCH] [--type repository\|folder]` | `create-feature-workspace -Command add -FolderName NAME -FolderPath PATH [-Branch BRANCH]` |
| Remove an entry | `create-feature-workspace remove --folder-name NAME` | `create-feature-workspace -Command remove -FolderName NAME` |

`add` auto-detects the current branch of the target repository in worktree mode when `--branch` / `-Branch` is not provided.

## Workspace Modes

**Worktree mode** (default): each repository entry is checked out as a git worktree on a branch named after the feature. Use this when you want isolated branches per feature.

**Symlink mode** (`--no-worktrees` / `-NoWorktrees` during `create`): all entries are created as symlinks to the source paths. Use this when you want to work on existing branches without creating new ones.

The mode is recorded in the workspace manifest and applies to all subsequent `sync` and `add` operations.

## Workspace Metadata Files

Each workspace contains two hidden metadata files:

- `.create-feature-workspace.desired.ini` — the desired workspace definition. Edit this file to change entries, then run `sync`.
- `.create-feature-workspace.provisioned.ini` — the provisioned record. Managed by the tool; do not edit.

The two files may differ while changes are being reconciled. The provisioned record lets the tool distinguish entries it owns from unrelated files in the workspace.

## Claude Code Plugin

A Claude Code plugin in `plugins/create-feature-workspace/` provides guided assistance for all workspace operations. It includes four skills:

| Skill | Purpose |
|-------|---------|
| `install-create-feature-workspace` | Guided installation on Unix and Windows |
| `use-create-feature-workspace` | Usage reference for all commands and config format |
| `add-to-feature-workspace` | Step-by-step guidance for adding a new entry |
| `remove-from-feature-workspace` | Step-by-step guidance for removing an entry |

The plugin is registered in `.claude-plugin/marketplace.json` and can be installed via the Claude Code marketplace.

## Running Tests

Install the test dependency:

```bash
npm ci
```

Run all Bash integration tests:

```bash
npm test
```

Run a single test file:

```bash
npx bats tests/create-feature-workspace.bats
```

Run a single test by name:

```bash
npx bats tests/create-feature-workspace.bats -f "Fails on malformed config"
```

Run PowerShell tests (requires Pester):

```powershell
Invoke-Pester tests/create-feature-workspace.tests.ps1
```

---

Copyright © 2026 Commit AI. All rights reserved.
