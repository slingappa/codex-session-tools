#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Install codex-session-tools for the current user.

Usage:
  ./install.sh [--prefix DIR] [--aliases] [--shell rcfile]

Options:
  --prefix DIR   Install prefix. Default: ~/.local
  --aliases      Append cs/cxs aliases to the detected shell rc file
  --shell FILE   Shell rc file to update when --aliases is used
  -h, --help     Show this help

Examples:
  ./install.sh
  ./install.sh --aliases
  ./install.sh --prefix ~/tools/codex-session-tools
USAGE
}

prefix="$HOME/.local"
add_aliases=0
shell_rc=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      prefix="${2:?missing value for --prefix}"
      shift 2
      ;;
    --aliases)
      add_aliases=1
      shift
      ;;
    --shell)
      shell_rc="${2:?missing value for --shell}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

missing=0
for cmd in python3 install; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    missing=1
  fi
done
if ! python3 - <<'PY_CHECK' >/dev/null 2>&1
import sys
if sys.version_info < (3, 8):
    raise SystemExit("python 3.8+ required")
import argparse, curses, dataclasses, json, pathlib, subprocess
PY_CHECK
then
  echo "python3 is present, but Python 3.8+ and required stdlib modules are needed; on some distros install python3-curses" >&2
  missing=1
fi
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi
if ! command -v tmux >/dev/null 2>&1; then
  echo "warning: tmux not found; list/rename/delete/resume work, but 'codex-sessions tmux' will not" >&2
fi
if [[ -z "${CODEX_BIN:-}" ]] && ! command -v codex >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/codex" ]]; then
  echo "warning: codex not found in PATH or ~/.local/bin; set CODEX_BIN=/path/to/codex for resume/tmux" >&2
fi

install_bin="$prefix/bin"
mkdir -p "$install_bin"
install -m 0755 "$src_dir/bin/codex-sessions" "$install_bin/codex-sessions"

cat <<MSG
Installed codex-sessions to:
  $install_bin/codex-sessions

Ensure this is in PATH:
  export PATH="$install_bin:\$PATH"
MSG

if [[ "$add_aliases" -eq 1 ]]; then
  if [[ -z "$shell_rc" ]]; then
    case "${SHELL:-}" in
      */zsh) shell_rc="$HOME/.zshrc" ;;
      */bash) shell_rc="$HOME/.bashrc" ;;
      *) shell_rc="$HOME/.profile" ;;
    esac
  fi
  mkdir -p "$(dirname "$shell_rc")"
  touch "$shell_rc"
  if ! grep -q "codex-session-tools aliases" "$shell_rc"; then
    cat >> "$shell_rc" <<ALIASES

# codex-session-tools aliases
alias cs='$install_bin/codex-sessions '
alias cxs='$install_bin/codex-sessions '
ALIASES
    echo "Added cs/cxs aliases to $shell_rc"
  else
    echo "Aliases marker already exists in $shell_rc; leaving it unchanged"
  fi
fi

python3 -m py_compile "$install_bin/codex-sessions"
rm -rf "$install_bin/__pycache__"
"$install_bin/codex-sessions" --help >/dev/null

echo "Install check passed. Try: codex-sessions list -n 10"
