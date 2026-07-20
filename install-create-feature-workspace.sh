#!/usr/bin/env bash
set -euo pipefail

bin_dir="~/.local/bin"
link_name="create-feature-workspace"

usage() {
  cat <<EOF
Usage: $0 [--bin-dir PATH]

Creates a symlink so you can run:
  $link_name <args...>

Options:
  --bin-dir PATH  Directory where the symlink will be created (default: ~/.local/bin)
  -h, --help      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      [[ $# -ge 2 ]] || {
        echo "Missing value for --bin-dir" >&2
        exit 1
      }
      bin_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_script="$script_dir/create-feature-workspace.sh"
case "$bin_dir" in
  "~") bin_dir="$HOME" ;;
  "~/"*) bin_dir="$HOME/${bin_dir#"~/"}" ;;
esac
link_path="$bin_dir/$link_name"

[[ -f "$source_script" ]] || {
  echo "Source script not found: $source_script" >&2
  exit 1
}

mkdir -p "$bin_dir"
chmod +x "$source_script"

if [[ -e "$link_path" && ! -L "$link_path" ]]; then
  echo "Refusing to replace non-symlink path: $link_path" >&2
  exit 1
fi

if [[ -L "$link_path" ]]; then
  current_target="$(readlink "$link_path")"
  if [[ "$current_target" == "$source_script" ]]; then
    echo "Symlink already configured: $link_path -> $source_script"
    exit 0
  fi

  rm "$link_path"
fi

ln -s "$source_script" "$link_path"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    echo "Installed symlink at: $link_path"
    echo "Note: $bin_dir is not currently in PATH. Add it to your shell configuration and restart your shell."
    exit 0
    ;;
esac

echo "Created symlink: $link_path -> $source_script"
