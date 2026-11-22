# Suggestions from history in dim grey; → accepts one.
_f="${HOMEBREW_PREFIX:-/nonexistent}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -r "$_f" ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#919CB3'
  source "$_f"
fi
unset _f
