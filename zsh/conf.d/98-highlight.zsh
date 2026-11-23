# Syntax highlighting, loaded last so it wraps every other widget. Its colours
# come from the theme (05-theme.zsh), set before it loads.
_f="${HOMEBREW_PREFIX:-/nonexistent}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -r "$_f" ]] && source "$_f"
unset _f
