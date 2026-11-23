# Every zsh reads this first (~/.zshenv is a link to it). Keep it quiet and fast.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# The rest of the zsh config lives in ~/.config/zsh.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Keep dotfiles out of ~/ : tools that honour a variable are pointed at an XDG folder.
export SHELL_SESSION_DIR="$XDG_STATE_HOME/zsh/sessions"   # Terminal.app's per-window history
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export CODEX_HOME="$XDG_CONFIG_HOME/codex"                # linked to OneDrive by install.sh

export EDITOR="${EDITOR:-vim}"
export LANG="${LANG:-en_US.UTF-8}"

typeset -U path
path=("$HOME/.local/bin" $path)
