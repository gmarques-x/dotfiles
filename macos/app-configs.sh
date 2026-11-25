#!/usr/bin/env bash
# Sourced by install.sh (step "Folders and configs") and by bin/apply-app-configs:
# seeds a fresh setup with the Thor and Rectangle snapshots (thor/ and rectangle/,
# from $DOTFILES), keeps Thor's live apps.json under $CONFIG/thor, and creates the
# BetterCmdTab config and the VS Code link under $CONFIG. Needs DOTFILES and CONFIG
# plus install.sh's info, ok, warn, backup, pretty (and BACKUP).
#
# Nothing is restarted. Existing settings always win: a snapshot is applied only to
# an installed app that has no settings of its own yet, and nothing is overwritten.
# Test seams: SYSTEM_APPS_DIR (default /Applications; ~/Applications is always
# checked too), DEFAULTS_BIN (default defaults) and PGREP_BIN (default pgrep).

DEFAULTS_BIN="${DEFAULTS_BIN:-defaults}"
PGREP_BIN="${PGREP_BIN:-pgrep}"

# app_installed NAME: NAME.app is in the system or the home Applications folder.
app_installed() {
  [ -d "${SYSTEM_APPS_DIR:-/Applications}/$1.app" ] || [ -d "$HOME/Applications/$1.app" ]
}

# publish_new SRC DEST: copy SRC to DEST only if DEST doesn't exist (a file, a
# symlink even a dangling one, a directory, anything). The copy is finished in a
# temporary sibling and then hard-linked into place with the POSIX `link` utility
# (`command link`, so install.sh's shell function of that name is bypassed; found
# via PATH, normally /bin/link). `link` takes exact paths, never treats DEST as a
# directory to link into, and fails if DEST appeared meanwhile, so a competing
# writer's file or directory is kept untouched. The temporary file is always removed.
# Returns 0 if published, 1 on error, 2 if DEST already exists.
publish_new() {
  local src="$1" dest="$2" tmp rc=0
  [ -e "$dest" ] || [ -L "$dest" ] && return 2
  tmp="$(mktemp "$dest.tmp.XXXXXX")" || return 1
  if cp "$src" "$tmp"; then
    if ! command link "$tmp" "$dest" 2>/dev/null; then
      if [ -e "$dest" ] || [ -L "$dest" ]; then rc=2; else rc=1; fi
    fi
  else
    rc=1
  fi
  rm -f "$tmp"
  return "$rc"
}

# exact_symlink TARGET PATH: create the link at exactly PATH. Unlike `ln -s` it never
# links inside PATH when that is a directory, and it fails if anything is there.
exact_symlink() { python3 -I -c 'import os,sys; os.symlink(sys.argv[1], sys.argv[2])' "$1" "$2" 2>/dev/null; }

# thor_gate: 0 only when pgrep says Thor is closed (exit 1). Running (0) and any
# other result (pgrep missing or failing) defer the change and return 2.
thor_gate() {
  local p=0
  "$PGREP_BIN" -x Thor >/dev/null 2>&1 || p=$?
  case "$p" in
    1) return 0 ;;
    0) info "Thor is running, so its current setup is kept. Quit Thor and run this again to move apps.json to $(pretty "$CONFIG/thor")" ;;
    *) warn "could not tell whether Thor is running, so its current setup is kept" ;;
  esac
  return 2
}

# thor_backup_dest PATH: where install.sh's backup() puts PATH.
thor_backup_dest() { printf '%s/%s' "$BACKUP" "${1#"$HOME"/}"; }

# thor_backup PATH: backup(), but never onto a backup destination that already exists.
thor_backup() {
  local dest
  dest="$(thor_backup_dest "$1")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$(pretty "$dest") already exists, so $(pretty "$1") was not moved"
    return 1
  fi
  backup "$1"
}

