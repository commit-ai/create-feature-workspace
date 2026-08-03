bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="create-feature-workspace.sh"
    BATS_TMP_DIR="$(mktemp -d)"
    TEMP_WS_ROOT="$BATS_TMP_DIR/workspaces"
    CONFIG_FILE="$BATS_TMP_DIR/test-config.ini"
    SHIM_DIR="$BATS_TMP_DIR/bin"
    mkdir -p "$SHIM_DIR"
    cat << 'SHIM' > "$SHIM_DIR/git"
#!/bin/bash
echo "MOCK GIT CALLED: $*" >&2
if [[ "$*" == *"worktree add"* ]]; then
    args=("$@")
    count=$#
    dest="${args[$((count - 2))]}"
    mkdir -p "$dest"
fi
exit 0
SHIM
    chmod +x "$SHIM_DIR/git"
    OLD_PATH="$PATH"
    export PATH="$SHIM_DIR:$PATH"
}

teardown() {
    export PATH="$OLD_PATH"
    rm -rf "$BATS_TMP_DIR"
}

@test "Successfully calls git worktree add for a valid config" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "new-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    echo "$output" >&2
    [ "$status" -eq 0 ]
    [ -d "$TEMP_WS_ROOT/new-feat/repo-alpha" ]
}

@test "Expands tilde (~) in paths" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = ~/fake-repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "test-tilde" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    echo "$output" >&2
    [ "$status" -eq 0 ]
}

@test "Fails on malformed config (missing branch in worktree mode)" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "fail-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Missing name/path/branch"* ]]
}

@test "Handles relative --workspaces-root correctly" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    local rel_root="relative-workspaces"
    local run_dir="$BATS_TMP_DIR/run-cwd"
    mkdir -p "$run_dir"

    # Stricter mock that honours the -C flag: resolves relative destination
    # paths relative to the repo dir, exactly as real git does.
    local strict_bin="$BATS_TMP_DIR/strict-bin"
    mkdir -p "$strict_bin"
    cat << 'SHIM' > "$strict_bin/git"
