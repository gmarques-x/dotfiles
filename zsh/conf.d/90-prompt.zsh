# Starship prompt, in the theme's colours (starship/theme.toml, written by `theme`;
# starship.toml, in Nord, until then). Terminal.app can't draw Nerd Font glyphs,
# so it gets the icon-free one.
() {
  local name=theme base=starship
  [[ "$TERM_PROGRAM" == Apple_Terminal ]] && name=theme-plain base=starship-plain
  if [[ -r "$XDG_CONFIG_HOME/starship/$name.toml" ]]; then
    export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/$name.toml"
  else
    export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/$base.toml"
  fi
}
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
