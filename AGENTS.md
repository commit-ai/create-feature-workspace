# Repository Guidance

## Commands

- Install the Unix test dependency with `npm ci`.
- Run all Bash integration tests with `npm test`.
- Run one Bats file with `npx bats tests/create-feature-workspace.bats` or `npx bats tests/install-create-feature-workspace.bats`.
- Run one Bats test by name with `npx bats tests/create-feature-workspace.bats -f "Fails on malformed config"`.
- PowerShell tests use Pester: `Invoke-Pester tests/create-feature-workspace.tests.ps1`.
- There is no build step or separate lint command.

## Architecture

- `create-feature-workspace.sh` and `create-feature-workspace.ps1` are parallel Unix and Windows implementations. Both create and manage a workspace at `<workspaces-root>/<feature-name>/`.
- `create` reads an INI-like repository configuration, writes `.create-feature-workspace.desired.ini` as the desired manifest, then reconciles it into workspace artifacts and `.create-feature-workspace.provisioned.ini` as the provisioned state.
- `sync` reconciles the manifest with the state; `add` updates the manifest and provisions an entry; `remove` stages a manifest update, reconciles it, then promotes it only on success. The Bash CLI selects these with an optional first positional action; PowerShell uses `-Command`.
- Repository entries use `git -C <repo-path> worktree add -b <feature-name> <workspace-dir>/<entry-name> <branch>` in `worktree` mode. `--no-worktrees` / `-NoWorktrees` selects the persisted `symlink` mode during `create`. Entries with `type = folder` are always symlinked.
- `install-create-feature-workspace.sh` is Unix setup: it marks the Bash entry point executable and creates, preserves, or updates the `create-feature-workspace` symlink in the chosen bin directory.
- `install-create-feature-workspace.ps1` is Windows setup: it copies `create-feature-workspace.ps1` to the chosen bin directory and writes a `create-feature-workspace.cmd` wrapper alongside it. The `.cmd` wrapper is in `PATHEXT` so users can invoke `create-feature-workspace` without an extension from any terminal. No Administrator rights or Developer Mode are required. Re-running the installer is idempotent: it prints "Already up to date" if both files are current, and overwrites only what has changed (including replacing a legacy symlink from an older installation with a plain copy).
- Bats and Pester tests are integration tests. They put a fake `git` on `PATH` and assert filesystem effects, command arguments, and error behavior instead of creating real worktrees.

## Repository-Specific Conventions

- Keep the Bash and PowerShell implementations behaviorally aligned when changing workspace operations, validation, path handling, or `git worktree` invocation order. Update both integration suites for behavior changes.
- Source config sections describe entries with `name`, `path`, optional `branch`, and optional `type` (`repository` by default or `folder`). Repository entries need `branch` in worktree mode; symlink mode and folder entries need only `name` and `path`.
- Managed manifests must start with `[workspace]` and `mode = worktree|symlink`. Reject malformed sections, duplicate names or keys, invalid types, unknown manifest keys, and unsafe entry names rather than skipping them.
- Treat the manifest as desired state and the state file as the ownership record. Never replace an unmanaged destination; let `git worktree remove` fail for dirty worktrees, and do not advance the state after a failed operation.
- Expand only leading home forms (`~`, `~/...`, and `~\...` on PowerShell). Resolve relative workspace roots from the caller's current directory.
- Preserve fail-fast, visible failures: Bash uses `set -euo pipefail` with stderr errors; PowerShell uses `$ErrorActionPreference = "Stop"` and throws.
- The installer must not overwrite a non-symlink target, must leave an already-correct link alone, and may replace an outdated symlink.
- When changing CLI output or the `git worktree add` command shape, update the fake-git expectations and assertions in `tests/create-feature-workspace.bats`.
