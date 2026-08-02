# Repository guidance

## Commands

- Install the Bats dependency with `npm ci`.
- Run all Unix integration tests with `npm test`.
- Run one Bats file with `npx bats tests/create-feature-workspace.bats` or `npx bats tests/install-create-feature-workspace.bats`.
- Run a single Bats test by name with `npx bats tests/create-feature-workspace.bats -f "Fails on malformed config"`.
- PowerShell coverage is in `tests/create-feature-workspace.tests.ps1` and uses Pester; run it where Pester is available with `Invoke-Pester tests/create-feature-workspace.tests.ps1`.
- There is no build step or separate lint command.

## Architecture

- `create-feature-workspace.sh` and `create-feature-workspace.ps1` are equivalent Unix and Windows entry points. They parse an intentionally small INI-like repository config, create `<workspaces-root>/<feature-name>/`, and process every repository section.
- In the default mode, each section creates a worktree with `git -C <repo-path> worktree add -b <feature-name> <workspace-dir>/<repo-name> <branch>`. With `--no-worktrees` / `-NoWorktrees`, each repository is symlinked into the workspace instead.
- `install-create-feature-workspace.sh` is Unix-only setup: it marks the Bash entry point executable and installs or updates a `create-feature-workspace` symlink in the selected bin directory.
- Bats tests are integration tests. They provide a fake `git` through `PATH` and verify filesystem effects and command behavior rather than making real worktrees. The PowerShell tests use the analogous shim approach.

## Repository conventions

- Keep feature-creation behavior aligned between the Bash and PowerShell implementations, including path expansion, config validation, `--no-worktrees` behavior, and the `git worktree add` argument order.
- Config sections use `name`, `path`, and `branch`. Worktree mode requires all three; no-worktrees mode requires only `name` and `path`. A malformed active section must fail visibly rather than be skipped.
- Only expand leading home-directory forms: `~` and `~/...` (plus `~\...` in PowerShell). Resolve a relative workspace root from the caller's current directory.
- Preserve fail-fast, user-visible errors: Bash uses `set -euo pipefail` and stderr; PowerShell uses `$ErrorActionPreference = "Stop"` and throws.
- The installer must not overwrite a non-symlink target, should leave an already-correct symlink unchanged, and may replace an outdated symlink.
- When changing CLI output or the `git worktree add` call shape, update the Bats assertions and fake-`git` expectations in `tests/create-feature-workspace.bats`.
