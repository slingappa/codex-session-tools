# codex-session-tools

`codex-session-tools` is a small, relocatable helper for browsing and resuming
Codex sessions without modifying Codex itself.

It provides:

- `codex-sessions list` — list recent Codex sessions with time, CWD, and prompt preview
- `codex-sessions rename` — add human-friendly titles using sidecar metadata
- `codex-sessions delete` — move session rollout files to a recoverable trash folder
- `codex-sessions resume` — resume by UUID, UUID prefix, or unique text fragment
- `codex-sessions tmux` — tmux two-pane workspace with a session sidebar

The tool is intentionally dependency-light: Python 3 stdlib plus `tmux` for sidebar mode.


## Screenshots

The screenshots below use representative session data and do not expose real team session contents.

### Dependency Check

![codex-sessions doctor terminal output](docs/screenshots/doctor.svg)

### Session List

![codex-sessions list terminal output](docs/screenshots/list.svg)

### tmux Sidebar With Resumed Codex Session

![codex-sessions tmux sidebar next to an active resumed Codex session](docs/screenshots/tmux-sidebar.svg)

## Requirements

Required for core commands (`paths`, `list`, `rename`, `delete`):

- Linux/macOS shell environment
- Python 3.8+
- Python stdlib modules: `argparse`, `curses`, `dataclasses`, `datetime`, `glob`, `json`, `os`, `pathlib`, `re`, `shutil`, `subprocess`, `time`
  - Note: on some Linux distributions, `curses` is packaged separately as `python3-curses`.
- Existing Codex session files under one of:
  - `$CODEX_HOME/sessions`
  - `$CODEX_HOME/agent/sessions`
  - `~/.codex/sessions`
  - `~/.config/codex/sessions`

Required for resume/sidebar workflows:

- Codex installed as `codex`, available at `~/.local/bin/codex`, or configured via `CODEX_BIN=/path/to/codex`
- A Codex-compatible wrapper can be used by setting `CODEX_BIN` to that executable path or command name
- `tmux` for `codex-sessions tmux`
- A POSIX-compatible shell for tmux pane bootstrap snippets (`sh`, `bash`, or `zsh`)

Required only for installation/packaging:

- `bash` to run `install.sh`
- `install` command from GNU coreutils/BSD userland
- `tar` and `sha256sum` only if you want to recreate the shareable archive/checksum

Not required by the tool: `jq`, `fzf`, `gum`, `dialog`, `zellij`, `textual`, `prompt_toolkit`, or any Python packages outside the standard library.

Run this after install to verify a machine:

```bash
codex-sessions doctor
```

Use `--strict` when validating full sidebar/resume readiness, including optional `codex` and `tmux`:

```bash
codex-sessions doctor --strict
```

## Quick Start

From this folder:

```bash
./install.sh --aliases
source ~/.zshrc   # or source ~/.bashrc, depending on your shell
cs doctor
cs list -n 10
cs tmux
```

Without installing:

```bash
export PATH=/path/to/codex-session-tools/bin:$PATH
codex-sessions list -n 10
codex-sessions tmux
```

If Codex is not in `PATH`, or you need a Codex-compatible wrapper:

```bash
export CODEX_BIN=/absolute/path/to/codex
# Optional: if sessions live outside the default Codex home
export CODEX_HOME=/absolute/path/to/codex-home-or-agent
codex-sessions tmux
```

For machine-local defaults without changing your shell rc, create an ignored local env file next to this repo:

```bash
cat > .codex-session-tools.env <<'EOF'
CODEX_HOME=/absolute/path/to/codex-home-or-agent
CODEX_BIN=/absolute/path/to/codex-or-compatible-wrapper
EOF
```

## Installation

Install to `~/.local/bin`:

```bash
./install.sh
```

Install and add `cs`/`cxs` aliases:

```bash
./install.sh --aliases
source ~/.zshrc   # zsh
# or
source ~/.bashrc  # bash
```

Install to a custom prefix:

```bash
./install.sh --prefix ~/tools
export PATH="$HOME/tools/bin:$PATH"
```

The installer copies only `bin/codex-sessions`; the tool remains relocatable.


## Shell RC / Alias Notes

The tool itself does **not** require `~/.zshrc`, `~/.bashrc`, or any team-specific shell setup.

Shell rc changes are optional and only used for convenience aliases:

```bash
alias cs='/path/to/codex-sessions '
alias cxs='/path/to/codex-sessions '
```

`./install.sh --aliases` appends those aliases to the detected shell rc file:

- zsh: `~/.zshrc`
- bash: `~/.bashrc`
- fallback: `~/.profile`

If a teammate does not want rc-file changes, use one of these instead:

```bash
export PATH="$HOME/.local/bin:$PATH"
codex-sessions tmux
```

or run directly:

```bash
/path/to/codex-session-tools/bin/codex-sessions tmux
```

If someone has a custom `codex()` shell function in their rc file, it is not required by this tool.
The sidebar resolves Codex through `CODEX_BIN`, `PATH`, or common install locations and sends an absolute binary path when possible. If the wrong executable is selected, set:

```bash
export CODEX_BIN=/absolute/path/to/codex
```

`CODEX_BIN` is intentionally generic: it may point to `codex` itself or to a
Codex-compatible wrapper executable. The tool does not hardcode wrapper names.

For teams that wrap Codex with `script` for chat logs, ensure the util-linux `script` argument order is correct on that machine. Common Linux form:

```bash
script -qf -c "/path/to/codex resume <id>" /path/to/logfile
```

