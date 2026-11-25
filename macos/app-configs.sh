#!/usr/bin/env bash
# Sourced by install.sh (step "Folders and configs"): seeds a fresh setup with the
# Thor and Rectangle snapshots (thor/, rectangle/, linked at $CONFIG/thor and
# $CONFIG/rectangle). Uses install.sh's info, ok, warn, backup and pretty.
#
# Nothing is restarted. Existing settings always win: a snapshot is applied only to
# an installed app that has no settings of its own yet, and nothing is overwritten.
# Test seams: SYSTEM_APPS_DIR (default /Applications; ~/Applications is always
# checked too) and DEFAULTS_BIN (default defaults).

DEFAULTS_BIN="${DEFAULTS_BIN:-defaults}"

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

# Thor reads and rewrites its own apps.json. The snapshot is copied there only when
# no apps.json exists at all; an existing one (even "[]", empty or a symlink) is
# never touched. Thor skips entries whose app isn't installed when it loads and
# rewrites the file on its next change: the snapshot stays whole, and
# `dots-sync --all` can't bring those entries back.
apply_thor_config() {
  local snap="$CONFIG/thor/apps.json" native="$HOME/Library/Application Support/Thor/apps.json"
  local domain=me.alvinzhu.Thor rc
  if ! app_installed Thor; then
    info "${DIM}Thor isn't installed; its shortcuts are applied on a later run${N}"
    return 0
  fi
  if [ ! -f "$snap" ]; then
    warn "$(pretty "$snap") is missing; Thor's shortcuts were not applied"
    return 0
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
  # The menu-bar icon: only when this preference was never set.
  local plist="$CONFIG/thor/defaults.plist" val
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
