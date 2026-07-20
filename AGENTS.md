# Copilot / Claude Code instructions

## Commands

- `npm ci` installs the repo's test dependency (`bats`).
- `npm test` runs the full test suite.
- `npx bats tests/create-feature-workspace.bats` runs the Unix workspace-creation tests only.
- `npx bats tests/install-create-feature-workspace.bats` runs the installer tests only.
- There is no separate build or lint command in this repository today.

## Architecture

- `create-feature-workspace.sh` is the primary Unix implementation. It parses an INI-style config file section by section, expands leading `~` paths, creates `<workspaces-root>/<feature-name>/`, and runs `git -C <repo-path> worktree add -b <feature-name> <workspace-dir>/<repo-name> <branch>` once per repo section.
- `create-feature-workspace.ps1` is the Windows/PowerShell implementation of the same workflow. Changes to the feature-creation flow should usually be mirrored in both scripts.
- `install-create-feature-workspace.sh` is a separate installer entrypoint. It makes `create-feature-workspace.sh` executable and creates a `create-feature-workspace` symlink in the target bin directory.
- The test suite is integration-oriented Bats coverage. The main script tests inject a fake `git` executable through `PATH` and assert filesystem side effects and CLI behavior instead of creating real worktrees.

## Conventions

- The config file format is intentionally small and fixed: each repo section must provide `name`, `path`, and `branch`. Missing any of those keys should fail the current section instead of being skipped.
- Keep Bash and PowerShell behavior aligned, especially around path expansion, section validation, and `git worktree add` argument order.
- Path expansion only handles leading `~` forms (`~` and `~/...`) in both implementations. Preserve that scoped behavior unless you update both scripts and their tests together.
- Error handling is fail-fast and user-visible: Bash uses `set -euo pipefail` and stderr messages, while PowerShell uses `$ErrorActionPreference = "Stop"` and throws on invalid input.
- Installer behavior is conservative: refuse to replace an existing regular file, accept an already-correct symlink, and replace an outdated symlink.
- If you change CLI output or the shape of the `git worktree add` call, update the Bats assertions and the mocked-`git` expectations in `tests/create-feature-workspace.bats`.
