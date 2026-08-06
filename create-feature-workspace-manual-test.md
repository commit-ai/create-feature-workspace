# Manual Unix Test Scenario

This scenario exercises the Unix implementation with real local Git repositories. It creates temporary repositories, provisions a worktree workspace, adds and removes an entry, tests symlink mode, and verifies the installer.

Run it from the repository root on macOS or Linux:

```bash
cd /path/to/create-feature-workspace
```

## 1. Prepare an isolated test area

The commands below keep all test data under a temporary directory and remove it when the shell exits:

```bash
set -euo pipefail

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ONE="$TEST_ROOT/repo-one"
REPO_TWO="$TEST_ROOT/repo-two"
SHARED_FOLDER="$TEST_ROOT/shared-folder"
WORKSPACES="$TEST_ROOT/workspaces"
BIN_DIR="$TEST_ROOT/bin"
CONFIG="$TEST_ROOT/repos.ini"

mkdir -p "$REPO_ONE" "$REPO_TWO" "$SHARED_FOLDER" "$WORKSPACES" "$BIN_DIR"
```

## 2. Create source repositories and commits

`git worktree add` requires each source repository to have at least one commit:

```bash
git -C "$REPO_ONE" init -b main
printf 'repository one\n' > "$REPO_ONE/README.md"
git -C "$REPO_ONE" add README.md
git -C "$REPO_ONE" -c user.name='Manual Test' -c user.email='manual-test@example.com' commit -m 'Initial repository one'

git -C "$REPO_TWO" init -b main
printf 'repository two\n' > "$REPO_TWO/README.md"
git -C "$REPO_TWO" add README.md
git -C "$REPO_TWO" -c user.name='Manual Test' -c user.email='manual-test@example.com' commit -m 'Initial repository two'

printf 'shared files\n' > "$SHARED_FOLDER/README.txt"
```

## 3. Create a repository configuration

The first two entries are repositories and the third is a folder. The folder is always symlinked:

```bash
cat > "$CONFIG" <<EOF
[repo-one]
name = repo-one
path = $REPO_ONE
branch = main

[repo-two]
name = repo-two
path = $REPO_TWO
branch = main

[shared-folder]
name = shared-folder
path = $SHARED_FOLDER
type = folder
EOF
```

Inspect the generated configuration before continuing:

```bash
cat "$CONFIG"
```

## 4. Create a worktree workspace

Run the script directly:

```bash
bash ./create-feature-workspace.sh \
  --feature-name feature-demo \
  --config-file "$CONFIG" \
  --workspaces-root "$WORKSPACES"
```

The workspace should contain two real Git worktrees and one symlink:

```bash
WORKSPACE="$WORKSPACES/feature-demo"

test -f "$WORKSPACE/repo-one/.git"
test -f "$WORKSPACE/repo-two/.git"
test -L "$WORKSPACE/shared-folder"
test "$(readlink "$WORKSPACE/shared-folder")" = "$SHARED_FOLDER"
test -f "$WORKSPACE/.create-feature-workspace.desired.ini"
test -f "$WORKSPACE/.create-feature-workspace.provisioned.ini"

git -C "$WORKSPACE/repo-one" branch --show-current
git -C "$WORKSPACE/repo-two" branch --show-current
cat "$WORKSPACE/.create-feature-workspace.desired.ini"
cat "$WORKSPACE/.create-feature-workspace.provisioned.ini"
```

Expected branch output:

```text
feature-demo
feature-demo
```

The manifest should start with `mode = worktree`; the state file should list all three provisioned entries.

## 5. Verify create is not destructive

Running `create` again with the same feature name must fail because the manifest already exists:

```bash
if bash ./create-feature-workspace.sh \
  --feature-name feature-demo \
  --config-file "$CONFIG" \
  --workspaces-root "$WORKSPACES"; then
  echo "ERROR: duplicate create unexpectedly succeeded" >&2
  exit 1
fi
```

The error should mention `Workspace manifest already exists`.

## 6. Test `sync`

Add a new entry to the existing manifest manually, then reconcile it:

```bash
mkdir -p "$TEST_ROOT/extra-folder"
printf 'extra files\n' > "$TEST_ROOT/extra-folder/README.txt"

cat >> "$WORKSPACE/.create-feature-workspace.desired.ini" <<EOF

[entry-extra]
name = extra-folder
path = $TEST_ROOT/extra-folder
type = folder
EOF

bash ./create-feature-workspace.sh \
  sync \
  --feature-name feature-demo \
  --workspaces-root "$WORKSPACES"

test -L "$WORKSPACE/extra-folder"
test "$(readlink "$WORKSPACE/extra-folder")" = "$TEST_ROOT/extra-folder"
```

