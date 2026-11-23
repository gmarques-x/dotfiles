#!/usr/bin/env bash
# dotfiles installer for macOS.
#
#   1. Homebrew
#   2. OneDrive (then waits while you finish its setup wizard)
#   3. Terminal tools and apps from the Brewfile (Ghostty, eza, yazi, starship,
#      Claude, ChatGPT, Gemini and their CLIs, ...)
#   4. Links the configs into ~/.config and ~/.zshenv
#   5. Links ~/.ssh to the "dot-ssh" folder in OneDrive
#   6. Links ~/.claude (Claude Code's settings, skills, memory) to the
#      "claude" folder in OneDrive, and Codex's and Gemini's instruction
#      files (~/.codex/AGENTS.md, ~/.gemini/GEMINI.md) to the copies in it
#   7. Git identity, GitHub login and SSH keys on GitHub
#   8. macOS settings (macos/settings.sh)
#   9. Moves the removable Apple apps (GarageBand, iMovie, Keynote, Numbers,
#      Pages) and GarageBand's sound library to the Trash, after asking
#
# Safe to run again: anything already done is skipped. Anything replaced is
# moved (never deleted) to ~/.local/state/dotfiles/backup/<timestamp>/.
#
# Environment overrides:
#   ONEDRIVE_SSH_DIR     name of the ssh folder inside OneDrive (default: dot-ssh)
#   ONEDRIVE_CLAUDE_DIR  name of the Claude Code folder inside OneDrive (default: claude)
#   DOTFILES_SKIP        space-separated steps to skip: onedrive ssh claude github macos debloat

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$HOME/.local/state/dotfiles"
BACKUP="$STATE/backup/$(date +%Y%m%d-%H%M%S)"
CLOUD="$HOME/Library/CloudStorage"
SSH_DIR_NAME="${ONEDRIVE_SSH_DIR:-dot-ssh}"
CLAUDE_DIR_NAME="${ONEDRIVE_CLAUDE_DIR:-claude}"
SKIP=" ${DOTFILES_SKIP:-} "

# ---------------------------------------------------------------- helpers

