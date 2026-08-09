# remove-from-feature-workspace — Unix Syntax Reference

## Command

Run from **inside** the workspace directory:

```bash
cd /path/to/your/workspace
create-feature-workspace remove \
  --folder-name NAME
```

## Parameters

| Flag | Required | Description |
|------|----------|-------------|
| `--folder-name NAME` | Yes | Exact name of the entry to remove (as it appears in the manifest) |

`remove` accepts only `--folder-name`. Passing any other flag (`--folder-path`,
`--branch`, `--feature-name`, `--workspaces-root`, `--config-file`, `--no-worktrees`)
will produce an error.

## Examples

**Remove a repository entry:**
```bash
cd ~/workspaces/my-feature
create-feature-workspace remove --folder-name payments
```

**Remove a plain-folder entry:**
```bash
cd ~/workspaces/my-feature
create-feature-workspace remove --folder-name shared-docs
```

## Finding Valid Entry Names

List the entries in the manifest before running `remove`:

```bash
cat .create-feature-workspace.desired.ini
```

Look for lines that begin with `name =` — those values are the valid names.
Names are **case-sensitive** on Unix.

## What Gets Removed

| Entry type | What `remove` does |
|------------|-------------------|
| `repository` in **worktree** mode | Calls `git worktree remove <workspace-dir>/<name>` — removes the checkout, not the branch |
| `repository` in **symlink** mode | Deletes the symlink at `<workspace-dir>/<name>` |
| `folder` (any mode) | Deletes the symlink at `<workspace-dir>/<name>` |

The underlying repository and all its branches are **not affected**.

## Failure Behavior

- If the worktree has uncommitted changes, `git worktree remove` will refuse and the
  manifest is left unchanged. Commit or stash the changes, then retry.
- If `--folder-name` does not match any entry in the manifest, the command exits with
  an error immediately.
