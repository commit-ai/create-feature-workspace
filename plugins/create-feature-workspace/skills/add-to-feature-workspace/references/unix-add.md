# add-to-feature-workspace — Unix Syntax Reference

## Command

Run from **inside** the workspace directory:

```bash
cd /path/to/your/workspace
create-feature-workspace add \
  --folder-name NAME \
  --folder-path PATH \
  [--branch BRANCH] \
  [--type repository|folder]
```

## Parameters

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--folder-name NAME` | Yes | — | Entry name; becomes the subdirectory in the workspace |
| `--folder-path PATH` | Yes | — | Path to the repo or folder; supports leading `~` |
| `--branch BRANCH` | No | auto-detected | Branch to use for repository entries in worktree mode |
| `--type repository\|folder` | No | `repository` | `repository` for a git repo; `folder` for a plain directory |

## Examples

**Add a git repository (branch explicit):**
```bash
cd ~/workspaces/my-feature
create-feature-workspace add \
  --folder-name payments \
  --folder-path ~/src/payments-service \
  --branch main
```

**Add a git repository (branch auto-detected from HEAD):**
```bash
cd ~/workspaces/my-feature
create-feature-workspace add \
  --folder-name payments \
  --folder-path ~/src/payments-service
```

**Add a plain folder (no git, no branch):**
```bash
cd ~/workspaces/my-feature
create-feature-workspace add \
  --folder-name shared-docs \
  --folder-path ~/Dropbox/project-docs \
  --type folder
```

## Path Expansion

- Leading `~` and `~/…` in `--folder-path` are expanded to `$HOME`.
- Relative paths in `--folder-path` are resolved from `$PWD` at invocation time.

## Notes

- `--folder-name`, `--folder-path`, `--branch`, and `--type` are the only flags
  accepted by `add`. Passing `--feature-name`, `--workspaces-root`, `--config-file`,
  or `--no-worktrees` will produce an error.
- The operation is atomic: the manifest is only updated if provisioning succeeds.