# thor_restore SAVED ORIG: put a backed-up item back at ORIG only if ORIG is still
# absent. A new item at ORIG is kept and the backup stays where it is.
thor_restore() {
  local saved="$1" orig="$2"
  [ -n "$saved" ] || return 0
  if [ -e "$orig" ] || [ -L "$orig" ] || [ ! -d "$(dirname "$orig")" ]; then
    warn "$(pretty "$orig") changed meanwhile, so your previous copy stays at $(pretty "$saved")"
    return 1
  fi
  mv "$saved" "$orig" 2>/dev/null || warn "could not put $(pretty "$orig") back, so it stays at $(pretty "$saved")"
}

# thor_config_in_repo: 0 when the physical (symlinks resolved) XDG config base is the
# checkout or inside it, or when that can't be worked out. The base is CONFIG, or its
# nearest existing parent, so an alias into the checkout is caught even before
# CONFIG exists. Relocating Thor there would send live writes into tracked files.
thor_config_in_repo() {
  local p="$CONFIG" base repo
  while [ ! -d "$p" ]; do p="$(dirname "$p")"; done
  base="$(cd -P "$p" 2>/dev/null && pwd -P)" || return 0
  repo="$(cd -P "$DOTFILES" 2>/dev/null && pwd -P)" || return 0
  case "$base/" in "$repo"/*) return 0 ;; esac
  return 1
}

# thor_link_defaults LIVE: expose the tracked menu-bar preference snapshot as
# LIVE/defaults.plist (the path the earlier installer's link gave), unless something
# is already there. It is a snapshot only: Thor reads the preference from macOS defaults.
thor_link_defaults() {
  local live="$1" plist="$DOTFILES/thor/defaults.plist"
  [ -f "$plist" ] || return 0
  [ -e "$live/defaults.plist" ] || [ -L "$live/defaults.plist" ] && return 0
  exact_symlink "$plist" "$live/defaults.plist" || warn "could not link $(pretty "$live/defaults.plist")"
}

# thor_relocate: Thor replaces apps.json by name, so a file link can't work. Its
# real folder, ~/Library/Application Support/Thor, becomes a link to the local
# $CONFIG/thor folder (never into the git checkout, which only seeds it).
# Returns 0 when done, 1 when blocked (the caller then keeps the old behavior)
# and 2 when nothing more may be touched (Thor running or not provably closed,
# container, foreign link). Moves only the exact default folder that holds nothing
# but a plain apps.json, has no sandbox container, with Thor probed closed before
# the first change and again before the folder moves, and no conflicting
# destination. A newly installed Thor build is not inspected beyond that. The old
# installer link ($CONFIG/thor to the checkout) is recognized by comparing it with
# the checkout's thor/ (-ef) and backed up, never followed; any other link is left
# alone. Nothing is deleted. The live copy is staged first and kept on any later
# failure, and a retry resumes when it still matches the native apps.json.
thor_relocate() {
  local seed="$DOTFILES/thor" live="$CONFIG/thor" ndir="$HOME/Library/Application Support/Thor"
  local nentries okl kind src entries lentries saved="" nsaved="" created=0 rc=0
  case "$CONFIG" in
    /*) ;;
    *) warn "XDG_CONFIG_HOME isn't an absolute path; Thor's apps.json stays in $(pretty "$ndir")"; return 1 ;;
  esac
  if thor_config_in_repo; then
    warn "XDG_CONFIG_HOME is, or links into, the dotfiles checkout, so Thor's folder was not changed"; return 2
  fi
  if [ -e "$HOME/Library/Containers/me.alvinzhu.Thor" ] || [ -L "$HOME/Library/Containers/me.alvinzhu.Thor" ]; then
    warn "Thor has a sandbox container here, so nothing in $(pretty "$ndir") was changed"; return 2
  fi
  # Thor's own folder and its apps.json, with every link resolved, must stay out of the checkout.
  if ! outside_checkout "$ndir" || ! outside_checkout "$ndir/apps.json"; then
    warn "Thor's folder or its apps.json lies in or links into the dotfiles checkout, so nothing was changed"; return 2
  fi
  if [ -L "$live" ]; then
    if [ "$live" -ef "$seed" ]; then kind=old
    else warn "$(pretty "$live") links somewhere else; Thor keeps its current setup"; return 1; fi
  elif [ -d "$live" ]; then
    kind=dir
    # A real local folder must hold a plain apps.json (or none), never a link such as one into
    # the checkout. It is kept as it is, native exists or not. (The old installer link is
    # kind=old above and is backed up before anything is published.)
    if [ -e "$live/apps.json" ] || [ -L "$live/apps.json" ]; then
      if [ ! -f "$live/apps.json" ] || [ -L "$live/apps.json" ]; then
        warn "$(pretty "$live/apps.json") isn't a plain file, so nothing was changed"; return 2
      fi
    fi
  elif [ -e "$live" ]; then warn "$(pretty "$live") isn't a folder; Thor keeps its current setup"; return 1
  else kind=none; fi

  src="$seed/apps.json"
  if [ -L "$ndir" ]; then
    if [ "$kind" = dir ] && [ "$(readlink "$ndir")" = "$live" ]; then
      if [ ! -e "$live/apps.json" ] && [ ! -L "$live/apps.json" ]; then
        publish_new "$src" "$live/apps.json" || rc=$?
        if [ "$rc" = 1 ]; then
          warn "$(pretty "$ndir") links to $(pretty "$live") but apps.json is missing there and could not be restored"
          return 2
        fi
      fi
      thor_link_defaults "$live"
      ok "Thor's apps.json lives in $(pretty "$live")"
      return 0
    fi
    warn "$(pretty "$ndir") is a link these dotfiles didn't make; left alone"
    return 2
  fi
  if [ -e "$ndir" ]; then
    [ -d "$ndir" ] || { warn "$(pretty "$ndir") isn't a folder; left alone"; return 2; }
    entries="$(ls -A "$ndir")" || { warn "could not read $(pretty "$ndir"); Thor keeps its current setup"; return 1; }
    case "$entries" in
      "") ;;
      apps.json)
        if [ -f "$ndir/apps.json" ] && [ ! -L "$ndir/apps.json" ]; then src="$ndir/apps.json"
        else warn "$(pretty "$ndir/apps.json") isn't a plain file; Thor keeps its current setup"; return 1; fi ;;
      *) warn "$(pretty "$ndir") holds other files; Thor keeps its current setup"; return 1 ;;
    esac
    if [ "$kind" = dir ]; then
      lentries="$(ls -A "$live")" || { warn "could not read $(pretty "$live"); Thor keeps its current setup"; return 1; }
      if [ -z "$lentries" ]; then kind=emptydir
      elif [ "$lentries" = apps.json ] && [ -f "$live/apps.json" ] && [ ! -L "$live/apps.json" ] && cmp -s "$src" "$live/apps.json"; then
        kind=staged   # an earlier run staged this copy and stopped
      else
        warn "$(pretty "$ndir") and $(pretty "$live") both have different content; Thor keeps its current setup"; return 1
      fi
    fi
  fi
  thor_gate || return 2

  if [ "$kind" = old ]; then
    saved="$(thor_backup_dest "$live")"
    thor_backup "$live" || { warn "could not back up the link at $(pretty "$live"); Thor keeps its current setup"; return 1; }
  fi
  if [ "$kind" = emptydir ]; then
    rmdir "$live" 2>/dev/null || { warn "could not replace the empty $(pretty "$live"); Thor keeps its current setup"; return 1; }
    kind=none
  fi
  if [ "$kind" = old ] || [ "$kind" = none ]; then
    if ! mkdir "$live" 2>/dev/null; then
      thor_restore "$saved" "$live"
      warn "could not create $(pretty "$live"); Thor keeps its current setup"
      return 1
    fi
    created=1
  fi
  if [ "$kind" != staged ] && [ ! -e "$live/apps.json" ] && [ ! -L "$live/apps.json" ]; then
    publish_new "$src" "$live/apps.json" || rc=$?
    case "$rc" in
      0) cmp -s "$src" "$live/apps.json" || { warn "$(pretty "$live/apps.json") differs from its source; kept, and Thor keeps its current setup"; return 2; } ;;
      2) warn "$(pretty "$live/apps.json") appeared meanwhile; kept, and Thor keeps its current setup"; return 2 ;;
      *) # nothing was staged, so the empty folder this run made can go and the old link return
         if [ "$created" = 1 ]; then rmdir "$live" 2>/dev/null && thor_restore "$saved" "$live"; fi
         warn "could not stage Thor's apps.json in $(pretty "$live"); Thor keeps its current setup"
         return 1 ;;
    esac
  fi
  # From here the staged copy stays whatever happens, and a retry resumes from it.
  thor_gate || return 2
  if [ -e "$ndir" ]; then
    nsaved="$(thor_backup_dest "$ndir")"
    thor_backup "$ndir" || { warn "could not move $(pretty "$ndir") aside; Thor keeps its current setup, and $(pretty "$live") holds a copy"; return 1; }
    # Thor may have saved between the first look and the move. The moved folder must hold
    # exactly what was staged: nothing, or a plain apps.json identical to the staged copy
    # (and that file must be there if the staged copy came from it). Otherwise it goes
    # back, both copies stay as they are, and no fallback write follows.
    nentries="$(ls -A "$nsaved")" || nentries="?"
    okl=0
    case "$nentries" in
      "") [ "$src" != "$ndir/apps.json" ] && okl=1 ;;
      apps.json) [ -f "$nsaved/apps.json" ] && [ ! -L "$nsaved/apps.json" ] && cmp -s "$nsaved/apps.json" "$live/apps.json" && okl=1 ;;
    esac
    if [ "$okl" != 1 ]; then
      thor_restore "$nsaved" "$ndir"
      warn "$(pretty "$ndir") changed while it was being moved, so nothing was relinked. Both copies are kept, the staged one in $(pretty "$live")"
      return 2
    fi
  fi
  if ! { mkdir -p "$(dirname "$ndir")" && exact_symlink "$live" "$ndir"; }; then
    if [ -e "$ndir" ] || [ -L "$ndir" ]; then
      warn "$(pretty "$ndir") appeared meanwhile and was kept; the previous folder stays at ${nsaved:+$(pretty "$nsaved")}"
      return 2
    fi
    thor_restore "$nsaved" "$ndir"
    warn "could not link $(pretty "$ndir"); Thor keeps its current setup, and $(pretty "$live") holds a copy"
    return 1
  fi
  thor_link_defaults "$live"
  ok "Thor's apps.json now lives in $(pretty "$live") ($(pretty "$ndir") links there; the old copy is in the backup). Thor sees it at its next start"
  return 0
}

# The earlier behavior, used when thor_relocate is blocked: the snapshot is copied
# into Thor's own folder only when no apps.json exists at all; an existing one
# (even "[]", empty or a symlink) is never touched. Thor skips entries whose app
# isn't installed when it loads and rewrites the file on its next change: the
# snapshot stays whole, and `dots-sync --all` can't bring those entries back.
# It checks for itself before writing: Thor closed (pgrep says so), no sandbox
# container, and a native folder that is absent or a real directory. A symlink there
# is never followed. Returns 2 when it deferred, so no settings are written either.
thor_seed_native() {
  local snap="$1" ndir="$HOME/Library/Application Support/Thor" rc
  local native="$ndir/apps.json"
  thor_gate || return 2
  if [ -e "$HOME/Library/Containers/me.alvinzhu.Thor" ] || [ -L "$HOME/Library/Containers/me.alvinzhu.Thor" ]; then
    warn "Thor has a sandbox container here, so nothing in $(pretty "$ndir") was changed"; return 2
  fi
  if ! outside_checkout "$ndir" || ! outside_checkout "$native"; then
    warn "Thor's folder or its apps.json lies in or links into the dotfiles checkout, so nothing was changed"; return 2
  fi
  if [ -L "$ndir" ] || { [ -e "$ndir" ] && [ ! -d "$ndir" ]; }; then
    warn "$(pretty "$ndir") is a link or not a folder; left alone"; return 2
  fi
  if [ -e "$native" ] || [ -L "$native" ]; then
    ok "Thor already has an apps.json; kept"
  elif ! mkdir -p "$(dirname "$native")"; then
    warn "could not create $(pretty "$(dirname "$native")")"
  else
    rc=0
    publish_new "$snap" "$native" || rc=$?
    case "$rc" in
      0) ok "Thor shortcuts copied to $(pretty "$native") (Thor reads them at its next start)" ;;
      2) ok "Thor already has an apps.json; kept" ;;
      *) warn "could not copy Thor's shortcuts to $(pretty "$native")" ;;
    esac
  fi
  return 0
}

# Thor's shortcuts and menu-bar preference. The tracked thor/ folder is only a seed.
apply_thor_config() {
  local seed="$DOTFILES/thor" domain=me.alvinzhu.Thor rc=0
  if ! app_installed Thor; then
    info "${DIM}Thor isn't installed; its shortcuts are applied on a later run${N}"
    return 0
  fi
  if [ ! -f "$seed/apps.json" ]; then
    warn "$(pretty "$seed/apps.json") is missing; Thor's shortcuts were not applied"
    return 0
  fi
  thor_relocate || rc=$?
  if [ "$rc" = 1 ]; then rc=0; thor_seed_native "$seed/apps.json" || rc=$?; fi
  # The menu-bar icon: only when this preference was never set, and not when the
  # run deferred (Thor running or not provably closed, container, foreign link).
  local plist="$seed/defaults.plist" val
  [ "$rc" = 2 ] && return 0
  if [ -f "$plist" ] && ! "$DEFAULTS_BIN" read "$domain" enableMenuBarIcon >/dev/null 2>&1; then
    val="$(plutil -extract enableMenuBarIcon raw -o - "$plist" 2>/dev/null || true)"
    case "$val" in
      true|false)
        "$DEFAULTS_BIN" write "$domain" enableMenuBarIcon -bool "$val" \
          && ok "Thor menu-bar icon: $val" || warn "could not set Thor's menu-bar icon preference" ;;
      *) warn "$(pretty "$plist") has no enableMenuBarIcon; skipped" ;;
    esac
  fi
}

# Rectangle's portable preferences (shortcuts and behaviors, no update or window
# state) are imported with `defaults import` (NSUserDefaults) only when Rectangle has
# no settings: no readable defaults domain and no prefs plist (file or link) under
# ~/Library/Preferences. A failed read is not treated as "absent" evidence on its
# own; the plist check covers a pending or unreadable config. Launch on login can
# still need macOS approval and Rectangle's normal Accessibility onboarding.
apply_rectangle_config() {
  local snap="$CONFIG/rectangle/com.knollsoft.Rectangle.plist" domain=com.knollsoft.Rectangle
  local prefs="$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
  if ! app_installed Rectangle; then
    info "${DIM}Rectangle isn't installed; its shortcuts are applied on a later run${N}"
    return 0
  fi
  if [ ! -f "$snap" ]; then
    warn "$(pretty "$snap") is missing; Rectangle's shortcuts were not applied"
    return 0
  fi
  if "$DEFAULTS_BIN" read "$domain" >/dev/null 2>&1 || [ -e "$prefs" ] || [ -L "$prefs" ]; then
    ok "Rectangle already has settings; kept"
  elif ! plutil -lint "$snap" >/dev/null 2>&1; then
    warn "$(pretty "$snap") isn't a valid plist; Rectangle's shortcuts were not applied"
  elif "$DEFAULTS_BIN" import "$domain" "$snap"; then
    ok "Rectangle shortcuts and settings imported (they take effect at Rectangle's next start; launch on login may need macOS approval, and Rectangle asks for Accessibility access as usual)"
  else
    warn "could not import Rectangle's settings; the next run retries"
  fi
}

# outside_checkout PATH: 0 when PATH, with every symlink resolved (parts that don't
# exist yet too), is outside the dotfiles checkout. Any error counts as inside.
outside_checkout() {
  python3 -I -c 'import os,sys
p=os.path.realpath(sys.argv[1]); r=os.path.realpath(sys.argv[2])
sys.exit(1 if os.path.commonpath([p,r])==r else 0)' "$1" "$DOTFILES" 2>/dev/null
}

# BetterCmdTab's two-way config: its config.json under an absolute XDG_CONFIG_HOME.
# An installed app with no such path gets the documented partial seed "{}", which
# leaves every other value as it is. Anything already there (a file, a link, even a
# dangling one, a folder) is kept. Recorded chords and per-Mac state stay out of it.
apply_bettercmdtab_config() {
  local dir="$CONFIG/bettercmdtab" dest rc=0 seed
  dest="$dir/config.json"
  if ! app_installed BetterCmdTab; then
    info "${DIM}BetterCmdTab isn't installed; its config.json is created on a later run${N}"
    return 0
  fi
  case "$CONFIG" in
    /*) ;;
    *) warn "XDG_CONFIG_HOME isn't an absolute path; BetterCmdTab's config.json was not created"; return 0 ;;
  esac
  # The config must stay local: never in the checkout, whatever links lead there.
  if ! outside_checkout "$dir"; then
    warn "$(pretty "$dir") lies in or links into the dotfiles checkout, so BetterCmdTab's config.json was not created"
    return 0
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if outside_checkout "$dest"; then ok "BetterCmdTab already has a config.json; kept"
    else warn "$(pretty "$dest") links into the dotfiles checkout; kept as it is and not followed"; fi
    return 0
  fi
  if ! mkdir -p "$dir"; then warn "could not create $(pretty "$dir")"; return 0; fi
  seed="$(mktemp "${TMPDIR:-/tmp}/bcmdt-seed.XXXXXX")" || { warn "could not create a temporary file"; return 0; }
  printf '{}\n' > "$seed"
  publish_new "$seed" "$dest" || rc=$?
  rm -f "$seed"
  case "$rc" in
    0) ok "BetterCmdTab config.json created in $(pretty "$dir") (two-way config; it applies when BetterCmdTab reads it)" ;;
    2) ok "BetterCmdTab already has a config.json; kept" ;;
    *) warn "could not create $(pretty "$dest")" ;;
  esac
}

# VS Code keeps reading its settings at the native path (install.sh links that to the
# tracked file). The same file is also exposed at $CONFIG/vscode/settings.json with a
# link. Whatever is already there is kept, unless it is already that same file.
apply_vscode_xdg_link() {
  local src="$DOTFILES/vscode/settings.json" dest="$CONFIG/vscode/settings.json"
  case "$CONFIG" in
    /*) ;;
    *) warn "XDG_CONFIG_HOME isn't an absolute path; $(pretty "$dest") was not linked"; return 0 ;;
  esac
  if [ ! -f "$src" ]; then
    warn "$(pretty "$src") is missing; VS Code's settings link was not made"
    return 0
  fi
  if [ -L "$dest" ] && [ "$dest" -ef "$src" ]; then
    ok "$(pretty "$dest")"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$(pretty "$dest") already exists and isn't the tracked settings; kept"
  elif mkdir -p "$(dirname "$dest")" && exact_symlink "$src" "$dest"; then
    ok "$(pretty "$dest") → $(pretty "$src")"
  else
    warn "could not link $(pretty "$dest")"
  fi
}
