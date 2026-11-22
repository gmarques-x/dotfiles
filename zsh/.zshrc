# Interactive shells: load every conf.d/*.zsh in name order.
# Machine-specific additions go in conf.d/local.zsh (not tracked by git).
for _conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$_conf"
done
unset _conf
