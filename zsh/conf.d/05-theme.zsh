# Colours from `theme`: theme.zsh (written by `theme`, not tracked by git) sets
# fzf's, zsh-syntax-highlighting's and zsh-autosuggestions' colours, BAT_THEME
# and GLOW_STYLE. Open shells re-read it at the next prompt after a switch.
FZF_BASE_OPTS='--height 40% --layout reverse --border none --info inline-right'
export FZF_DEFAULT_OPTS="$FZF_BASE_OPTS"

zmodload -F zsh/stat b:zstat
_theme_load() {
  local -a m
  zstat -A m +mtime "$ZDOTDIR/theme.zsh" 2>/dev/null || return 0
  [[ "$m[1]" == "${_theme_mtime:-}" ]] && return
  _theme_mtime=$m[1]
  source "$ZDOTDIR/theme.zsh"
}
_theme_load
precmd_functions+=(_theme_load)
