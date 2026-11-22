# Login shells: Homebrew's environment (PATH, HOMEBREW_PREFIX, ...).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi
# /etc/zprofile (path_helper) reorders PATH after .zshenv; put ~/.local/bin back first.
typeset -U path
path=("$HOME/.local/bin" ${path:#$HOME/.local/bin})
