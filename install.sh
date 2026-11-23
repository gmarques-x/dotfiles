#!/usr/bin/env bash
# dotfiles installer for macOS. On a fresh Mac:
#   curl -fsSL https://raw.githubusercontent.com/gmarques-x/dotfiles/main/install.sh | bash
#
#   1. Command Line Tools (git, compilers) and Homebrew
#   2. OneDrive (then waits while you finish its setup wizard)
#   3. Command-line tools and fonts (Brewfile), then the apps you pick from
#      Brewfile.apps (Rosetta first, for Steam), and Chrome as the default browser
#   4. Creates ~/Developer and the XDG folders, links the configs into
#      ~/.config (and ~/.zshenv, VS Code's settings, ~/.local/bin/theme and
#      dots-sync), moves stray dotfiles out of ~/ (Claude Code's into
#      ~/.config/claude), adds a login item that gives apps CODEX_HOME and
#      CLAUDE_CONFIG_DIR, and installs the yazi and Neovim (LazyVim) plugins
#   5. Links ~/.ssh to the "dot-ssh" folder in OneDrive
#   6. Links ~/.config/codex (Codex's settings and memory, found through
#      $CODEX_HOME) to the "codex" folder in OneDrive, creating it there if it
#      doesn't exist
#   7. Git identity, GitHub login and SSH keys on GitHub
#   8. macOS settings (macos/settings.sh)
#   9. Turns off Siri, suggestions, ads and Game Center and their background
#      agents (macos/debloat.sh)
#  10. Moves the removable Apple apps (GarageBand, iMovie, Keynote, Numbers,
#      Pages) and GarageBand's sound library to the Trash, after asking
#  11. Applies the theme (bin/theme; Nord unless you picked another)
#
# Safe to run again: anything already done is skipped. Anything replaced is
# moved (never deleted) to $XDG_STATE_HOME/dotfiles/backup/<timestamp>/
# (~/.local/state/dotfiles/backup/<timestamp>/).
#
# Environment overrides:
#   ONEDRIVE_SSH_DIR     name of the ssh folder inside OneDrive (default: dot-ssh)
#   ONEDRIVE_CODEX_DIR   name of the Codex folder inside OneDrive (default: codex)
#   DOTFILES_SKIP        space-separated steps to skip:
#                        onedrive brew ssh codex github macos debloat trash theme

set -uo pipefail
export HOMEBREW_NO_ENV_HINTS=1

# clt: install Apple's Command Line Tools (git, compilers) if missing, and wait
# for them. macOS shows an install window; click Install there.
clt() {
  xcode-select -p >/dev/null 2>&1 && return 0
  printf '    Installing the Command Line Tools (git and compilers): click Install in the window that opens.\n'
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  printf '    Command Line Tools installed.\n'
}

# Bootstrap. Run without a clone of the repo (curl … | bash) or from a copy that
# isn't a git clone (a downloaded zip): install the Command Line Tools, clone
# the repo to ~/Developer/dotfiles, and start again from there.
REPO_URL="https://github.com/gmarques-x/dotfiles.git"
# Piped into bash, the script has no file of its own (BASH_SOURCE is empty).
HERE=""
[ -n "${BASH_SOURCE[0]:-}" ] && HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [ -z "$HERE" ] || [ ! -f "$HERE/Brewfile" ] || [ ! -e "$HERE/.git" ]; then
  DEST="$HOME/Developer/dotfiles"
  printf 'dotfiles: getting the repo into %s\n' "$DEST"
  clt
  if [ -e "$DEST/.git" ]; then
    git -C "$DEST" pull --ff-only --quiet || printf '    ! could not update %s; using it as it is\n' "$DEST"
  else
    mkdir -p "$HOME/Developer"
    git clone --quiet "$REPO_URL" "$DEST" || { printf 'Could not clone %s\n' "$REPO_URL" >&2; exit 1; }
  fi
  if (: </dev/tty) 2>/dev/null; then exec bash "$DEST/install.sh" "$@" </dev/tty; fi
  exec bash "$DEST/install.sh" "$@"
fi

DOTFILES="$HERE"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
XSTATE="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE="$XSTATE/dotfiles"
BACKUP="$STATE/backup/$(date +%Y%m%d-%H%M%S)"
CLOUD="$HOME/Library/CloudStorage"
SSH_DIR_NAME="${ONEDRIVE_SSH_DIR:-dot-ssh}"
CODEX_DIR_NAME="${ONEDRIVE_CODEX_DIR:-codex}"
SKIP=" ${DOTFILES_SKIP:-} "

# ---------------------------------------------------------------- helpers

