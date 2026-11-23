# zoxide replaces cd (`builtin cd` still reaches the original).
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

# fzf: ⌃T files, ⌥C folders, ⌃G git commits, and anything piped into `fzf`.
# Its colours come from the theme (05-theme.zsh). ⌃R belongs to atuin, below.
if (( $+commands[fzf] )); then
  if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
    export FZF_ALT_C_COMMAND='fd --type d --hidden --strip-cwd-prefix --exclude .git'
    _fzf_compgen_path() { fd --hidden --exclude .git . "$1" }   # ** completion
    _fzf_compgen_dir()  { fd --type d --hidden --exclude .git . "$1" }
  fi
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :200 {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons=always {}'"
  source <(fzf --zsh)

  # ⌃G: pick commits from this repo's history (Tab marks several); their short
  # hashes go on the command line, e.g. after `git show ` or `git revert `.
  fzf-git-commit-widget() {
    git rev-parse --git-dir >/dev/null 2>&1 || { zle -M "not a git repository"; return 0 }
    local picked
    picked=$(git log --color=always --format='%C(yellow)%h%C(reset) %s %C(dim)(%cr, %an)%C(reset)' |
      fzf --ansi --multi --no-sort --prompt 'commit ❯ ' \
          --preview 'git show --color=always --stat --patch {1} | delta --paging=never 2>/dev/null || git show --color=always {1}' \
          --preview-window 'right,60%' | awk '{ print $1 }' | tr '\n' ' ')
    LBUFFER+="${picked% }"
    zle reset-prompt
  }
  zle -N fzf-git-commit-widget
  bindkey '^G' fzf-git-commit-widget
fi

# atuin: searchable history on ⌃R (after fzf, so it takes ⌃R over). The up arrow
# stays zsh's own.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
