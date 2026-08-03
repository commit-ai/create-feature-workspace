#!/usr/bin/env bash
set -euo pipefail

action="create"
feature_name=""
config_file=""
workspaces_root="~/workspaces"
no_worktrees="false"
entry_name=""
entry_path=""
entry_branch=""
entry_type="repository"

if [[ $# -gt 0 ]]; then
  case "$1" in
    add|remove|sync)
      action="$1"
      shift
      ;;
  esac
fi

usage() {
  cat >&2 <<EOF
Usage:
  $0 --feature-name NAME --config-file PATH [--workspaces-root PATH] [--no-worktrees]
  $0 add --feature-name NAME --name NAME --path PATH [--branch BRANCH] [--type repository|folder] [--workspaces-root PATH]
  $0 remove --feature-name NAME --name NAME [--workspaces-root PATH]
  $0 sync --feature-name NAME [--workspaces-root PATH]
EOF
}

error() {
  echo "$1" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 ]] || error "Missing value for $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-name)
      require_value "$@"
      feature_name="$2"
      shift 2
      ;;
    --config-file)
      require_value "$@"
      config_file="$2"
      shift 2
      ;;
    --workspaces-root)
      require_value "$@"
      workspaces_root="$2"
      shift 2
      ;;
    --no-worktrees)
      no_worktrees="true"
      shift
      ;;
    --name)
      require_value "$@"
      entry_name="$2"
      shift 2
      ;;
    --path)
      require_value "$@"
      entry_path="$2"
      shift 2
      ;;
    --branch)
      require_value "$@"
      entry_branch="$2"
      shift 2
      ;;
    --type)
      require_value "$@"
      entry_type="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$feature_name" ]] || {
  usage
  exit 1
}

if [[ "$action" == "create" ]]; then
  [[ -n "$config_file" ]] || {
    usage
    exit 1
  }
elif [[ "$no_worktrees" == "true" || -n "$config_file" ]]; then
  error "--config-file and --no-worktrees are only supported when creating a workspace"
fi

if [[ "$action" == "add" ]]; then
  [[ -n "$entry_name" && -n "$entry_path" ]] || error "add requires --name and --path"
elif [[ "$action" == "remove" ]]; then
  [[ -n "$entry_name" ]] || error "remove requires --name"
fi

expand_path() {
  case "$1" in
    "~") echo "$HOME" ;;
    "~/"*) echo "$HOME/${1#~/}" ;;
    *) echo "$1" ;;
  esac
}

workspaces_root="$(expand_path "$workspaces_root")"
[[ "$workspaces_root" == /* ]] || workspaces_root="$PWD/$workspaces_root"
workspace_dir="$workspaces_root/$feature_name"
manifest_file="$workspace_dir/.create-feature-workspace.ini"
state_file="$workspace_dir/.create-feature-workspace.state.ini"

entry_names=()
entry_paths=()
entry_branches=()
entry_types=()
manifest_mode=""

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

assert_entry_name() {
  local name="$1"
  [[ -n "$name" ]] || return 0  # empty name reported by validate_entries
  [[ "$name" != "." && "$name" != ".." ]] || error "Invalid entry name: $name"
  [[ "$name" != */* && "$name" != *\\* ]] || error "Invalid entry name: $name"
  [[ "$name" != ".create-feature-workspace.ini" && "$name" != ".create-feature-workspace.state.ini" ]] ||
    error "Invalid entry name: $name is reserved"
}

