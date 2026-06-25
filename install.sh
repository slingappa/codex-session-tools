#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Install agentic-session-tools for the current user.

Usage:
  ./install.sh [--prefix DIR] [--aliases] [--shell rcfile]

Options:
  --prefix DIR   Install prefix. Default: ~/.local
  --aliases      Append ags/cs/cxs aliases to the detected running shell rc file
  --shell FILE   Shell rc file to update when --aliases is used
  -h, --help     Show this help

Examples:
  ./install.sh
  ./install.sh --aliases
  ./install.sh --prefix ~/tools/agentic-session-tools
USAGE
}

prefix="$HOME/.local"
add_aliases=0
shell_rc=""
alias_status="not requested"

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

shell_quote() {
  printf '%q' "$1"
}

detect_running_shell() {
  local shell_name=""
  if command -v ps >/dev/null 2>&1 && [[ -n "${PPID:-}" ]]; then
    shell_name="$(ps -p "$PPID" -o comm= 2>/dev/null || true)"
  fi
  shell_name="${shell_name#"${shell_name%%[![:space:]]*}"}"
  shell_name="${shell_name%"${shell_name##*[![:space:]]}"}"
  shell_name="${shell_name#-}"
  shell_name="${shell_name##*/}"
  if [[ -z "$shell_name" ]]; then
    local login_shell="${SHELL:-}"
    login_shell="${login_shell##*/}"
    if [[ -n "$login_shell" ]]; then
      shell_name="$login_shell"
    fi
  fi
  printf '%s' "$shell_name"
}

default_shell_rc() {
  local shell_name="$1"
  case "$shell_name" in
    zsh) printf '%s/.zshrc' "$HOME" ;;
    bash) printf '%s/.bashrc' "$HOME" ;;
    sh|dash|ksh) printf '%s/.profile' "$HOME" ;;
    *) printf '%s/.profile' "$HOME" ;;
  esac
}

source_command_for() {
  local rc_file="$1"
  case "${rc_file##*/}" in
    .zshrc|.bashrc) printf 'source %s' "$(shell_quote "$rc_file")" ;;
    *) printf '. %s' "$(shell_quote "$rc_file")" ;;
  esac
}

missing=0
for cmd in python3 install; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    missing=1
  fi
done
if ! python3 - <<'PY_CHECK' >/dev/null 2>&1
import sys
if sys.version_info < (3, 7):
    raise SystemExit("python 3.7+ required")
import argparse, curses, dataclasses, json, pathlib, subprocess
PY_CHECK
then
  echo "python3 is present, but Python 3.7+ and required stdlib modules are needed; on some distros install python3-curses" >&2
  missing=1
fi
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi
if ! command -v tmux >/dev/null 2>&1; then
  echo "warning: tmux not found; list/rename/delete/resume work, but 'agentic-sessions tmux' will not" >&2
fi
if [[ -z "${CODEX_BIN:-}" ]] && ! command -v codex >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/codex" ]]; then
  echo "warning: codex not found in PATH or ~/.local/bin; set CODEX_BIN=/path/to/codex for Codex resume/tmux" >&2
fi
if [[ -z "${CLAUDE_BIN:-}" ]] && ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
  echo "warning: claude not found in PATH or ~/.local/bin; set CLAUDE_BIN=/path/to/claude for Claude resume/tmux" >&2
fi

install_bin="$prefix/bin"
mkdir -p "$install_bin"
install -m 0755 "$src_dir/bin/agentic-sessions" "$install_bin/agentic-sessions"
install -m 0755 "$src_dir/bin/codex-sessions" "$install_bin/codex-sessions"

if [[ "$add_aliases" -eq 1 ]]; then
  if [[ -z "$shell_rc" ]]; then
    detected_shell="$(detect_running_shell)"
    shell_rc="$(default_shell_rc "$detected_shell")"
  else
    detected_shell="custom"
  fi
  mkdir -p "$(dirname "$shell_rc")"
  touch "$shell_rc"
  if ! grep -q "agentic-session-tools aliases" "$shell_rc"; then
    cat >> "$shell_rc" <<ALIASES

# agentic-session-tools aliases
alias ags='$install_bin/agentic-sessions '
alias cs='$install_bin/agentic-sessions '
alias cxs='$install_bin/codex-sessions '
ALIASES
    alias_status="added to $shell_rc"
  else
    alias_status="already present in $shell_rc"
  fi
fi

python3 -m py_compile "$install_bin/agentic-sessions"
rm -rf "$install_bin/__pycache__"
"$install_bin/agentic-sessions" --help >/dev/null
"$install_bin/codex-sessions" --help >/dev/null

cat <<MSG
Installed agentic-sessions to:
  $install_bin/agentic-sessions

Compatibility command also installed:
  $install_bin/codex-sessions

Install check passed.
Aliases: $alias_status

Quick start:
  export PATH="$install_bin:\$PATH"
MSG

if [[ "$add_aliases" -eq 1 ]]; then
  cat <<MSG
  $(source_command_for "$shell_rc")
  ags doctor
  ags list -n 10
  ags --provider claude list -n 10
  ags tmux
MSG
else
  cat <<'MSG'
  agentic-sessions doctor
  agentic-sessions list -n 10
  agentic-sessions --provider claude list -n 10
  agentic-sessions tmux
MSG
fi