if [ -t 1 ]; then
  B=$'\033[1m' DIM=$'\033[2m' G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' N=$'\033[0m'
else
  B="" DIM="" G="" Y="" R="" C="" N=""
fi

# The sections, in order. Before each one the whole list is shown: ✓ done,
# ! done with warnings, – skipped, ▸ running now, ○ still to come.
STEPS=("Command Line Tools and Homebrew" "OneDrive" "Apps and command-line tools" "Folders and configs"
       "~/.ssh in OneDrive" "Codex's folder in OneDrive" "Git and GitHub" "macOS settings"
       "Siri, suggestions and ads off" "Remove Apple apps" "Theme")
STATUS=() CUR=-1 STEP_WARN=0 STEP_SKIP=0
close_step() {
  [ "$CUR" -ge 0 ] && [ "$CUR" -lt "${#STEPS[@]}" ] || return 0
  if [ "$STEP_SKIP" = 1 ]; then STATUS[$CUR]=skip
  elif [ "$STEP_WARN" = 1 ]; then STATUS[$CUR]=warn
  else STATUS[$CUR]=done; fi
}
checklist() {
  local i line
  for i in "${!STEPS[@]}"; do
    case "${STATUS[$i]:-}" in
      done) line="${G}✓$N ${STEPS[$i]}" ;;
      warn) line="$Y!$N ${STEPS[$i]} ${DIM}(see the warnings above)$N" ;;
      skip) line="${DIM}– ${STEPS[$i]} (skipped)$N" ;;
      fail) line="${R}✗ ${STEPS[$i]}$N" ;;
      *) if [ "$i" -eq "$CUR" ]; then line="$B${C}▸ ${STEPS[$i]}$N"; else line="${DIM}○ ${STEPS[$i]}$N"; fi ;;
    esac
    printf '    %s\n' "$line"
  done
}
step() {
  close_step
  CUR=$((CUR + 1)) STEP_WARN=0 STEP_SKIP=0
  printf '\n'
  checklist
  printf '\n%s==> [%d/%d] %s%s\n' "$B$C" "$((CUR + 1))" "${#STEPS[@]}" "$1" "$N"
}
finish() {
  close_step
  CUR=${#STEPS[@]}
  printf '\n%s==> Done%s\n' "$B$C" "$N"
  checklist
  printf '\n'
}
info() { printf '    %s\n' "$1"; }
ok()   { printf '    %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '    %s!%s %s\n' "$Y" "$N" "$1"; STEP_WARN=1; }
skipped() { printf '    %s– skipped (DOTFILES_SKIP)%s\n' "$DIM" "$N"; STEP_SKIP=1; }
die()  {
  printf '\n%s✗ %s%s\n' "$R" "$1" "$N" >&2
  if [ "$CUR" -ge 0 ] && [ "$CUR" -lt "${#STEPS[@]}" ]; then STATUS[$CUR]=fail; printf '\n' >&2; checklist >&2; fi
  exit 1
}
pretty() { printf '%s' "${1/#"$HOME"/\~}"; }
skip() { case "$SKIP" in *" $1 "*) return 0 ;; esac; return 1; }

# ask PROMPT [DEFAULT]: read an answer from the terminal (works under curl | bash).
ask() {
  local prompt="$1" def="${2-}" ans
  if [ -n "$def" ]; then
    printf '    %s %s[%s]%s: ' "$prompt" "$DIM" "$def" "$N" >/dev/tty
  else
    printf '    %s: ' "$prompt" >/dev/tty
  fi
  IFS= read -r ans </dev/tty || ans=""
  printf '%s' "${ans:-$def}"
}

pause() {
  printf '\n    %s%s%s ' "$B" "$1" "$N" >/dev/tty
  IFS= read -r REPLY </dev/tty || REPLY=""
}

# backup PATH: move PATH into this run's backup folder, keeping its place under $HOME.
backup() {
  local src="$1" rel dest
  rel="${src#"$HOME"/}"
  dest="$BACKUP/$rel"
  mkdir -p "$(dirname "$dest")" || return 1
  mv "$src" "$dest" || return 1
  info "${DIM}backed up ~/$rel → $(pretty "$dest")${N}"
}

# link SRC DEST: make DEST a symlink to SRC, backing up whatever was there.
link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "$(pretty "$dest")"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup "$dest" || die "could not back up $dest"
  fi
  ln -s "$src" "$dest" || die "could not link $dest"
  ok "$(pretty "$dest") → $(pretty "$src")"
}

