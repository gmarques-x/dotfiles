# Codex home

Earlier versions of the installer used `~/.config/codex`. To keep using that home with the CLI, set `CODEX_HOME="$HOME/.config/codex"` in your local shell environment. Git ignores credentials, settings, sessions, and databases stored in the optional `codex/` directory in this checkout.

To move an existing **directory** here, quit ChatGPT and Codex and close any Codex CLI sessions first. Run the following for a checkout at `~/Developer/dotfiles`. It copies the data, saves the original directory as a backup, and creates the link.

```bash
source_dir="$HOME/.config/codex"
target_dir="$HOME/Developer/dotfiles/codex"
test -d "$source_dir" && test ! -L "$source_dir" &&
  mkdir -p "$target_dir" &&
  backup_dir="$(mktemp -d "$HOME/.config/codex-backup.XXXXXXXX")" &&
  rsync -a --ignore-existing "$source_dir/" "$target_dir/" &&
  mv "$source_dir" "$backup_dir/codex" &&
  ln -s "$target_dir" "$source_dir"
```

The backup is in the newly created `~/.config/codex-backup.*` directory. If your existing Codex home is a symlink, identify its target before migrating.
