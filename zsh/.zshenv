# Every zsh reads this first (~/.zshenv is a link to it). Keep it quiet and fast.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# The rest of the zsh config lives in ~/.config/zsh.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

export EDITOR="${EDITOR:-vim}"
export LANG="${LANG:-en_US.UTF-8}"

typeset -U path
path=("$HOME/.local/bin" $path)
