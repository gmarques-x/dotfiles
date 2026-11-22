# zoxide replaces cd (`builtin cd` still reaches the original); fzf binds
# ⌃R (history), ⌃T (files) and ⌥C (folders).
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi
if (( $+commands[fzf] )); then
  if (( $+commands[rg] )); then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
  export FZF_DEFAULT_OPTS="--color=bg:#2E3440,bg+:#434C5E,fg:#D8DEE9,fg+:#D8DEE9,hl:#A3BE8C,hl+:#A3BE8C,prompt:#88C0D0,pointer:#BF616A,marker:#EBCB8B,info:#919CB3,spinner:#88C0D0,header:#81A1C1,border:#4C566A"
  source <(fzf --zsh)
fi
