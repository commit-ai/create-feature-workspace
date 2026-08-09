---
name: remove-from-feature-workspace
description: >
  Remove a repository or folder entry from an existing `create-feature-workspace`
  workspace using the `remove` command. Use this skill whenever the user wants to
  remove, delete, unlink, or stop tracking a repo, service, or folder from a workspace
  — even if they phrase it as "take out", "drop this repo", "I no longer need X in my
  workspace", "clean up an entry", or any other phrasing that means removing something
  from an existing workspace. This skill fully supports Unix (macOS/Linux) and Windows.
---

# remove-from-feature-workspace

## What This Skill Does

This skill covers one specific operation: **removing an entry from an already-created
workspace** using `create-feature-workspace remove`.

- For creating a brand-new workspace from scratch, use the `use-create-feature-workspace` skill.
- For adding a new entry to a workspace, use the `add-to-feature-workspace` skill.
- For installing the script, use the `install-create-feature-workspace` skill.

---

## Prerequisites

1. The `create-feature-workspace` script must be installed and on PATH.
   - Unix: `which create-feature-workspace`
   - Windows: `Get-Command create-feature-workspace`
   If not found, stop and tell the user to install it first.

2. The workspace must already exist. `remove` must be run **from inside** the workspace
   directory (the one containing `.create-feature-workspace.desired.ini`).

---

## Gather What You Need

Before running `remove`, confirm:

| Question | Why it matters |
|----------|---------------|
| What is the entry's **name**? | Must match exactly the name recorded in the manifest |
| Does the worktree have **uncommitted changes**? | `git worktree remove` will fail if it does — the user needs to commit or stash first |

To look up valid entry names, read the manifest from inside the workspace:

```bash
# Unix
cat .create-feature-workspace.desired.ini
```

```powershell
# Windows
Get-Content .create-feature-workspace.desired.ini
```

---

## Platform Syntax

Flag names differ between Unix and Windows. Read the relevant file before generating
any command:

- **Unix (macOS/Linux):** `references/unix-remove.md`
- **Windows (PowerShell / cmd.exe):** `references/windows-remove.md`

The behavior is identical on both platforms — only flag names differ.

---

## What Happens on Success

When `remove` completes successfully:

- The entry's subdirectory inside the workspace is removed:
  - **Worktree entries**: `git worktree remove` is called; the branch itself is **not** deleted,
    only the worktree checkout.
  - **Symlink entries** (symlink-mode repos or `type = folder`): the symlink is deleted.
- `.create-feature-workspace.desired.ini` is updated to drop the entry.
- `.create-feature-workspace.provisioned.ini` is updated to reflect the new state.
- The underlying repository and its branches are **unaffected** — only the workspace
  checkout is removed.

---

## What Happens on Failure

The operation is atomic with respect to the manifest:

- If `git worktree remove` fails (e.g., uncommitted changes), **neither** the manifest
  nor the state file is changed. The workspace stays as-is. Fix the underlying problem
  and retry.
- If the entry name is not found in the manifest, the command errors immediately without
  touching anything.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Not inside a managed workspace" | CWD is not the workspace directory | `cd` into the workspace directory, then retry |
| "Workspace entry not found" | Name doesn't match an entry in the manifest | Check the manifest for the exact name (case-sensitive on Unix) |
| `git worktree remove` fails with "dirty" error | The worktree has uncommitted changes | Commit or stash changes in that worktree, then retry `remove` |
| Symlink deletion fails on Windows | Insufficient permissions for symlink operations | Run the terminal as Administrator, or enable Developer Mode |
| Entry removed from manifest but directory still exists | A previous partial run left stale state | Run `create-feature-workspace sync` to reconcile |
