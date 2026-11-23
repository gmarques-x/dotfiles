# Completion: zsh's own system plus Homebrew's completions (zsh-completions, gh, ...).
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" "$HOMEBREW_PREFIX/share/zsh-completions" $fpath)
  typeset -U fpath
fi
[[ -d "$XDG_CACHE_HOME/zsh" ]] || mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit
# -i skips (rather than asks about) folders compaudit thinks are insecure.
compinit -i -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

# `theme <Tab>` lists the themes (bin/theme)
_theme() { compadd list current apply ${commands[theme]:A:h:h}/themes/*.sh(N:t:r) }
(( $+commands[theme] )) && compdef _theme theme
