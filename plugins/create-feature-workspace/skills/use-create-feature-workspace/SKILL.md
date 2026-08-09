---
name: use-create-feature-workspace
description: >
  Use the already-installed `create-feature-workspace` script to create and manage
  feature workspaces: directories that aggregate git worktrees or symlinks for all
  repositories needed for a feature branch. Use this skill whenever the user wants
  to create a new workspace, write or validate a config file, sync an existing
  workspace, add or remove entries, or troubleshoot a failing `create-feature-workspace`
  invocation. Also triggers for questions about multi-repo feature setups, worktree vs
  symlink mode, the INI config format, the `--no-worktrees` flag, or any workspace
  lifecycle operation. This skill fully supports Unix (macOS/Linux) and Windows.
---

# use-create-feature-workspace

## Prerequisites — Check Before Doing Anything

Before running any command, verify that `create-feature-workspace` is on PATH:

- Unix: `which create-feature-workspace`
- Windows (PowerShell): `Get-Command create-feature-workspace`

If the command is not found, **stop and tell the user to install it first** using the
`install-create-feature-workspace` skill. Do not proceed with workspace operations
until installation is confirmed.

---

## What This Skill Covers

This skill covers **using** the `create-feature-workspace` script once it is installed.
For installation help, use the `install-create-feature-workspace` skill.

A feature workspace is a directory that collects all the repositories you need for
one feature branch in a single place — one git worktree (or symlink) per repository.

Typical flow:
1. Write a config INI file listing your repositories and branches.
2. Run `create-feature-workspace --feature-name my-feature --config-file repos.ini`.
3. Open the resulting folder in your editor as a multi-root workspace.
4. Use `sync`, `add`, `remove` from inside the workspace directory to keep it current.

---

## Platform Syntax Reference

The flags differ between Unix and Windows. Read the relevant file before generating
any command:

- **Unix (macOS/Linux):** `references/unix-usage.md`
- **Windows (PowerShell):** `references/windows-usage.md`

The behavior (what each command does, the config format, workspace structure) is
identical on both platforms — only the flag names differ.

---

## Selecting the Right Mode

Before running `create`, confirm which mode fits the user's situation:

| Mode | Flag | When it fits |
|------|------|--------------|
| `worktree` (default) | *(omit flag)* | Isolated git history per feature; each workspace gets its own branch |
| `symlink` | `--no-worktrees` / `-NoWorktrees` | Shared checkouts; no new branches; faster but all workspaces share the same working tree |

The mode is baked into the workspace manifest and **cannot be changed after creation**.
If the user asks to switch modes, they must remove the workspace directory and recreate it.

---

## Writing the Config File

The config file is an INI-like text file the user creates once and passes to `create`.
It is **not** the manifest — the manifest is written by the tool itself.

```ini
# Comments start with # or ;
[frontend]
name = frontend
path = ~/src/my-frontend
branch = main

[backend]
name = backend
path = ~/src/my-backend
branch = feature/my-feature

[shared-docs]
name = docs
path = ~/Dropbox/project-docs
type = folder
```

Rules to validate before running:
- Every entry needs `name` and `path`.
- `branch` is required for `repository` entries when mode is `worktree`.
- `type` defaults to `repository`; set `type = folder` for non-git directories.
- `name` values must be unique; no entry name may be `.`, `..`, contain `/` or `\`.
- Section names (the `[label]` lines) are free-form labels — they don't need to match `name`.
- Unknown keys, duplicate keys within a section, and keys outside a section all cause errors.

---

## Workspace Lifecycle Commands

### create — make a new workspace

Creates the workspace directory, writes the manifest, and provisions all entries.
Fails if a manifest already exists at that location.

Read the platform reference for the exact invocation.

Common mistakes to warn the user about:
- Running `create` from inside an existing workspace (the `--workspaces-root` /
  `--feature-name` flags are not accepted by `sync`, `add`, or `remove`).
- Forgetting `--branch` (or `-Branch`) on repository entries in worktree mode.
- Using a relative `--workspaces-root` — it resolves from `$PWD` at invocation time.

### sync — reconcile state with the manifest

Run from inside the workspace directory. Reads `.create-feature-workspace.desired.ini`
and brings the filesystem in line with it: removes entries that were deleted from the
manifest, creates entries that were added.

Useful after manually editing the manifest or after a partial failure.

### add — append a new entry

Run from inside the workspace directory. Adds one new repository or folder to both
the manifest and the filesystem atomically: if provisioning fails (e.g., git error),
the manifest is not updated.

If `--branch` / `-Branch` is omitted for a repository entry in worktree mode, the tool
auto-detects the current HEAD branch of that repository.

### remove — remove an entry

Run from inside the workspace directory. Removes the entry from both the manifest and
the filesystem. If `git worktree remove` fails (e.g., the worktree has uncommitted
changes), the manifest is left unchanged and the error is surfaced.

---

## After Running `create`

The workspace looks like this:

```
~/workspaces/<feature-name>/
├── .create-feature-workspace.desired.ini    ← desired state; safe to edit, then sync
├── .create-feature-workspace.provisioned.ini ← managed record; do not edit
├── <entry-name-1>/   ← git worktree (or symlink in symlink mode)
├── <entry-name-2>/   ← git worktree (or symlink)
└── <folder-entry>  → /path/to/folder        ← always a symlink for type=folder
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "command not found" / `Get-Command` fails | Script not installed or not on PATH | Use the `install-create-feature-workspace` skill |
| "Workspace manifest already exists" | Running `create` in an existing workspace | Change `--feature-name` or delete the old workspace |
| "Not inside a managed workspace" | Running `sync`/`add`/`remove` outside the workspace dir | `cd` into the workspace directory first |
| `git worktree remove` fails | Uncommitted changes in the worktree | Commit or stash changes, then retry `remove` |
| "Refusing to replace unmanaged path" | A path at the destination wasn't created by this tool | Rename or delete the conflicting path manually |
| "State mode does not match" | Manifest and state file disagree on `worktree` vs `symlink` | Do not edit the state file; recreate the workspace if needed |
| Windows symlink error | Developer Mode or admin rights not enabled | Enable Developer Mode, or use `--no-worktrees` and avoid `type = folder` |
| `add` auto-detect branch fails | Repo is in detached HEAD state | Pass `--branch` / `-Branch` explicitly |
