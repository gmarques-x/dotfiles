# Aliases. Edit with `zalias`; open a new shell (or `exec zsh`) to load changes.

alias zalias='${EDITOR:-vim} "$ZDOTDIR/conf.d/20-aliases.zsh"'   # edit this file
alias zedit='${EDITOR:-vim} "$ZDOTDIR"'                          # edit the zsh config folder
alias cls='clear && DOTFILES_FETCHED= exec zsh -l'               # clear and reload, like a new window

# The dotfiles: go there, or pull them and apply what changed
# (dots-sync --all re-applies everything; --dry-run only shows what would run).
alias dots='cd ~/Developer/dotfiles'
dots-sync() {
  command dots-sync "$@" && [[ " $* " != *" --dry-run "* && " $* " != *" -n "* ]] && exec zsh
}
alias brewup='brew update && brew upgrade'

# Places
alias dev='cd ~/Developer'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
mkcd() { mkdir -p -- "$1" && builtin cd -- "$1" }   # make a folder and go into it

# Listings: folders first, then files, each A→Z ignoring case. Icons only where
# the terminal can draw them (not Terminal.app). The originals stay as \ls, \cat.
if (( $+commands[eza] )); then
  # ls and ll go through _eza_ls, which is eza taking ls's everyday sort flags,
  # alone or bundled (-ltr, -lrt, -ltrh): -t newest first, -S largest first, -r
  # the other way round. Everything else goes to eza as typed; nothing after
  # `--` is touched.
  _eza_ls() {
    local -a opts rest
    local a c kept sort="" rev=0
    while (( $# )); do
      a="$1"
      [[ "$a" == -- ]] && break
      shift
      if [[ "$a" == -[trS[:alnum:]@]* && "${a#-}" != *[^[:alnum:]@]* && "$a" == *[trS]* && "$a" != *[sLIw]* ]]; then
        kept=-
        for c in ${(s::)a#-}; do
          case "$c" in
            t) sort=modified ;;
            S) sort=size ;;
            r) rev=1 ;;
            *) kept+="$c" ;;
          esac
        done
        [[ "$kept" == - ]] || opts+=("$kept")
      else
        opts+=("$a")
      fi
    done
    rest=("$@")
    if [[ -n "$sort" ]]; then
      opts=("${(@)opts:#--group-directories-first}" "--sort=$sort")
      (( rev )) || opts+=(--reverse)
    elif (( rev )); then
      opts+=(--reverse)
    fi
    command eza "${opts[@]}" "${rest[@]}"
  }
  _icons=(--icons=auto)
  [[ "$TERM_PROGRAM" == Apple_Terminal ]] && _icons=()
  alias ls="_eza_ls -l --group-directories-first --sort=name --git ${_icons[*]}"   # long listing
  alias ll="_eza_ls -la --group-directories-first --sort=name --git ${_icons[*]}"  # ls plus hidden files
  alias lt="eza --tree --level=2 --group-directories-first ${_icons[*]}"         # two-level tree
  unset _icons
fi

if (( $+commands[bat] )); then
  alias cat='bat --paging=auto'  # pages only files longer than the window
fi

# Better versions of the usual tools. The originals stay as \top, \du, \df.
(( $+commands[htop] )) && alias top='htop'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[duf] ))  && alias df='duf'

# Editors and development
(( $+commands[nvim] )) && alias vi='nvim'
(( $+commands[code] )) && alias vs='code'
(( $+commands[lazygit] )) && alias lg='lazygit'
alias g='git'
alias python='python3'
alias pip='pip3'

# finder: yazi, and when you quit, the shell moves to the folder you were in.
if (( $+commands[yazi] )); then
  finder() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    command yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp")"
    [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
  }
fi