onedrive_folders() {
  local d
  for d in "$CLOUD"/OneDrive*; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

# pick_onedrive: set OD to the OneDrive folder to use, asking once if there are
# several. Returns 1 (OD empty) when there is none.
OD=""
pick_onedrive() {
  [ -n "$OD" ] && return 0
  local folders count i n d
  folders="$(onedrive_folders)"
  count="$(printf '%s' "$folders" | grep -c . || true)"
  [ "$count" -eq 0 ] && return 1
  if [ "$count" -eq 1 ]; then
    OD="$folders"
  else
    info "More than one OneDrive folder:"
    i=0
    while IFS= read -r d; do i=$((i + 1)); info "  $i  $(pretty "$d")"; done <<<"$folders"
    n="$(ask "Which one holds your $SSH_DIR_NAME and $CODEX_DIR_NAME folders?" 1)"
    OD="$(sed -n "${n}p" <<<"$folders")"
    [ -n "$OD" ] || die "not a choice: $n"
  fi
}

# link_to_onedrive DEST FOLDER: make DEST (a full path) a symlink to OneDrive/FOLDER.
# Files only on this Mac are copied across (never overwriting OneDrive's), and
# the old DEST goes to the backup.
link_to_onedrive() {
  local home="$1" target="$OD/$2" shown
  shown="$(pretty "$home")"
  if [ ! -d "$target" ]; then
    warn "$(pretty "$target") doesn't exist yet; creating it"
    mkdir -p "$target" || die "could not create $target"
  fi
  # Make sure the files are downloaded, not just placeholders.
  find "$target" -type f -exec cat {} + >/dev/null 2>&1 || true
  mkdir -p "$(dirname "$home")"
  if [ -d "$home" ] && [ ! -L "$home" ]; then
    cp -Rn "$home/." "$target/" 2>/dev/null \
      || info "files OneDrive already had were kept; the old $shown is in the backup"
    backup "$home" || die "could not back up $shown"
  elif [ -L "$home" ]; then
    backup "$home" || die "could not move the old $shown link"
  fi
  ln -s "$target" "$home" || die "could not link $shown"
  ok "$shown → $(pretty "$target")"
  info "${DIM}Tip: in Finder, right-click that folder › Always Keep on This Device.${N}"
}

# ---------------------------------------------------------------- preflight

[ "$(uname -s)" = "Darwin" ] || die "this installer is for macOS"
[ "$(id -u)" -ne 0 ] || die "run this as yourself, not with sudo"

printf '%sdotfiles%s  %s\n' "$B" "$N" "$(pretty "$DOTFILES")"

# ---------------------------------------------------------------- 1. Homebrew

step "Command Line Tools and Homebrew"
clt
ok "Command Line Tools"
if [ -x /opt/homebrew/bin/brew ]; then
  BREW=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW=/usr/local/bin/brew
else
  BREW=""
fi
if [ -n "$BREW" ]; then
  ok "already installed"
else
  info "Installing Homebrew (it asks for your Mac password and installs the Command Line Tools)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty \
    || die "Homebrew install failed"
  if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew; else BREW=/usr/local/bin/brew; fi
  ok "installed"
fi
eval "$("$BREW" shellenv)"

# ---------------------------------------------------------------- 2. OneDrive

step "OneDrive"
if skip onedrive; then
  skipped
else
  if [ -d /Applications/OneDrive.app ]; then
    ok "already installed"
  else
    "$BREW" install --cask onedrive || die "could not install OneDrive"
    ok "installed"
  fi
  if [ -n "$(onedrive_folders)" ] && [ -f "$STATE/onedrive-done" ]; then
    ok "already set up"
  else
    open -a OneDrive || warn "could not open OneDrive; open it from Applications"
    info "OneDrive is opening. In its wizard:"
    info "  • sign in"
    info "  • let your OneDrive folder finish syncing (your $SSH_DIR_NAME folder must be downloaded)"
    info "  • optionally turn on Desktop and Documents backup"
    while :; do
      pause "Press Return when the OneDrive wizard is finished (or type skip):"
      case "$REPLY" in skip|SKIP|Skip) warn "skipped; ~/.ssh will not be linked"; break ;; esac
      if [ -n "$(onedrive_folders)" ]; then
        mkdir -p "$STATE" && date +%F > "$STATE/onedrive-done"
        ok "OneDrive folder found: $(onedrive_folders | head -1 | sed "s|$HOME|~|")"
        break
      fi
      warn "no OneDrive folder in ~/Library/CloudStorage yet; give it a moment"
    done
  fi
fi

# ---------------------------------------------------------------- 3. Apps and tools

