# Aliases. Edit with `zalias`; open a new shell (or `exec zsh`) to load changes.

alias zalias='${EDITOR:-vim} "$ZDOTDIR/conf.d/20-aliases.zsh"'   # edit this file
alias zedit='${EDITOR:-vim} "$ZDOTDIR"'                          # edit the zsh config folder
alias cls='clear && DOTFILES_FETCHED= exec zsh -l'               # clear and reload, like a new window

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

# y (or finder): yazi, and when you quit, the shell moves to the folder you were in.
if (( $+commands[yazi] )); then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    command yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp")"
    [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
  }
  alias finder='y'   # the same, by a friendlier name
fi
