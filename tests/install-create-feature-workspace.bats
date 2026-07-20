setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../install-create-feature-workspace.sh"
  BATS_TMP_DIR="$(mktemp -d)"
  TEMP_BIN_DIR="$BATS_TMP_DIR/bin"
  SOURCE_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/create-feature-workspace.sh"
}

teardown() {
  rm -rf "$BATS_TMP_DIR"
}

@test "Creates a symlink in the requested bin directory" {
  run bash "$SCRIPT" --bin-dir "$TEMP_BIN_DIR"
  [ "$status" -eq 0 ]
  [ -L "$TEMP_BIN_DIR/create-feature-workspace" ]
  [ "$(readlink "$TEMP_BIN_DIR/create-feature-workspace")" = "$SOURCE_SCRIPT" ]
}

@test "Fails when the target path already exists as a regular file" {
  mkdir -p "$TEMP_BIN_DIR"
  touch "$TEMP_BIN_DIR/create-feature-workspace"

  run bash "$SCRIPT" --bin-dir "$TEMP_BIN_DIR"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to replace non-symlink path"* ]]
}

@test "Uses HOME for the default bin dir and explains PATH setup" {
  home_dir="$BATS_TMP_DIR/home"

  run env HOME="$home_dir" PATH="/usr/bin:/bin" bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -L "$home_dir/.local/bin/create-feature-workspace" ]
  [[ "$output" == *"Installed symlink at: $home_dir/.local/bin/create-feature-workspace"* ]]
  [[ "$output" == *"Note: $home_dir/.local/bin is not currently in PATH."* ]]
  [[ "$output" != *"Created symlink:"* ]]
}