step "Apps and command-line tools"
# pick_apps: show Brewfile.apps as a list to mark with space; print the chosen casks.
# The first time nothing is marked; after that, the last choice is.
APPS_CHOICE="$STATE/apps"
pick_apps() {
  local lines name desc i=0 binds="start:"
  lines="$(sed -n 's/^cask "\([^"]*\)" *# *\(.*\)$/\1	\2/p' "$DOTFILES/Brewfile.apps")"
  while IFS=$'\t' read -r name desc; do
    i=$((i + 1))
    if [ -f "$APPS_CHOICE" ] && grep -qx "$name" "$APPS_CHOICE"; then binds="${binds}pos($i)+toggle+"; fi
  done <<<"$lines"
  printf '%s\n' "$lines" | fzf --multi --no-sort --cycle --layout reverse --height '~100%' \
    --delimiter '\t' --with-nth 2 --prompt '  apps ❯ ' --marker '✓' --pointer '▸' \
    --header $'  space: mark or unmark · ctrl-a: mark all · return: install the marked ones\n' \
    --bind 'space:toggle+down' --bind 'ctrl-a:select-all' --bind "${binds}first" \
    --bind 'enter:become([ "$FZF_SELECT_COUNT" -gt 0 ] && cat {+f} || true)' \
    | cut -f1
}
if skip brew; then
  skipped
else
  info "Command-line tools and fonts (Brewfile)"
  if "$BREW" bundle check --file="$DOTFILES/Brewfile" >/dev/null 2>&1; then
    ok "everything installed"
  elif "$BREW" bundle --file="$DOTFILES/Brewfile"; then
    ok "installed"
  else
    # One item failing shouldn't stop the rest of the setup.
    warn "some of the Brewfile didn't install (see above); run install.sh again later to retry"
  fi

  info "Apps (Brewfile.apps)"
  if [ -z "${DOTFILES_NONINTERACTIVE:-}" ] && command -v fzf >/dev/null && [ -r /dev/tty ]; then
    if chosen="$(pick_apps)"; then
      mkdir -p "$STATE" && printf '%s\n' "$chosen" > "$APPS_CHOICE"
    else
      # Esc: the previous choice, or none the first time
      chosen="$(cat "$APPS_CHOICE" 2>/dev/null || true)"
      info "${DIM}kept the previous choice${N}"
    fi
  else
    # No questions (dots-sync): the saved choice, or no apps
    chosen="$(cat "$APPS_CHOICE" 2>/dev/null || true)"
  fi
  has_app() { printf '%s\n' "$chosen" | grep -qx "$1"; }

  if [ -z "$(printf '%s' "$chosen" | tr -d '[:space:]')" ]; then
    ok "no apps chosen"
  else
    # Steam is an Intel app: on Apple silicon it needs Rosetta.
    if has_app steam && [ "$(uname -m)" = arm64 ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
      info "Installing Rosetta, for Steam (it may ask for your Mac password)."
      sudo softwareupdate --install-rosetta --agree-to-license >/dev/null \
        && ok "Rosetta installed" || warn "could not install Rosetta; Steam won't open without it"
    fi
    # An app installed outside Homebrew (dragged in, or from its own installer)
    # makes `brew install --cask` fail, so those are left as they are.
    apps_brewfile="$STATE/Brewfile.apps.chosen"
    mkdir -p "$STATE"; : > "$apps_brewfile"
    while IFS= read -r cask; do
      [ -n "$cask" ] || continue
      app="$("$BREW" info --cask --json=v2 "$cask" 2>/dev/null | jq -r \
        '[.casks[0].artifacts[] | objects | .app? // empty | .[] | strings | select(endswith(".app"))][0] // empty' 2>/dev/null)"
      if [ -n "$app" ] && [ -d "/Applications/$app" ] && ! "$BREW" list --cask "$cask" >/dev/null 2>&1; then
        info "${DIM}${app%.app} is already installed outside Homebrew; leaving it as it is${N}"
        continue
      fi
      grep "^cask \"$cask\"" "$DOTFILES/Brewfile.apps" >> "$apps_brewfile"
    done <<<"$chosen"
    if [ ! -s "$apps_brewfile" ] || "$BREW" bundle check --file="$apps_brewfile" >/dev/null 2>&1; then
      ok "the chosen apps are installed"
    elif "$BREW" bundle --file="$apps_brewfile"; then
      ok "installed the chosen apps"
    else
      warn "some apps didn't install (see above); run install.sh again later to retry"
    fi
  fi

  # Chrome as the default browser (macOS asks you to confirm, once).
  if has_app google-chrome && [ -d "/Applications/Google Chrome.app" ] && command -v defaultbrowser >/dev/null; then
    if defaultbrowser 2>/dev/null | grep -q '^\* chrome$'; then
      ok "Chrome is the default browser"
    else
      defaultbrowser chrome >/dev/null 2>&1 && info "Choose \"Use Chrome\" in the dialog to make it the default browser." \
        || warn "could not make Chrome the default browser"
    fi
  fi
fi

# ---------------------------------------------------------------- 4. Folders and configs

step "Folders and configs"
# The XDG folders, ~/.local/bin (where the XDG spec puts user programs) and ~/Developer.
mkdir -p "$CONFIG" "$CACHE" "$DATA" "$XSTATE" "$HOME/.local/bin" "$HOME/Developer"
touch "$HOME/.hushlogin"   # no "Last login" line at the top of new terminals
ok "~/Developer and the XDG folders ($(pretty "$CONFIG"), $(pretty "$CACHE"), $(pretty "$DATA"), $(pretty "$XSTATE"))"
link "$DOTFILES/zsh/.zshenv"  "$HOME/.zshenv"
for tool in zsh ghostty starship eza bat yazi git fastfetch atuin htop glow lazygit nvim vim wget; do
  link "$DOTFILES/$tool" "$CONFIG/$tool"
done
link "$DOTFILES/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
link "$DOTFILES/bin/theme"     "$HOME/.local/bin/theme"
link "$DOTFILES/bin/dots-sync" "$HOME/.local/bin/dots-sync"
# Earlier versions linked the two starship files on their own; they now live in ~/.config/starship.
for f in starship.toml starship-plain.toml; do
  if [ -L "$CONFIG/$f" ]; then backup "$CONFIG/$f"; fi
done
# atuin looks for themes in its data folder; `theme` writes them into atuin/themes.
mkdir -p "$DOTFILES/atuin/themes" "$DATA/atuin"
link "$DOTFILES/atuin/themes" "$DATA/atuin/themes"
# VS Code's "Home" workspace (drag it into the Dock to open VS Code on your home folder).
mkdir -p "$CONFIG/vscode"
printf '{\n  "folders": [{ "name": "Home", "path": "%s" }],\n  "settings": {}\n}\n' "$HOME" > "$CONFIG/vscode/home.code-workspace"

# zsh reads ~/.zprofile and ~/.zshrc only without ZDOTDIR; ours live in ~/.config/zsh.
for f in .zprofile .zshrc .zlogin; do
  if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then backup "$HOME/$f"; fi
done
# Ghostty prefers this file over ~/.config/ghostty/config when it exists.
GHOSTTY_APP_SUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [ -f "$GHOSTTY_APP_SUPPORT" ] && [ ! -L "$GHOSTTY_APP_SUPPORT" ]; then backup "$GHOSTTY_APP_SUPPORT"; fi
mkdir -p "$XSTATE/zsh" "$XSTATE/less" "$XSTATE/python" "$XSTATE/vim" "$CACHE/zsh"
# Dotfiles zsh and less used to leave in ~/ : move them to their XDG places.
if [ -f "$HOME/.zsh_history" ] && [ ! -e "$XSTATE/zsh/history" ]; then
  mv "$HOME/.zsh_history" "$XSTATE/zsh/history" && ok "moved ~/.zsh_history → $(pretty "$XSTATE/zsh/history")"
fi
# vim (now ~/.config/vim), atuin (~/.local/share/atuin) and wget (~/.cache/wget-hsts) too.
for f in .zsh_history .zsh_sessions .zcompdump* .lesshst .python_history .vimrc .vim .viminfo .wget-hsts .atuin; do
  for p in "$HOME"/$f; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    backup "$p"
  done
done

# Claude Code keeps its settings in ~/.config/claude (CLAUDE_CONFIG_DIR, set in
# zsh/.zshenv) instead of ~/.claude and ~/.claude.json. Anything already in those
# is copied across (never overwriting), and the old ones go to the backup. A link
# from an older setup (to OneDrive, say) is only removed; what it points to stays.
CLAUDE_DIR="$CONFIG/claude"
mkdir -p "$CLAUDE_DIR"
if [ -d "$HOME/.claude" ]; then
  cp -Rn "$HOME/.claude/." "$CLAUDE_DIR/" 2>/dev/null || true
  backup "$HOME/.claude" && ok "moved ~/.claude into $(pretty "$CLAUDE_DIR")"
elif [ -L "$HOME/.claude" ]; then
  backup "$HOME/.claude"
fi
if [ -f "$HOME/.claude.json" ]; then
  [ -e "$CLAUDE_DIR/.claude.json" ] || cp "$HOME/.claude.json" "$CLAUDE_DIR/.claude.json"
  backup "$HOME/.claude.json" && ok "moved ~/.claude.json into $(pretty "$CLAUDE_DIR")"
fi

# The tools' own downloads, with the same folders zsh gives them (zsh/.zshenv).
export XDG_CONFIG_HOME="$CONFIG" XDG_CACHE_HOME="$CACHE" XDG_DATA_HOME="$DATA" XDG_STATE_HOME="$XSTATE"
export ATUIN_HOME="$DATA/atuin"
# atuin: start its history from zsh's, once.
if command -v atuin >/dev/null && [ ! -e "$ATUIN_HOME/data/history.db" ] && [ -s "$XSTATE/zsh/history" ]; then
  HISTFILE="$XSTATE/zsh/history" atuin import zsh >/dev/null 2>&1 \
    && ok "atuin: imported your zsh history" || warn "atuin could not import the zsh history"
fi
# yazi: its plugins and flavors, as listed in yazi/package.toml.
if command -v ya >/dev/null; then
  ya pkg install >/dev/null 2>&1 && ok "yazi plugins" || warn "could not install the yazi plugins (ya pkg install)"
fi
# Neovim: LazyVim and its plugins (otherwise they download on the first start).
if command -v nvim >/dev/null; then
  info "Installing Neovim's plugins (LazyVim); this takes a minute the first time."
  nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 && ok "Neovim plugins" \
    || warn "Neovim's plugins didn't all install; they finish on its first start"
fi

# ---------------------------------------------------------------- 5. ~/.ssh → OneDrive

step "~/.ssh → OneDrive/$SSH_DIR_NAME"
if skip ssh; then
  skipped
else
  if [ -L "$HOME/.ssh" ] && [ -d "$HOME/.ssh" ] && [ "$(basename "$(readlink "$HOME/.ssh")")" = "$SSH_DIR_NAME" ]; then
    ok "already linked → $(readlink "$HOME/.ssh" | sed "s|$HOME|~|")"
  elif ! pick_onedrive; then
    warn "no OneDrive folder found; ~/.ssh stays on this Mac (run again after OneDrive syncs)"
  else
    link_to_onedrive "$HOME/.ssh" "$SSH_DIR_NAME"
  fi

  [ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"
  chmod 700 "$HOME/.ssh/" 2>/dev/null || true
  if [ ! -f "$HOME/.ssh/config" ]; then
    if cp "$DOTFILES/ssh/config" "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"; then
      ok "added ssh config"
    else
      warn "could not add the ssh config; copy $(pretty "$DOTFILES/ssh/config") to ~/.ssh/config yourself"
    fi
  else
    ok "ssh config present"
  fi
  mkdir -p "$HOME/.ssh/config.d"
  for k in "$HOME"/.ssh/id_*; do
    [ -f "$k" ] && case "$k" in *.pub) ;; *) chmod 600 "$k" ;; esac
  done
fi

# ---------------------------------------------------------------- 6. Codex → OneDrive

# Codex's settings and memory. Codex looks in $CODEX_HOME (set in zsh/.zshenv to
# $XDG_CONFIG_HOME/codex) instead of ~/.codex. The folder is created in OneDrive
# if it isn't there yet.
CODEX_HOME_DIR="$CONFIG/codex"
step "$(pretty "$CODEX_HOME_DIR") → OneDrive/$CODEX_DIR_NAME"
if skip codex; then
  skipped
elif [ -L "$CODEX_HOME_DIR" ] && [ -d "$CODEX_HOME_DIR" ] && [ "$(basename "$(readlink "$CODEX_HOME_DIR")")" = "$CODEX_DIR_NAME" ]; then
  ok "already linked → $(readlink "$CODEX_HOME_DIR" | sed "s|$HOME|~|")"
elif ! pick_onedrive; then
  warn "no OneDrive folder found; Codex's folder stays on this Mac (run again after OneDrive syncs)"
else
  link_to_onedrive "$CODEX_HOME_DIR" "$CODEX_DIR_NAME"
  info "${DIM}Use this folder from one Mac at a time; it holds live session files.${N}"
fi
# The old place, ~/.codex: bring across what OneDrive doesn't have, then back it up.
# Without OneDrive the folder is still created, since Codex won't start if
# CODEX_HOME points at nothing.
if ! skip codex; then
  mkdir -p "$CODEX_HOME_DIR"
  if [ -d "$HOME/.codex" ] && [ ! -L "$HOME/.codex" ]; then
    cp -Rn "$HOME/.codex/." "$CODEX_HOME_DIR/" 2>/dev/null || true
    backup "$HOME/.codex" && ok "moved ~/.codex into $(pretty "$CODEX_HOME_DIR")"
  elif [ -L "$HOME/.codex" ]; then
    backup "$HOME/.codex"
  fi
fi

# Apps opened from the Dock or Finder (ChatGPT, Claude, VS Code) don't read zsh's
# files, so a login item sets CODEX_HOME and CLAUDE_CONFIG_DIR for the whole
# session at each login.
CODEX_DB_DIR="$XSTATE/codex/sqlite"
AGENT_LABEL="local.dotfiles.environment"
AGENT="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
mkdir -p "${AGENT%/*}"
OLD_AGENT="$HOME/Library/LaunchAgents/local.dotfiles.codex-home.plist"   # earlier versions: Codex only
if [ -f "$OLD_AGENT" ]; then
  launchctl bootout "gui/$(id -u)/local.dotfiles.codex-home" 2>/dev/null || true
  rm -f "$OLD_AGENT"
fi
CODEX_MIGRATION=""
if ! skip codex || [ -f "$CODEX_DB_DIR/.migration-complete" ]; then
  CODEX_MIGRATION="; /usr/bin/python3 \"$DOTFILES/bin/codex-sqlite-home.py\" \"$CODEX_HOME_DIR\" \"$CODEX_DB_DIR\" &amp;&amp; /bin/launchctl setenv CODEX_SQLITE_HOME \"$CODEX_DB_DIR\""
fi
cat > "$AGENT.tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/bin/launchctl setenv CODEX_HOME "$CODEX_HOME_DIR"; /bin/launchctl setenv CLAUDE_CONFIG_DIR "$CLAUDE_DIR"$CODEX_MIGRATION</string>
  </array>
  <key>KeepAlive</key>
  <dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key>
  <integer>15</integer>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
if cmp -s "$AGENT.tmp" "$AGENT"; then
  rm -f "$AGENT.tmp"
  ok "login item sets CODEX_HOME and CLAUDE_CONFIG_DIR for apps"
else
  mv "$AGENT.tmp" "$AGENT"
  launchctl bootout "gui/$(id -u)/$AGENT_LABEL" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null; then
    ok "login item sets CODEX_HOME and CLAUDE_CONFIG_DIR for apps ($(pretty "$AGENT"))"
  else
    warn "could not load $(pretty "$AGENT"); it takes effect at the next login"
  fi
fi
# Now as well, for apps opened from here on (already open ones need a restart).
launchctl setenv CODEX_HOME "$CODEX_HOME_DIR" 2>/dev/null || true
launchctl setenv CLAUDE_CONFIG_DIR "$CLAUDE_DIR" 2>/dev/null || true

# ---------------------------------------------------------------- 7. Git & GitHub

step "Git & GitHub"
if skip github; then
  skipped
else
  LOCAL="$DOTFILES/git/local"
  cur_name="$(git config -f "$LOCAL" user.name 2>/dev/null || true)"
  cur_email="$(git config -f "$LOCAL" user.email 2>/dev/null || true)"
  NAME="$(ask "Your name for git commits" "$cur_name")"
  EMAIL="$(ask "Your email for git commits" "$cur_email")"
  [ -n "$NAME" ] && [ -n "$EMAIL" ] || die "git needs a name and an email"

  # Log in first, so the key choice below can see which keys GitHub already has.
  if gh auth status -h github.com >/dev/null 2>&1; then
    ok "GitHub: already logged in"
    if ! gh auth status -h github.com 2>&1 | grep -q 'admin:ssh_signing_key'; then
      gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key || warn "could not add key scopes"
    fi
  else
    info "Logging in to GitHub in your browser."
    gh auth login --hostname github.com --git-protocol https --web \
      --scopes admin:public_key,admin:ssh_signing_key,workflow </dev/tty \
      || die "gh auth login failed"
  fi
  gh config set git_protocol https -h github.com >/dev/null 2>&1 || true
  keys="$(gh ssh-key list 2>/dev/null || true)"

  # on_github PUBFILE TYPE: is this public key on GitHub as TYPE (authentication/signing)?
  on_github() {
    local t b
    read -r t b _ < "$1" || return 1
    printf '%s\n' "$keys" | awk -F '\t' -v k="$t $b" -v t="$2" \
      '{ split($2, a, " "); if (a[1] " " a[2] == k && $5 == t) f = 1 } END { exit !f }'
  }

  # Use the key you already have: ~/.ssh/id_ed25519, or else any key in ~/.ssh
  # that GitHub already knows for logging in. Only create one when there is none.
  KEY=""
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    KEY="$HOME/.ssh/id_ed25519"
    if [ ! -f "$KEY.pub" ]; then
      info "Recreating $(pretty "$KEY.pub") from the private key (it may ask for the passphrase)."
      ssh-keygen -y -f "$KEY" > "$KEY.pub" </dev/tty || die "could not read $KEY"
    fi
  else
    for pub in "$HOME"/.ssh/*.pub; do
      [ -f "$pub" ] && [ -f "${pub%.pub}" ] || continue
      if on_github "$pub" authentication; then KEY="${pub%.pub}"; break; fi
    done
  fi
  if [ -n "$KEY" ]; then
    ok "using your existing SSH key $(pretty "$KEY")"
  else
    if [ ! -L "$HOME/.ssh" ]; then
      warn "~/.ssh isn't linked to OneDrive/$SSH_DIR_NAME, so a key you already have may not be here."
      case "$(ask "Create a new SSH key anyway? [y/N]")" in
        [Yy]*) ;;
        *) die "run install.sh again once OneDrive has synced your $SSH_DIR_NAME folder" ;;
      esac
    fi
    KEY="$HOME/.ssh/id_ed25519"
    info "No SSH key yet; creating $(pretty "$KEY") (choose a passphrase)."
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" </dev/tty || die "ssh-keygen failed"
  fi
  # ~/.ssh/config offers id_ed25519; point github.com at any other key.
  if [ "$KEY" != "$HOME/.ssh/id_ed25519" ]; then
    mkdir -p "$HOME/.ssh/config.d"
    printf 'Host github.com\n    IdentityFile %s\n    IdentitiesOnly yes\n' "$KEY" > "$HOME/.ssh/config.d/github"
    ok "github.com uses $(pretty "$KEY") (~/.ssh/config.d/github)"
  fi
  ssh-add --apple-use-keychain "$KEY" </dev/tty 2>/dev/null && ok "key in the agent and Keychain" \
    || warn "could not add the key to the agent; ssh will ask for it on first use"

  {
    printf '[user]\n'
    printf '    name = "%s"\n' "${NAME//\"/\\\"}"
    printf '    email = "%s"\n' "${EMAIL//\"/\\\"}"
    printf '    signingkey = %s\n' "$KEY.pub"
  } > "$LOCAL"
  read -r ktype kbody _ < "$KEY.pub"
  printf '%s %s %s\n' "$EMAIL" "$ktype" "$kbody" > "$DOTFILES/git/allowed_signers"
  if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then backup "$HOME/.gitconfig"; fi
  ok "git identity: $NAME <$EMAIL>, commits signed with your SSH key"

  title="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
  for type in authentication signing; do
    if on_github "$KEY.pub" "$type"; then
      ok "SSH key on GitHub ($type)"
    else
      gh ssh-key add "$KEY.pub" --type "$type" --title "$title" >/dev/null \
        && ok "uploaded SSH key to GitHub ($type)" \
        || warn "could not upload the SSH key ($type)"
    fi
  done
fi

# ---------------------------------------------------------------- 8. macOS settings

step "macOS settings (Desktop & Dock, Finder, Keyboard, Trackpad, screenshots, ...)"
if skip macos; then
  skipped
else
  if "$DOTFILES/macos/settings.sh"; then
    ok "applied (some need a log out to take full effect)"
  else
    warn "applied, except the ones above (some need a log out to take full effect)"
  fi
fi

# ---------------------------------------------------------------- 9. Debloat

step "Turn off Siri, suggestions, personalised ads and Game Center"
if skip debloat; then
  skipped
elif "$DOTFILES/macos/debloat.sh"; then
  ok "done (the background agents stop at your next login)"
else
  warn "done, except the ones above"
fi

# Only the Apple apps installed from the App Store can go. Safari, Mail, Music,
# Photos, News, Stocks and the rest live on the sealed, read-only system
# volume, and macOS puts them back if that is ever changed.
step "Remove Apple apps (GarageBand, iMovie, Keynote, Numbers, Pages)"

# trash PATH: move PATH to the Trash (asking for the admin password if needed).
trash() {
  local src="$1" dest="$HOME/.Trash/${1##*/}"
  [ -e "$dest" ] && dest="$dest $(date +%H%M%S)"
  mv "$src" "$dest" 2>/dev/null || sudo mv "$src" "$dest"
}

