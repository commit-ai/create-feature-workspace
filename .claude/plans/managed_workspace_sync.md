# Managed workspace synchronization plan

## Problem and approach

Feature workspaces are currently generated once from an external INI file. Add an internal, normalized manifest to each workspace, plus `add`, `remove`, and `sync` commands. The manifest will be the desired structure; `sync` will fully reconcile managed workspace entries against it. A generated state file will record the last successful managed entries so a deletion from the manifest can be safely identified without treating arbitrary workspace files as managed.

**Both scripts already implement this.** The work is:
1. Close all existing coverage gaps first.
2. Fix the Bash/PowerShell parity gap (entry-name validation).
3. Then follow TDD (red test first) for any remaining implementation work.

---

## Phase 0 — Close existing coverage gaps (no new implementation)

All tests in this phase are written against already-implemented behavior. Every test must pass before Phase 1 begins.

### 0a. Extend the fake-git shim

The existing shim only handles `worktree add`. Extend it to handle `worktree remove` (delete the directory at the destination argument), so removal tests can run correctly.

### 0b. Bats coverage for manifest and state creation

- Creation writes `.create-feature-workspace.desired.ini` with a `[workspace]` section containing `mode = worktree` (or `mode = symlink` with `--no-worktrees`).
- Creation writes `.create-feature-workspace.provisioned.ini` listing exactly the entries provisioned.
- Creation fails with a visible error when the manifest already exists ("Workspace manifest already exists").

### 0c. Bats coverage for manifest validation

- Rejects a manifest with a duplicate entry name.
- Rejects a manifest missing `name` or `path`.
- Rejects a manifest with a repository entry missing `branch` in worktree mode.
- Rejects an unknown key (`unknown key`).
- Rejects a duplicate key within a section.
- Rejects a manifest that does not begin with a `[workspace]` section.
- Rejects an invalid `mode` value in `[workspace]`.
- Rejects a malformed section header.

### 0d. Bats coverage for `sync`

- `sync` creates a missing entry declared in the manifest (worktree variant).
- `sync` creates a missing entry declared in the manifest (folder/symlink variant).
- `sync` removes a managed entry absent from the manifest (uses `worktree remove` for worktrees, `rm` for symlinks).
- `sync` replaces a managed entry whose `path`, `type`, or `branch` has changed.
- `sync` is a no-op when the workspace already matches the manifest.
- `sync` updates the state file only after each successful operation (verify state after each step).
- `sync` refuses to touch an unmanaged path at a conflicting destination and emits a visible error.
- `sync` does not force-delete a dirty worktree; fake-git returns non-zero from `worktree remove`, and the state file is not updated for that entry.
- `sync` rejects `--no-worktrees` (flag only valid on create).

### 0e. Bats coverage for `add`

- `add` appends the entry to the manifest and provisions it in the workspace.
- `add` rejects a duplicate name before modifying the manifest.
- `add` of a `folder` entry creates a symlink even when workspace mode is `worktree`.
- `add` of a repository entry in worktree mode rejects a missing `branch`.

### 0f. Bats coverage for `remove`

- `remove` deletes the entry from the manifest and removes it from the workspace.
- `remove` of an unrecognized name is rejected with a visible error.
- `remove` does not force-delete a dirty worktree (fake-git returns non-zero, visible error, no manifest change).

### 0g. Bats coverage for manual manifest edit + `sync`

- Manually adding an entry to the manifest and running `sync` provisions it.
- Manually removing an entry from the manifest and running `sync` removes the managed artifact.
- A manually introduced invalid section causes `sync` to reject with a visible error before changing anything.

### 0h. Pester coverage (mirror of 0b–0g)

Write equivalent Pester tests for all cases above, using the existing shim/stub approach in `create-feature-workspace.tests.ps1`. All must pass before Phase 1 begins.

---

## Phase 1 — Fix Bash/PowerShell parity gap (TDD)

PowerShell has `Assert-EntryName`, which rejects entry names containing path separators, reserved filenames (`.create-feature-workspace.desired.ini`, `.create-feature-workspace.provisioned.ini`), and filesystem-invalid characters. Bash has no equivalent.

**1a. Write red Bats tests first**
- Reject an entry name containing `/`.
- Reject an entry name containing `\`.
- Reject an entry name of `.` or `..`.
- Reject an entry name equal to `.create-feature-workspace.desired.ini` or `.create-feature-workspace.provisioned.ini`.
- Run the tests and confirm they fail before implementing anything.

**1b. Implement `assert_entry_name` in `create-feature-workspace.sh`**
- Add validation matching PowerShell's `Assert-EntryName` behavior.
- Run the tests; all must pass before proceeding.

---

## Phase 2 — Any remaining implementation gaps (TDD)

After Phases 0 and 1, identify any behaviors present in one script but absent in the other, or any validation described in the plan but not yet in the code. For each gap:

1. Write a failing test.
2. Implement the minimum code to make it pass.
3. Run the full suite; zero regressions allowed.

---

## Decisions and considerations

- The workspace-local normalized INI file is the only desired-state source. The original input config initializes it but is not consulted by later mutations.
- Each workspace has one persisted repository mode; folders are always symlinks, even when repositories are worktrees.
- `sync` performs full reconciliation but only deletes entries listed in its generated ownership state. Existing unmanaged paths cause a visible conflict instead of deletion or replacement.
- Worktree removal is intentionally non-forced. Dirty worktrees or Git failures must surface to the user, and state updates occur only after a successful operation.
- The exact filenames and command spelling will follow the repository's existing CLI style and be documented consistently across Bash and PowerShell.
- Coverage gap closure (Phase 0) must be complete and all tests green before any red-test TDD work begins.
