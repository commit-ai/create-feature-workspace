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

## Plugin and Marketplace

`marketplace.json` registers a single plugin (`create-feature-workspace`) sourced from `plugins/create-feature-workspace/`. The plugin bundles four skills under `plugins/create-feature-workspace/skills/`:

- `install-create-feature-workspace` — teaches Claude how to install the script on Unix and Windows, including the `.cmd` wrapper, PATH setup, and idempotency. It bundles the installer scripts under its `scripts/` subdirectory.
- `use-create-feature-workspace` — usage reference: `create`, `sync`, `add`, `remove`, config format, and mode selection.
- `add-to-feature-workspace` — guides adding a new entry to an existing workspace.
- `remove-from-feature-workspace` — guides removing an entry from a workspace.

Each skill directory contains `SKILL.md` (the skill definition) and `references/` with platform-specific detail files (`unix-*.md`, `windows-*.md`).

The `.apm/skills/unix-to-powershell/` skill is a local APM dependency that documents the patterns for porting Bash scripts to PowerShell (symlink pitfalls, `.cmd` wrappers, the `--flag` stop-parsing trap, etc.). Invoke it when porting or debugging Windows-side behavior.

## Dependency management (APM)

Dependencies are declared in `apm.yml` and pinned in `apm.lock.yaml`. Run `apm install` to install/update them. Installed packages land in `apm_modules/` (gitignored) and are also deployed to `.claude/skills/`, `.agents/skills/`, and `.github/agents/` - the agent runtime picks them up from there.

Do **not** edit files under `.claude/skills/`, `.claude/agents/`, `.agents/skills/`, `.github/agents/`, or `.claude/settings.json` directly; they are managed by APM and will be overwritten on the next `apm install`. To modify a skill, edit its source in `.apm/skills/<skill-name>/` only. To modify a custom subagent, edit its source in `.apm/agents/<agent-name>/` only. After editing either, run `scripts/reset-apm.sh` to redeploy, and reload skills/plugins with the agent's respective commands (e.g. `/reload-skills` in Claude Code).
