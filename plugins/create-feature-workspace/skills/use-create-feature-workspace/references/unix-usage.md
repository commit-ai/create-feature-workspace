# create-feature-workspace — Unix Usage Reference

## Invocation

After installation, the script is on PATH as `create-feature-workspace`.

The first positional argument selects the action (`create` is the default when omitted):

```
create-feature-workspace [ACTION] [FLAGS]
```

---

## create (default action)

Creates a new workspace directory, writes the manifest, and provisions all entries.

```bash
create-feature-workspace \
  --feature-name NAME \
  --config-file PATH \
  [--workspaces-root PATH] \
  [--no-worktrees]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--feature-name NAME` | Yes | — | Name of the workspace; becomes the directory name |
| `--config-file PATH` | Yes | — | Path to the INI source config file |
| `--workspaces-root PATH` | No | `~/workspaces` | Parent directory for the workspace |
| `--no-worktrees` | No | off | Use symlinks for all entries instead of git worktrees |
| `-h` / `--help` | No | — | Print usage and exit |

Example:

```bash
create-feature-workspace \
  --feature-name my-feature \
  --config-file ~/projects/repos.ini \
  --workspaces-root ~/workspaces
```

Creates `~/workspaces/my-feature/` with one worktree per repository entry.

---

## sync

Reconcile the workspace with its manifest. Run from **inside** the workspace directory.

```bash
cd ~/workspaces/my-feature
create-feature-workspace sync
```

No additional flags. Reads `.create-feature-workspace.desired.ini` and brings the
filesystem in line with it.

---

## add

Add a new entry to an existing workspace. Run from **inside** the workspace directory.

```bash
cd ~/workspaces/my-feature
create-feature-workspace add \
  --folder-name NAME \
  --folder-path PATH \
  [--branch BRANCH] \
  [--type repository|folder]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--folder-name NAME` | Yes | — | Name of the new entry (subdirectory in the workspace) |
| `--folder-path PATH` | Yes | — | Absolute or `~`-prefixed path to the repo or folder |
| `--branch BRANCH` | No | auto-detected | Branch to use (repository entries in worktree mode only) |
| `--type repository\|folder` | No | `repository` | Entry type |

If `--branch` is omitted for a repository entry in worktree mode, the current HEAD
branch of that repository is detected automatically via `git symbolic-ref`.

Example:

```bash
create-feature-workspace add \
  --folder-name payments \
  --folder-path ~/src/payments-service \
  --branch main
```

---

## remove

Remove an entry from an existing workspace. Run from **inside** the workspace directory.

```bash
cd ~/workspaces/my-feature
create-feature-workspace remove --folder-name NAME
```

| Flag | Required | Description |
|------|----------|-------------|
| `--folder-name NAME` | Yes | Name of the entry to remove |

If the entry is a git worktree with uncommitted changes, `git worktree remove` will fail
and the manifest is left unchanged. Commit or stash before removing.

---

## Path Expansion

- Leading `~` and `~/…` are expanded to `$HOME`.
- A relative `--workspaces-root` is resolved from `$PWD` at invocation time.
- `--folder-path` values support the same `~` expansion.

---

## Guards

These flags are only accepted by `create` and will error on `add`, `remove`, or `sync`:
`--feature-name`, `--workspaces-root`, `--config-file`, `--no-worktrees`.