BSD/macOS variants may differ; this wrapper is optional and not part of `codex-session-tools`.

## Commands

Show detected paths and dependency status:

```bash
codex-sessions paths
codex-sessions doctor
codex-sessions doctor --strict
```

List sessions:

```bash
codex-sessions list -n 20
codex-sessions list -q rv_github
codex-sessions list --long
codex-sessions list --json
```

Rename a session using sidecar metadata:

```bash
codex-sessions rename 019eda11 "RPMI telemetry docs"
codex-sessions rename 019eda11 ""   # clear custom title
```

Resume a session:

```bash
codex-sessions resume 019eda11
codex-sessions resume "RPMI telemetry"
```

Trash a session rollout file:

```bash
codex-sessions delete 019eda11
```

Launch the tmux sidebar:

```bash
codex-sessions tmux
```

Inside an existing tmux session, `tmux` mode splits the current window into panes.
Outside tmux, it creates a new tmux session with one window and two panes.

## tmux Sidebar Keys

- `j` / `k` or arrow keys: move selection
- `Enter`: resume selected session in the right pane and focus that pane
- `r`: rename selected session
- `d`: trash selected session after typing `DELETE`
- `/`: search/filter sessions
- `c`: clear search filter
- `R`: refresh cached session list
- `q`: close the sidebar pane

The sidebar caches the session list for fast arrow-key navigation. It reloads only on
search, clear, rename, delete, or manual refresh.

## Working Directory Prompt

Codex may ask:

```text
Choose working directory to resume this session
1. Use session directory (...)
2. Use current directory (...)
```

After selecting a session from the sidebar, focus should automatically move to the
right pane. Press `Enter` to accept the default, or choose the desired option there.

## Safety Model

The tool does not edit Codex rollout JSONL files for normal metadata operations.

- Custom names are stored in sidecar metadata:
  - `~/.codex/session-tools/session-names.json`
- Delete/trash moves rollout files into:
  - `~/.codex/session-tools/trash/`
- Trash operations append a manifest:
  - `~/.codex/session-tools/trash/manifest.jsonl`

Use `--state-root DIR` to keep metadata somewhere else.

## Configuration Overrides

Use these when auto-detection does not match your setup:

```bash
codex-sessions --agent-home /path/to/agent paths
codex-sessions --sessions-root /path/to/sessions list
codex-sessions --state-root /path/to/state rename <id> "Title"
codex-sessions tmux --codex-bin /path/to/codex
```

Environment variables:

- `CODEX_BIN`: explicit Codex binary path
- `CODEX_HOME`: agent home containing `sessions/`, or CLI home containing `agent/sessions/`
- `CODEX_SESSIONS_ROOT`: explicit rollout JSONL session root; overrides `CODEX_HOME`
- `CODEX_SESSION_TOOLS_HOME`: sidecar metadata root

## Validation Status

This package was smoke-tested in a clean Docker container based on Ubuntu with Python 3.8.10, no `tmux`, and no real Codex installed. Validated paths:

- `install.sh --prefix ... --aliases --shell ...`
- `codex-sessions doctor` with missing optional `codex`/`tmux` warnings
- `codex-sessions doctor --strict` failing when optional sidebar/resume deps are absent
- `list`, `rename`, `delete`, and trash manifest using fake session JSONL
- `resume` using a fake `codex` binary in `PATH`

The tmux sidebar was validated on the host environment where real `tmux` is available.

## Troubleshooting

### `codex: command not found` after pressing Enter

Restart the sidebar after updating this tool. The current sidebar process may still
be using old code. Also verify:

```bash
codex-sessions resume <id> --print-command
```

It should print an absolute Codex path when Codex is installed in `~/.local/bin`.
If not, set:

```bash
export CODEX_BIN=/absolute/path/to/codex
```

### Sidebar opens but arrows feel slow

Use the latest version of this tool. The sidebar should cache sessions and move
without reparsing JSONL on every keypress. Press `R` to refresh manually.

### Sidebar creates a new window inside tmux

Use the latest version. Inside tmux, `codex-sessions tmux` should split the current
window, not create a new window.

### I am stuck at Codex's working-directory prompt

Move to the right pane with your tmux prefix + arrow key, or restart with the latest
tool version. Current versions automatically focus the right pane after `Enter`.

### Session list is missing expected sessions

Check detected paths:

```bash
codex-sessions paths
```

Then override if needed:

```bash
codex-sessions --sessions-root /path/to/sessions list -n 20
```

## Sharing With Teammates

Recommended options:

1. Share the directory as-is:

   ```bash
   tar -czf codex-session-tools.tar.gz codex-session-tools
   ```

2. Teammates unpack and install:

   ```bash
   tar -xzf codex-session-tools.tar.gz
   cd codex-session-tools
   ./install.sh --aliases
   source ~/.zshrc
   cs tmux
   ```

3. Or run directly without installation:

   ```bash
   ./bin/codex-sessions list -n 10
   ./bin/codex-sessions tmux
   ```

## Uninstall

If installed to `~/.local/bin`:

```bash
rm -f ~/.local/bin/codex-sessions
```

If aliases were added, remove this block from your shell rc file:

```bash
# codex-session-tools aliases
alias cs='.../codex-sessions '
alias cxs='.../codex-sessions '
```

Sidecar metadata is not removed automatically. To remove it:

```bash
rm -rf ~/.codex/session-tools
```

Review the trash folder before deleting it if you used `delete`.