`sync` should create the missing managed entry and add it to the state file:

```bash
grep -q '^name = extra-folder$' "$WORKSPACE/.create-feature-workspace.provisioned.ini"
```

## 7. Test `add`

Add another folder through the CLI:

```bash
mkdir -p "$TEST_ROOT/docs"

bash ./create-feature-workspace.sh \
  add \
  --feature-name feature-demo \
  --folder-name docs \
  --folder-path "$TEST_ROOT/docs" \
  --type folder \
  --workspaces-root "$WORKSPACES"

test -L "$WORKSPACE/docs"
test "$(readlink "$WORKSPACE/docs")" = "$TEST_ROOT/docs"
grep -q '^name = docs$' "$WORKSPACE/.create-feature-workspace.desired.ini"
grep -q '^name = docs$' "$WORKSPACE/.create-feature-workspace.provisioned.ini"
```

## 8. Test `remove`

Remove the entry added in the previous step:

```bash
bash ./create-feature-workspace.sh \
  remove \
  --feature-name feature-demo \
  --folder-name docs \
  --workspaces-root "$WORKSPACES"

test ! -e "$WORKSPACE/docs"
test ! -L "$WORKSPACE/docs"
! grep -q '^name = docs$' "$WORKSPACE/.create-feature-workspace.desired.ini"
! grep -q '^name = docs$' "$WORKSPACE/.create-feature-workspace.provisioned.ini"
```

The source directory must remain untouched:

```bash
test -d "$TEST_ROOT/docs"
```

## 9. Remove a real worktree

Remove one repository entry. This should call `git worktree remove` and delete only the workspace copy:

```bash
bash ./create-feature-workspace.sh \
  remove \
  --feature-name feature-demo \
  --folder-name repo-two \
  --workspaces-root "$WORKSPACES"

test ! -d "$WORKSPACE/repo-two"
test -d "$REPO_TWO"
git -C "$REPO_TWO" worktree list
! grep -q '^name = repo-two$' "$WORKSPACE/.create-feature-workspace.provisioned.ini"
```

## 10. Test symlink mode with `--no-worktrees`

Create a separate workspace in symlink mode. In this mode repository entries do not need a `branch`:

```bash
SYMLINK_CONFIG="$TEST_ROOT/symlinks.ini"
cat > "$SYMLINK_CONFIG" <<EOF
[repo-one]
name = repo-one
path = $REPO_ONE

[shared-folder]
name = shared-folder
path = $SHARED_FOLDER
type = folder
EOF

bash ./create-feature-workspace.sh \
  --feature-name symlink-demo \
  --config-file "$SYMLINK_CONFIG" \
  --workspaces-root "$WORKSPACES" \
  --no-worktrees

SYMLINK_WORKSPACE="$WORKSPACES/symlink-demo"
test -L "$SYMLINK_WORKSPACE/repo-one"
test "$(readlink "$SYMLINK_WORKSPACE/repo-one")" = "$REPO_ONE"
test -L "$SYMLINK_WORKSPACE/shared-folder"
grep -q '^mode = symlink$' "$SYMLINK_WORKSPACE/.create-feature-workspace.desired.ini"
```

## 11. Test the installer

Install into the temporary bin directory, without changing the real home directory:

```bash
bash ./install-create-feature-workspace.sh --bin-dir "$BIN_DIR"

test -L "$BIN_DIR/create-feature-workspace"
test "$(readlink "$BIN_DIR/create-feature-workspace")" = "$PWD/create-feature-workspace.sh"
test -x ./create-feature-workspace.sh
```

Run the installed command by putting the temporary bin directory first on `PATH`:

```bash
PATH="$BIN_DIR:$PATH" create-feature-workspace --help
```

The output should include the `create`, `add`, `remove`, and `sync` usage forms.

Run the installer a second time. It should preserve the already-correct symlink:

```bash
bash ./install-create-feature-workspace.sh --bin-dir "$BIN_DIR"
test -L "$BIN_DIR/create-feature-workspace"
```

## 12. Clean up

The `trap` from step 1 removes all temporary repositories, workspaces, and installer files automatically when the shell exits:

```bash
exit
```