validate_entries() {
  local require_mode="$1"
  local i j

  if [[ "$require_mode" == "true" ]]; then
    [[ "$manifest_mode" == "worktree" || "$manifest_mode" == "symlink" ]] ||
      error "Missing or invalid workspace mode"
  fi

  for ((i = 0; i < ${#entry_names[@]}; i++)); do
    [[ "${entry_types[i]}" == "repository" || "${entry_types[i]}" == "folder" ]] ||
      error "Invalid type in section [${entry_names[i]}]: ${entry_types[i]}"
    if [[ "${entry_types[i]}" == "repository" && "$manifest_mode" == "worktree" ]]; then
      [[ -n "${entry_names[i]}" && -n "${entry_paths[i]}" && -n "${entry_branches[i]}" ]] ||
        error "Missing name/path/branch in section [${entry_names[i]}]"
    else
      [[ -n "${entry_names[i]}" && -n "${entry_paths[i]}" ]] ||
        error "Missing name/path in section [${entry_names[i]:-unknown}]"
    fi
    assert_entry_name "${entry_names[i]}"
    for ((j = 0; j < i; j++)); do
      [[ "${entry_names[i]}" != "${entry_names[j]}" ]] ||
        error "Duplicate workspace entry name: ${entry_names[i]}"
    done
  done
}

read_ini() {
  local file="$1"
  local metadata_section="$2"
  local require_mode="$3"
  local line section="" name="" path="" branch="" type="" mode=""
  local first_section="true"
  # per-section seen-key tracking (space-delimited list)
  local seen_keys=""

  [[ -f "$file" ]] || error "Config file not found: $file"
  entry_names=()
  entry_paths=()
  entry_branches=()
  entry_types=()
  manifest_mode=""

  flush_section() {
    [[ -n "$section" ]] || return 0
    if [[ -n "$metadata_section" && "$section" == "$metadata_section" ]]; then
      manifest_mode="$mode"
      return 0
    fi

    [[ -n "$name" || -n "$path" || -n "$branch" || -n "$type" ]] ||
      error "Empty section [$section]"
    entry_names+=("$name")
    entry_paths+=("$path")
    entry_branches+=("$branch")
    entry_types+=("${type:-repository}")
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      flush_section
      section="${BASH_REMATCH[1]}"
      if [[ "$first_section" == "true" && -n "$metadata_section" && "$section" != "$metadata_section" ]]; then
        error "Manifest must begin with [$metadata_section] section"
      fi
      first_section="false"
      name=""
      path=""
      branch=""
      type=""
      mode=""
      seen_keys=""
    elif [[ "$line" == *"="* ]]; then
      [[ -n "$section" ]] || error "Key outside a section: $line"
      local key value
      key="$(trim "${line%%=*}")"
      value="$(trim "${line#*=}")"
      # check for duplicate key within section
      [[ " $seen_keys " != *" $key "* ]] || error "duplicate key '$key' in section [$section]"
      seen_keys="$seen_keys $key"
      if [[ -n "$metadata_section" && "$section" == "$metadata_section" ]]; then
        # metadata section only allows mode key
        [[ "$key" == "mode" ]] || error "unknown key '$key' in section [$section]"
        mode="$value"
      elif [[ -n "$metadata_section" ]]; then
        # entry sections in manifest mode
        case "$key" in
          name) name="$value" ;;
          path) path="$value" ;;
          branch) branch="$value" ;;
          type) type="$value" ;;
          *) error "unknown key '$key' in section [$section]" ;;
        esac
      else
        # plain config file — allow all known keys, no unknown key check
        case "$key" in
          name) name="$value" ;;
          path) path="$value" ;;
          branch) branch="$value" ;;
          type) type="$value" ;;
          mode) mode="$value" ;;
        esac
      fi
    else
      error "Malformed config line: $line"
    fi
  done < "$file"

  flush_section
  validate_entries "$require_mode"
}

