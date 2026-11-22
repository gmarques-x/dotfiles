# A fastfetch summary once per new terminal window. DOTFILES_FETCHED is inherited
# by shells started from this one, so they stay quiet. Turn it off with
# DOTFILES_NO_FETCH=1 (e.g. in conf.d/local.zsh).
if [[ -o interactive && -t 1 && -z "$DOTFILES_FETCHED" && -z "$DOTFILES_NO_FETCH" ]] \
  && [[ "$TERM_PROGRAM" == ghostty || "$TERM_PROGRAM" == Apple_Terminal ]] \
  && (( $+commands[fastfetch] )); then
  print
  fastfetch || true
  export DOTFILES_FETCHED=1
fi
