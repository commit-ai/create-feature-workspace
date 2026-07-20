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

@test "Fails on malformed config (missing key)" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "fail-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing name/path/branch"* ]]
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