#!/bin/bash
args=("$@")
repo_dir=""
i=0
while [[ $i -lt ${#args[@]} ]]; do
    if [[ "${args[$i]}" == "-C" ]]; then
        repo_dir="${args[$((i+1))]}"
        i=$((i+2))
    else
        break
    fi
done
if [[ "$*" == *"worktree add"* ]]; then
    dest="${args[$((${#args[@]} - 2))]}"
    if [[ "$dest" != /* ]] && [[ -n "$repo_dir" ]]; then
        dest="$repo_dir/$dest"
    fi
    mkdir -p "$dest"
fi
exit 0
SHIM
    chmod +x "$strict_bin/git"

    run bash -c "cd '$run_dir' && PATH='$strict_bin:$PATH' bash '$BATS_TEST_DIRNAME/../$SCRIPT' \
        --feature-name 'rel-feat' \
        --config-file '$CONFIG_FILE' \
        --workspaces-root '$rel_root'"

    [ "$status" -eq 0 ]
    [ -d "$run_dir/$rel_root/rel-feat/repo-alpha" ]
}

@test "--no-worktrees creates a symlink to the repo path without calling git" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = some-branch
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" \
        --feature-name "no-wt-feat" \
        --config-file "$CONFIG_FILE" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --no-worktrees
    [ "$status" -eq 0 ]
    [ -L "$TEMP_WS_ROOT/no-wt-feat/repo-alpha" ]
    [ "$(readlink "$TEMP_WS_ROOT/no-wt-feat/repo-alpha")" = "/fake/repo" ]
    [[ "$output" != *"MOCK GIT CALLED"* ]]
}

@test "--no-worktrees succeeds when branch is absent from config" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" \
        --feature-name "no-branch-feat" \
        --config-file "$CONFIG_FILE" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --no-worktrees
    [ "$status" -eq 0 ]
    [ -L "$TEMP_WS_ROOT/no-branch-feat/repo-alpha" ]
}

# ---------------------------------------------------------------------------
# Phase 0a: fake-git shim extended with worktree remove support
# The shim used in the tests below also handles `worktree remove` by deleting
# the destination directory so removal tests can run correctly.
# ---------------------------------------------------------------------------

# Helper: write a shim that supports both add and remove to SHIM_DIR/git
_write_full_shim() {
    cat << 'SHIM' > "$SHIM_DIR/git"
#!/bin/bash
echo "MOCK GIT CALLED: $*" >&2
if [[ "$*" == *"worktree add"* ]]; then
    args=("$@")
    count=$#
    dest="${args[$((count - 2))]}"
    mkdir -p "$dest"
elif [[ "$*" == *"worktree remove"* ]]; then
    args=("$@")
    count=$#
    dest="${args[$((count - 1))]}"
    rm -rf "$dest"
fi
exit 0
SHIM
    chmod +x "$SHIM_DIR/git"
}

# Helper: write a dirty-worktree shim (worktree remove fails)
_write_dirty_shim() {
    cat << 'SHIM' > "$SHIM_DIR/git"
#!/bin/bash
echo "MOCK GIT CALLED: $*" >&2
if [[ "$*" == *"worktree add"* ]]; then
    args=("$@")
    count=$#
    dest="${args[$((count - 2))]}"
    mkdir -p "$dest"
elif [[ "$*" == *"worktree remove"* ]]; then
    echo "fatal: working tree has modifications" >&2
    exit 1
fi
exit 0
SHIM
    chmod +x "$SHIM_DIR/git"
}

# ---------------------------------------------------------------------------
# Phase 0b: manifest and state file creation
# ---------------------------------------------------------------------------

@test "create writes manifest with [workspace] and mode=worktree" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "mani-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    local manifest="$TEMP_WS_ROOT/mani-feat/.create-feature-workspace.ini"
    [ -f "$manifest" ]
    grep -q '^\[workspace\]' "$manifest"
    grep -q 'mode = worktree' "$manifest"
}

@test "create --no-worktrees writes manifest with mode=symlink" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "sym-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT" --no-worktrees
    [ "$status" -eq 0 ]
    local manifest="$TEMP_WS_ROOT/sym-feat/.create-feature-workspace.ini"
    grep -q 'mode = symlink' "$manifest"
}

@test "create writes state file listing provisioned entries" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "state-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    local state="$TEMP_WS_ROOT/state-feat/.create-feature-workspace.state.ini"
    [ -f "$state" ]
    grep -q 'name = repo-alpha' "$state"
}

@test "create fails when manifest already exists" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "dup-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "dup-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Workspace manifest already exists"* ]]
}

# ---------------------------------------------------------------------------
# Phase 0c: manifest validation
# ---------------------------------------------------------------------------

@test "manifest rejects duplicate entry name" {
    local ws="$TEMP_WS_ROOT/val-dup"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository

[entry-1]
name = repo-alpha
path = /fake/repo2
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-dup" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Duplicate workspace entry name"* ]]
}

@test "manifest rejects entry missing name" {
    local ws="$TEMP_WS_ROOT/val-noname"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-noname" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Missing name/path"* ]]
}

@test "manifest rejects repository entry missing branch in worktree mode" {
    local ws="$TEMP_WS_ROOT/val-nobranch"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-nobranch" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Missing name/path/branch"* ]]
}

@test "manifest rejects unknown key" {
    local ws="$TEMP_WS_ROOT/val-unknownkey"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
unknown = something
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-unknownkey" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown key"* ]]
}

@test "manifest rejects duplicate key within a section" {
    local ws="$TEMP_WS_ROOT/val-dupkey"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-dupkey" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"duplicate key"* ]]
}

@test "manifest rejects file that does not begin with [workspace]" {
    local ws="$TEMP_WS_ROOT/val-noworkspace"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-noworkspace" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
}

@test "manifest rejects invalid mode value" {
    local ws="$TEMP_WS_ROOT/val-badmode"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = invalid

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-badmode" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"mode"* ]]
}

@test "manifest rejects malformed section header" {
    local ws="$TEMP_WS_ROOT/val-badheader"
    mkdir -p "$ws"
    printf '[workspace]\nmode = worktree\n\n[entry-0\nname = repo-alpha\npath = /fake/repo\nbranch = main\ntype = repository\n' \
        > "$ws/.create-feature-workspace.ini"
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "val-badheader" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Phase 0d: sync command
# ---------------------------------------------------------------------------

@test "sync creates a missing worktree entry declared in the manifest" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-add-wt"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-add-wt" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ -d "$ws/repo-alpha" ]
}

@test "sync creates a missing symlink entry declared in the manifest" {
    local ws="$TEMP_WS_ROOT/sync-add-sym"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = symlink

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-add-sym" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ -L "$ws/repo-alpha" ]
}

@test "sync removes a managed worktree entry absent from the manifest" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-rm-wt"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-rm-wt" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ ! -e "$ws/repo-alpha" ]
}

@test "sync removes a managed symlink entry absent from the manifest" {
    local ws="$TEMP_WS_ROOT/sync-rm-sym"
    mkdir -p "$ws"
    ln -s /fake/repo "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = symlink
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = symlink

[entry-0]
name = repo-alpha
path = /fake/repo
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-rm-sym" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ ! -e "$ws/repo-alpha" ]
}

@test "sync replaces a managed entry whose branch has changed" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-replace"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = new-branch
type = repository
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = old-branch
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-replace" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ -d "$ws/repo-alpha" ]
}

@test "sync is a no-op when workspace already matches the manifest" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-noop"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-noop" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"MOCK GIT CALLED"* ]]
}

@test "sync updates state file after each successful operation" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-stateupdate"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-stateupdate" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    local state="$ws/.create-feature-workspace.state.ini"
    [ -f "$state" ]
    grep -q 'name = repo-alpha' "$state"
}

@test "sync refuses to touch an unmanaged path at a conflicting destination" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/sync-conflict"
    mkdir -p "$ws/repo-alpha"  # unmanaged — not in state
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    # no state file — so repo-alpha is not managed
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-conflict" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Refusing to replace unmanaged path"* ]]
}

@test "sync does not force-delete a dirty worktree and does not update state" {
    _write_dirty_shim
    local ws="$TEMP_WS_ROOT/sync-dirty"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-dirty" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    # state must still list repo-alpha (not updated after failed remove)
    grep -q 'name = repo-alpha' "$ws/.create-feature-workspace.state.ini"
}

@test "sync rejects --no-worktrees flag" {
    local ws="$TEMP_WS_ROOT/sync-nowt"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "sync-nowt" --workspaces-root "$TEMP_WS_ROOT" --no-worktrees
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"only supported when creating"* ]]
}

# ---------------------------------------------------------------------------
# Phase 0e: add command
# ---------------------------------------------------------------------------

@test "add appends entry to manifest and provisions it" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/add-basic"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "add-basic" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name repo-alpha \
        --path /fake/repo \
        --branch main
    [ "$status" -eq 0 ]
    [ -d "$ws/repo-alpha" ]
    grep -q 'name = repo-alpha' "$ws/.create-feature-workspace.ini"
}

@test "add rejects a duplicate entry name before modifying the manifest" {
    local ws="$TEMP_WS_ROOT/add-dup"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "add-dup" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name repo-alpha \
        --path /fake/repo2 \
        --branch develop
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"already exists"* ]]
}

@test "add of a folder entry creates a symlink even in worktree-mode workspace" {
    local ws="$TEMP_WS_ROOT/add-folder"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "add-folder" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name shared-libs \
        --path /fake/libs \
        --type folder
    [ "$status" -eq 0 ]
    [ -L "$ws/shared-libs" ]
}

@test "add of repository entry in worktree mode rejects missing branch" {
    local ws="$TEMP_WS_ROOT/add-nobranch"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "add-nobranch" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name repo-alpha \
        --path /fake/repo
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"Missing name/path/branch"* ]]
}

# ---------------------------------------------------------------------------
# Phase 0f: remove command
# ---------------------------------------------------------------------------

@test "remove deletes entry from manifest and removes it from workspace" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/remove-basic"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" remove \
        --feature-name "remove-basic" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name repo-alpha
    [ "$status" -eq 0 ]
    [ ! -e "$ws/repo-alpha" ]
    ! grep -q 'name = repo-alpha' "$ws/.create-feature-workspace.ini"
}

@test "remove of an unrecognized name is rejected with a visible error" {
    local ws="$TEMP_WS_ROOT/remove-notfound"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" remove \
        --feature-name "remove-notfound" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name nonexistent
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"not found"* ]]
}

@test "remove does not force-delete a dirty worktree and leaves manifest unchanged" {
    _write_dirty_shim
    local ws="$TEMP_WS_ROOT/remove-dirty"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" remove \
        --feature-name "remove-dirty" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name repo-alpha
    [ "$status" -ne 0 ]
    grep -q 'name = repo-alpha' "$ws/.create-feature-workspace.ini"
}

# ---------------------------------------------------------------------------
# Phase 0g: manual manifest edit + sync
# ---------------------------------------------------------------------------

@test "manually adding an entry to the manifest and running sync provisions it" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/manual-add"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree
EOF
    # manually add an entry
    cat << 'EOF' >> "$ws/.create-feature-workspace.ini"

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "manual-add" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ -d "$ws/repo-alpha" ]
}

@test "manually removing an entry from the manifest and running sync removes the artifact" {
    _write_full_shim
    local ws="$TEMP_WS_ROOT/manual-rm"
    mkdir -p "$ws/repo-alpha"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "manual-rm" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -eq 0 ]
    [ ! -e "$ws/repo-alpha" ]
}

@test "manually introduced invalid section causes sync to reject before changing anything" {
    local ws="$TEMP_WS_ROOT/manual-invalid"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree

[entry-0]
name = repo-alpha
path = /fake/repo
branch = main
type = repository
unknown = bad
EOF
    cat << 'EOF' > "$ws/.create-feature-workspace.state.ini"
[state]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" sync --feature-name "manual-invalid" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [ ! -e "$ws/repo-alpha" ]
}

# ---------------------------------------------------------------------------
# Phase 1a: assert_entry_name validation (red tests — implement in Phase 1b)
# ---------------------------------------------------------------------------

@test "entry name containing / is rejected" {
    local ws="$TEMP_WS_ROOT/name-slash"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-slash" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name "bad/name" \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* ]]
}

@test "entry name containing backslash is rejected" {
    local ws="$TEMP_WS_ROOT/name-backslash"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-backslash" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name 'bad\name' \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* ]]
}

@test "entry name of . is rejected" {
    local ws="$TEMP_WS_ROOT/name-dot"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-dot" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name "." \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* ]]
}

@test "entry name of .. is rejected" {
    local ws="$TEMP_WS_ROOT/name-dotdot"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-dotdot" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name ".." \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* ]]
}

@test "entry name equal to .create-feature-workspace.ini is rejected" {
    local ws="$TEMP_WS_ROOT/name-reserved1"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-reserved1" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name ".create-feature-workspace.ini" \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* || "$stderr" == *"reserved"* ]]
}

@test "entry name equal to .create-feature-workspace.state.ini is rejected" {
    local ws="$TEMP_WS_ROOT/name-reserved2"
    mkdir -p "$ws"
    cat << 'EOF' > "$ws/.create-feature-workspace.ini"
[workspace]
mode = worktree
EOF
    run --separate-stderr bash "$BATS_TEST_DIRNAME/../$SCRIPT" add \
        --feature-name "name-reserved2" \
        --workspaces-root "$TEMP_WS_ROOT" \
        --name ".create-feature-workspace.state.ini" \
        --path /fake/repo \
        --branch main
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"invalid"* || "$stderr" == *"entry name"* || "$stderr" == *"reserved"* ]]
}