write_manifest() {
  local temp_file="$manifest_file.tmp"
  local i

  {
    printf '[workspace]\nmode = %s\n' "$manifest_mode"
    for ((i = 0; i < ${#entry_names[@]}; i++)); do
      printf '\n[entry-%s]\nname = %s\npath = %s\ntype = %s\n' \
        "$i" "${entry_names[i]}" "${entry_paths[i]}" "${entry_types[i]}"
      [[ -z "${entry_branches[i]}" ]] || printf 'branch = %s\n' "${entry_branches[i]}"
    done
  } > "$temp_file"
  mv "$temp_file" "$manifest_file"
}

state_names=()
state_paths=()
state_branches=()
state_types=()
state_mode=""

load_state() {
  if [[ ! -f "$state_file" ]]; then
    state_names=()
    state_paths=()
    state_branches=()
    state_types=()
    state_mode="$manifest_mode"
    return 0
  fi

  read_ini "$state_file" "state" "true"
  state_names=("${entry_names[@]+"${entry_names[@]}"}")
  state_paths=("${entry_paths[@]+"${entry_paths[@]}"}")
  state_branches=("${entry_branches[@]+"${entry_branches[@]}"}")
  state_types=("${entry_types[@]+"${entry_types[@]}"}")
  state_mode="$manifest_mode"
}

write_state() {
  local temp_file="$state_file.tmp"
  local i

  {
    printf '[state]\nmode = %s\n' "$state_mode"
    for ((i = 0; i < ${#state_names[@]}; i++)); do
      printf '\n[entry-%s]\nname = %s\npath = %s\ntype = %s\n' \
        "$i" "${state_names[i]}" "${state_paths[i]}" "${state_types[i]}"
      [[ -z "${state_branches[i]}" ]] || printf 'branch = %s\n' "${state_branches[i]}"
    done
  } > "$temp_file"
  mv "$temp_file" "$state_file"
}

find_desired() {
  local name="$1"
  local i
  found_index="-1"
  for ((i = 0; i < ${#desired_names[@]}; i++)); do
    if [[ "${desired_names[i]}" == "$name" ]]; then
      found_index="$i"
      return 0
    fi
  done
}

find_state() {
  local name="$1"
  local i
  found_index="-1"
  for ((i = 0; i < ${#state_names[@]}; i++)); do
    if [[ "${state_names[i]}" == "$name" ]]; then
      found_index="$i"
      return 0
    fi
  done
}

remove_state_entry() {
  local remove_index="$1"
  local i
  local new_names=() new_paths=() new_branches=() new_types=()
  for ((i = 0; i < ${#state_names[@]}; i++)); do
    [[ "$i" -eq "$remove_index" ]] && continue
    new_names+=("${state_names[i]}")
    new_paths+=("${state_paths[i]}")
    new_branches+=("${state_branches[i]}")
    new_types+=("${state_types[i]}")
  done
  state_names=("${new_names[@]+"${new_names[@]}"}")
  state_paths=("${new_paths[@]+"${new_paths[@]}"}")
  state_branches=("${new_branches[@]+"${new_branches[@]}"}")
  state_types=("${new_types[@]+"${new_types[@]}"}")
}

remove_managed_entry() {
  local index="$1"
  local destination="$workspace_dir/${state_names[index]}"

  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ "${state_types[index]}" == "repository" && "$state_mode" == "worktree" ]]; then
      git -C "$(expand_path "${state_paths[index]}")" worktree remove "$destination"
    elif [[ -L "$destination" ]]; then
      rm "$destination"
    else
      error "Managed entry is no longer a removable symlink: $destination"
    fi
  fi

  remove_state_entry "$index"
  write_state
}

state_entry_differs() {
  local state_index="$1"
  local desired_index="$2"

  [[ "${state_types[state_index]}" == "${desired_types[desired_index]}" ]] || return 0
  [[ "${state_paths[state_index]}" == "${desired_paths[desired_index]}" ]] || return 0
  if [[ "${desired_types[desired_index]}" == "repository" ]]; then
    [[ "${state_branches[state_index]}" == "${desired_branches[desired_index]}" ]] || return 0
    [[ "$state_mode" == "$manifest_mode" ]] || return 0
  fi
  return 1
}

create_desired_entry() {
  local index="$1"
  local destination="$workspace_dir/${desired_names[index]}"

  if [[ -e "$destination" || -L "$destination" ]]; then
    error "Refusing to replace unmanaged path: $destination"
  fi

  if [[ "${desired_types[index]}" == "folder" || "$manifest_mode" == "symlink" ]]; then
    ln -s "$(expand_path "${desired_paths[index]}")" "$destination"
  else
    git -C "$(expand_path "${desired_paths[index]}")" worktree add -b "$feature_name" \
      "$destination" "${desired_branches[index]}"
  fi

  state_names+=("${desired_names[index]}")
  state_paths+=("${desired_paths[index]}")
  state_branches+=("${desired_branches[index]}")
  state_types+=("${desired_types[index]}")
  state_mode="$manifest_mode"
  write_state
}

sync_workspace() {
  [[ -d "$workspace_dir" ]] || error "Workspace not found: $workspace_dir"
  read_ini "$manifest_file" "workspace" "true"
  desired_names=("${entry_names[@]+"${entry_names[@]}"}")
  desired_paths=("${entry_paths[@]+"${entry_paths[@]}"}")
  desired_branches=("${entry_branches[@]+"${entry_branches[@]}"}")
  desired_types=("${entry_types[@]+"${entry_types[@]}"}")
  local desired_mode="$manifest_mode"

  load_state
  local i desired_index
  for ((i = ${#state_names[@]} - 1; i >= 0; i--)); do
    find_desired "${state_names[i]}"
    desired_index="$found_index"
    if [[ "$desired_index" == "-1" ]] || state_entry_differs "$i" "$desired_index"; then
      remove_managed_entry "$i"
    fi
  done

  manifest_mode="$desired_mode"
  for ((i = 0; i < ${#desired_names[@]}; i++)); do
    find_state "${desired_names[i]}"
    if [[ "$found_index" == "-1" ]]; then
      create_desired_entry "$i"
    fi
  done

  state_mode="$manifest_mode"
  write_state
}

create_workspace() {
  read_ini "$config_file" "" "false"
  manifest_mode="worktree"
  [[ "$no_worktrees" == "true" ]] && manifest_mode="symlink"
  validate_entries "true"

  mkdir -p "$workspace_dir"
  [[ ! -e "$manifest_file" ]] || error "Workspace manifest already exists: $manifest_file"
  write_manifest
  sync_workspace
}

add_entry() {
  assert_entry_name "$entry_name"
  read_ini "$manifest_file" "workspace" "true"
  local i
  for ((i = 0; i < ${#entry_names[@]}; i++)); do
    [[ "${entry_names[i]}" != "$entry_name" ]] || error "Workspace entry already exists: $entry_name"
  done
  entry_names+=("$entry_name")
  entry_paths+=("$entry_path")
  entry_branches+=("$entry_branch")
  entry_types+=("$entry_type")
  validate_entries "true"
  write_manifest
  sync_workspace
}

remove_entry() {
  read_ini "$manifest_file" "workspace" "true"
  local i target_index="-1"
  for ((i = 0; i < ${#entry_names[@]}; i++)); do
    if [[ "${entry_names[i]}" == "$entry_name" ]]; then
      target_index="$i"
      break
    fi
  done
  [[ "$target_index" != "-1" ]] || error "Workspace entry not found: $entry_name"

  local new_names=() new_paths=() new_branches=() new_types=()
  for ((i = 0; i < ${#entry_names[@]}; i++)); do
    [[ "$i" -eq "$target_index" ]] && continue
    new_names+=("${entry_names[i]}")
    new_paths+=("${entry_paths[i]}")
    new_branches+=("${entry_branches[i]}")
    new_types+=("${entry_types[i]}")
  done
  entry_names=("${new_names[@]+"${new_names[@]}"}")
  entry_paths=("${new_paths[@]+"${new_paths[@]}"}")
  entry_branches=("${new_branches[@]+"${new_branches[@]}"}")
  entry_types=("${new_types[@]+"${new_types[@]}"}")
  # Stage the new manifest; sync using the staged version; commit on success
  local staged_manifest="${manifest_file}.staged"
  local orig_manifest_file="$manifest_file"
  manifest_file="$staged_manifest"
  write_manifest
  # Point sync at the staged manifest so it sees the desired state
  manifest_file="$staged_manifest"
  sync_workspace
  # Sync succeeded — promote the staged manifest
  mv "$staged_manifest" "$orig_manifest_file"
  manifest_file="$orig_manifest_file"
}

case "$action" in
  create) create_workspace ;;
  sync) sync_workspace ;;
  add) add_entry ;;
  remove) remove_entry ;;
esac
