# Syntax highlighting, loaded last so it wraps every other widget.
_f="${HOMEBREW_PREFIX:-/nonexistent}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [[ -r "$_f" ]]; then
  source "$_f"
  ZSH_HIGHLIGHT_STYLES[command]='fg=#A3BE8C'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=#A3BE8C'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=#A3BE8C'
  ZSH_HIGHLIGHT_STYLES[function]='fg=#A3BE8C'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#BF616A'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#EBCB8B'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#EBCB8B'
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#EBCB8B'
  ZSH_HIGHLIGHT_STYLES[path]='underline'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=#919CB3'
fi
unset _f
