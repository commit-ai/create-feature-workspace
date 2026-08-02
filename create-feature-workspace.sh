#!/usr/bin/env bash
set -euo pipefail

feature_name=""
config_file=""
workspaces_root="~/workspaces"
no_worktrees="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-name) feature_name="$2"; shift 2 ;;
    --config-file) config_file="$2"; shift 2 ;;
    --workspaces-root) workspaces_root="$2"; shift 2 ;;
    --no-worktrees) no_worktrees="true"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$feature_name" && -n "$config_file" ]] || {
  echo "Usage: $0 --feature-name NAME --config-file PATH [--workspaces-root PATH]" >&2
  exit 1
}

expand_path() {
  case "$1" in
    "~") echo "$HOME" ;;
    "~/"*) echo "$HOME/${1#~/}" ;;
    *) echo "$1" ;;
  esac
}

workspaces_root="$(expand_path "$workspaces_root")"
[[ "$workspaces_root" == /* ]] || workspaces_root="$PWD/$workspaces_root"
mkdir -p "$workspaces_root/$feature_name"

section=""
name=""
path=""
branch=""

flush_repo() {
  [[ -n "$section" ]] || return 0
  if [[ "$no_worktrees" == "true" ]]; then
    [[ -n "$name" && -n "$path" ]] || {
      echo "Missing name/path in section [$section]" >&2
      exit 1
    }
    path="$(expand_path "$path")"
    ln -s "$path" "$workspaces_root/$feature_name/$name"
  else
    [[ -n "$name" && -n "$path" && -n "$branch" ]] || {
      echo "Missing name/path/branch in section [$section]" >&2
      exit 1
    }
    path="$(expand_path "$path")"
    git -C "$path" worktree add -b "$feature_name" \
      "$workspaces_root/$feature_name/$name" "$branch"
  fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* || "$line" == \;* ]] && continue

  if [[ "$line" =~ ^\[(.+)\]$ ]]; then
    flush_repo
    section="${BASH_REMATCH[1]}"
    name=""; path=""; branch=""
  elif [[ "$line" == *"="* ]]; then
    key="${line%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    case "$key" in
      name) name="$value" ;;
      path) path="$value" ;;
      branch) branch="$value" ;;
    esac
  fi
done < "$config_file"

flush_repo