if [ -t 1 ]; then
  B=$'\033[1m' DIM=$'\033[2m' G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' N=$'\033[0m'
else
  B="" DIM="" G="" Y="" R="" C="" N=""
fi

step() { printf '\n%s==> %s%s\n' "$B$C" "$1" "$N"; }
info() { printf '    %s\n' "$1"; }
ok()   { printf '    %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '    %s!%s %s\n' "$Y" "$N" "$1"; }
die()  { printf '\n%s✗ %s%s\n' "$R" "$1" "$N" >&2; exit 1; }
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
    n="$(ask "Which one holds your $SSH_DIR_NAME and $CLAUDE_DIR_NAME folders?" 1)"
    OD="$(sed -n "${n}p" <<<"$folders")"
    [ -n "$OD" ] || die "not a choice: $n"
  fi
}

# link_to_onedrive NAME FOLDER: make ~/NAME a symlink to OneDrive/FOLDER.
# Files only on this Mac are copied across (never overwriting OneDrive's), and
# the old ~/NAME goes to the backup.
link_to_onedrive() {
  local name="$1" target="$OD/$2" home="$HOME/$1"
  if [ ! -d "$target" ]; then
    warn "$(pretty "$target") doesn't exist yet; creating it"
    mkdir -p "$target" || die "could not create $target"
  fi
  # Make sure the files are downloaded, not just placeholders.
  find "$target" -type f -exec cat {} + >/dev/null 2>&1 || true
  if [ -d "$home" ] && [ ! -L "$home" ]; then
    cp -Rn "$home/." "$target/" 2>/dev/null \
      || info "files OneDrive already had were kept; the old ~/$name is in the backup"
    backup "$home" || die "could not back up ~/$name"
  elif [ -L "$home" ]; then
    backup "$home" || die "could not move the old ~/$name link"
  fi
  ln -s "$target" "$home" || die "could not link ~/$name"
  ok "~/$name → $(pretty "$target")"
  info "${DIM}Tip: in Finder, right-click that folder › Always Keep on This Device.${N}"
}

# ---------------------------------------------------------------- preflight

[ "$(uname -s)" = "Darwin" ] || die "this installer is for macOS"
[ "$(id -u)" -ne 0 ] || die "run this as yourself, not with sudo"

printf '%sdotfiles%s  %s\n' "$B" "$N" "$(pretty "$DOTFILES")"

# ---------------------------------------------------------------- 1. Homebrew

step "Homebrew"
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
  warn "skipped (DOTFILES_SKIP)"
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

# ---------------------------------------------------------------- 3. Tools

step "Terminal tools and apps (Brewfile)"
# An app installed outside Homebrew (dragged in, or from its own installer)
# makes `brew install --cask` fail, so those casks are skipped and left alone.
skip_casks=""
for pair in claude:Claude chatgpt:ChatGPT google-gemini:Gemini ghostty:Ghostty "google-chrome:Google Chrome"; do
  cask="${pair%%:*}" app="${pair#*:}"
  if [ -d "/Applications/$app.app" ] && ! "$BREW" list --cask "$cask" >/dev/null 2>&1; then
    skip_casks="$skip_casks $cask"
    info "${DIM}$app is already installed outside Homebrew; leaving it as it is${N}"
  fi
done
export HOMEBREW_BUNDLE_CASK_SKIP="${skip_casks# }"
if [ -z "$skip_casks" ] && "$BREW" bundle check --file="$DOTFILES/Brewfile" >/dev/null 2>&1; then
  ok "everything installed"
else
  "$BREW" bundle --file="$DOTFILES/Brewfile" || die "brew bundle failed"
  ok "installed"
fi

# ---------------------------------------------------------------- 4. Configs

step "Configs"
mkdir -p "$CONFIG"
link "$DOTFILES/zsh/.zshenv"                  "$HOME/.zshenv"
link "$DOTFILES/zsh"                          "$CONFIG/zsh"
link "$DOTFILES/ghostty"                      "$CONFIG/ghostty"
link "$DOTFILES/starship/starship.toml"       "$CONFIG/starship.toml"
link "$DOTFILES/starship/starship-plain.toml" "$CONFIG/starship-plain.toml"
link "$DOTFILES/eza"                          "$CONFIG/eza"
link "$DOTFILES/bat"                          "$CONFIG/bat"
link "$DOTFILES/yazi"                         "$CONFIG/yazi"
link "$DOTFILES/git"                          "$CONFIG/git"
link "$DOTFILES/fastfetch"                    "$CONFIG/fastfetch"

# zsh reads ~/.zprofile and ~/.zshrc only without ZDOTDIR; ours live in ~/.config/zsh.
for f in .zprofile .zshrc .zlogin; do
  if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then backup "$HOME/$f"; fi
done
# Ghostty prefers this file over ~/.config/ghostty/config when it exists.
GHOSTTY_APP_SUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if [ -f "$GHOSTTY_APP_SUPPORT" ] && [ ! -L "$GHOSTTY_APP_SUPPORT" ]; then backup "$GHOSTTY_APP_SUPPORT"; fi
mkdir -p "$HOME/.local/state/zsh" "$HOME/.cache/zsh"

# ---------------------------------------------------------------- 5. ~/.ssh → OneDrive

step "~/.ssh → OneDrive/$SSH_DIR_NAME"
if skip ssh; then
  warn "skipped (DOTFILES_SKIP)"
else
  if [ -L "$HOME/.ssh" ] && [ -d "$HOME/.ssh" ] && [ "$(basename "$(readlink "$HOME/.ssh")")" = "$SSH_DIR_NAME" ]; then
    ok "already linked → $(readlink "$HOME/.ssh" | sed "s|$HOME|~|")"
  elif ! pick_onedrive; then
    warn "no OneDrive folder found; ~/.ssh stays on this Mac (run again after OneDrive syncs)"
  else
    link_to_onedrive .ssh "$SSH_DIR_NAME"
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

# ---------------------------------------------------------------- 6. ~/.claude → OneDrive

# Claude Code's settings, CLAUDE.md, skills and memory. ~/.claude.json (app
# state and caches, rewritten on every launch) stays on this Mac on purpose.
step "~/.claude → OneDrive/$CLAUDE_DIR_NAME"
if skip claude; then
  warn "skipped (DOTFILES_SKIP)"
elif [ -L "$HOME/.claude" ] && [ -d "$HOME/.claude" ] && [ "$(basename "$(readlink "$HOME/.claude")")" = "$CLAUDE_DIR_NAME" ]; then
  ok "already linked → $(readlink "$HOME/.claude" | sed "s|$HOME|~|")"
elif ! pick_onedrive; then
  warn "no OneDrive folder found; ~/.claude stays on this Mac (run again after OneDrive syncs)"
else
  link_to_onedrive .claude "$CLAUDE_DIR_NAME"
  info "${DIM}Use this folder from one Mac at a time; it holds live session files.${N}"
fi
# The team's standing instructions for Codex and Gemini live in ~/.claude/team
# (so OneDrive backs them up); each CLI reads them from its own folder.
if ! skip claude; then
  for pair in "codex-AGENTS.md:.codex/AGENTS.md" "gemini-GEMINI.md:.gemini/GEMINI.md"; do
    src="$HOME/.claude/team/teammates/${pair%%:*}"
    if [ -f "$src" ]; then
      link "$src" "$HOME/${pair#*:}"
    else
      warn "$(pretty "$src") not found; ~/${pair#*:} not linked (run again after OneDrive syncs)"
    fi
  done
fi

# ---------------------------------------------------------------- 7. Git & GitHub

step "Git & GitHub"
if skip github; then
  warn "skipped (DOTFILES_SKIP)"
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

step "macOS settings (Appearance, Desktop & Dock, Accessibility, Trackpad)"
if skip macos; then
  warn "skipped (DOTFILES_SKIP)"
else
  if "$DOTFILES/macos/settings.sh"; then
    ok "applied (some need a log out to take full effect)"
  else
    warn "applied, except the ones above (some need a log out to take full effect)"
  fi
fi

# ---------------------------------------------------------------- 9. Debloat

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

if skip debloat; then
  warn "skipped (DOTFILES_SKIP)"
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

# ---------------------------------------------------------------- done

step "Done"
[ -d "$BACKUP" ] && info "Replaced files are in $(pretty "$BACKUP")"
if [ "${SHELL##*/}" != "zsh" ]; then
  chsh -s /bin/zsh && ok "default shell set to zsh"
fi
info "Open Ghostty (or run: exec zsh) to start using the new setup."