if skip trash; then
  skipped
else
  found=()
  for app in GarageBand iMovie Keynote Numbers Pages; do
    [ -d "/Applications/$app.app" ] && found+=("/Applications/$app.app")
  done
  # GarageBand's instruments and loops (several GB), unless Logic Pro still uses them.
  if [ -d "/Applications/GarageBand.app" ] && [ ! -d "/Applications/Logic Pro.app" ]; then
    for dir in "/Library/Application Support/GarageBand" "/Library/Application Support/Logic" \
               "/Library/Audio/Apple Loops" "/Library/Audio/Impulse Responses"; do
      [ -d "$dir" ] && found+=("$dir")
    done
  fi

  if [ "${#found[@]}" -eq 0 ]; then
    ok "none installed"
  else
    for f in "${found[@]}"; do
      info "$f ${DIM}($(du -sh "$f" 2>/dev/null | awk '{print $1}'))${N}"
    done
    case "$(ask "Move these to the Trash? (they can be reinstalled from the App Store) [y/N]")" in
      [Yy]*)
        for f in "${found[@]}"; do
          trash "$f" && ok "moved ${f##*/} to the Trash" || warn "could not move $f (drag it to the Trash in Finder)"
        done
        info "Empty the Trash to free the space."
        ;;
      *) info "kept" ;;
    esac
  fi
fi

# ---------------------------------------------------------------- 11. Theme

step "Theme (colours for every tool, macOS appearance, wallpaper)"
if skip theme; then
  skipped
elif zsh "$DOTFILES/bin/theme" apply; then
  info "${DIM}Change it any time with: theme${N}"
else
  warn "the theme didn't fully apply; run: theme apply"
fi

# ---------------------------------------------------------------- done

finish
[ -d "$BACKUP" ] && info "Replaced files are in $(pretty "$BACKUP")"
if [ "${SHELL##*/}" != "zsh" ]; then
  chsh -s /bin/zsh && ok "default shell set to zsh"
fi
info "Open Ghostty (or run: exec zsh) to start using the new setup."
