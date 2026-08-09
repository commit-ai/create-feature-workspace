---
name: add-to-feature-workspace
description: >
  Add a new repository or folder entry to an existing `create-feature-workspace`
  workspace using the `add` command. Use this skill whenever the user wants to add a
  repo, service, or folder to a workspace that already exists — even if they phrase it
  as "include another repo", "add a project to my workspace", "I need to add a service",
  "link a folder", or anything that means extending an existing workspace with a new
  entry. This skill fully supports Unix (macOS/Linux) and Windows.
---

# add-to-feature-workspace

## What This Skill Does

This skill covers one specific operation: **adding a new entry to an already-created
workspace** using `create-feature-workspace add`.

- For creating a brand-new workspace from scratch, use the `use-create-feature-workspace` skill.
- For installing the script, use the `install-create-feature-workspace` skill.

---

## Prerequisites

1. The `create-feature-workspace` script must be installed and on PATH.
   - Unix: `which create-feature-workspace`
   - Windows: `Get-Command create-feature-workspace`
   If not found, stop and tell the user to install it first.

2. The workspace must already exist. `add` must be run **from inside** the workspace
   directory (the one containing `.create-feature-workspace.desired.ini`).

---

## Gather What You Need

Before running `add`, confirm:

| Question | Why it matters |
|----------|---------------|
| What is the entry's **name**? | Becomes the subdirectory name inside the workspace |
| What is the **path** to the repo or folder? | Must be accessible from the machine |
| Is it a git **repository** or a plain **folder**? | Determines `--type` / `-Type`; defaults to `repository` |
| If repository in **worktree mode**: what **branch**? | Required unless you want auto-detection |

**Entry name rules** (validate before running):
- Must be unique within the workspace (not already in the manifest).
- Must not be `.` or `..`.
- Must not contain `/` or `\`.

---

## Platform Syntax

Flag names differ between Unix and Windows. Read the relevant file before generating
any command:

- **Unix (macOS/Linux):** `references/unix-add.md`
- **Windows (PowerShell / cmd.exe):** `references/windows-add.md`

The behavior is identical on both platforms — only flag names differ.

---

## Branch Handling

When adding a `repository` entry to a **worktree-mode** workspace:

- If the user provides a branch name, pass it explicitly.
- If they don't, the tool auto-detects the repo's current HEAD branch via
  `git symbolic-ref`. This is safe as long as the repo is not in detached HEAD state.
- In **symlink mode** workspaces, `--branch` / `-Branch` is ignored for repository
  entries (they share the working tree, no new branch is created).
- For `type = folder` entries, branch is never applicable.

---

## After Running `add`

If the command succeeds:
- The new entry appears as a subdirectory (worktree or symlink) inside the workspace.
- `.create-feature-workspace.desired.ini` is updated with the new entry.
- `.create-feature-workspace.provisioned.ini` is updated to reflect the provisioned state.

If provisioning fails (e.g., a git error during worktree creation), the manifest is
**not** updated — the operation is atomic. The user can fix the underlying issue and
retry.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Not inside a managed workspace" | CWD is not the workspace directory | `cd` into the workspace dir, then retry |
| "Entry name already exists" | Duplicate name in manifest | Choose a different `--folder-name` / `-FolderName` |
| `git worktree add` fails | Branch already checked out elsewhere, or branch doesn't exist | Create the branch first, or check it out somewhere else and use a different name |
| `add` auto-detect branch fails | Repo is in detached HEAD state | Pass `--branch` / `-Branch` explicitly |
| Windows symlink error | `type = folder` requires Developer Mode or admin rights | Enable Developer Mode, or use a repository entry with worktree mode instead |
| `-FeatureName` / `--feature-name` not recognized | These flags only work with `create`, not `add` | Make sure you're running `add` from inside the workspace directory |
