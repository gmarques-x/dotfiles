#!/usr/bin/env bash
# Fixture test for macos/app-configs.sh. Uses a temp HOME, fake app folders and a
# stub `defaults`; never touches the real user domain, apps or preferences.
# Run: bash tests/app-configs.test.sh
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d)"
trap 'chmod -R u+w "$ROOT" 2>/dev/null; rm -rf "$ROOT"' EXIT

FAILS=0
check() { if [ "$1" = "$2" ]; then :; else FAILS=$((FAILS+1)); printf 'FAIL: %s (got [%s], want [%s])\n' "$3" "$1" "$2"; fi; }

# Stub defaults: one file per domain under $STUB_DB; "import" can be forced to fail.
STUB="$ROOT/defaults-stub"
cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
d="$STUB_DB/$2"
case "$1" in
  read)   if [ -n "${3-}" ]; then grep -q "^$3=" "$d" 2>/dev/null && grep "^$3=" "$d"; else [ -e "$d" ]; fi ;;
  write)  mkdir -p "$STUB_DB"; echo "$3=$5" >> "$d" ;;
  import) [ -z "${STUB_FAIL_IMPORT-}" ] && { mkdir -p "$STUB_DB"; cp "$3" "$d"; } ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUB"

# install.sh helpers, reduced to what the sourced file needs.
info() { :; }; ok() { OUT+="ok:$1"$'\n'; }; warn() { OUT+="warn:$1"$'\n'; }
pretty() { printf '%s' "$1"; }; backup() { echo "unexpected backup" >&2; FAILS=$((FAILS+1)); }
DIM= N=

# must CMD...: setup commands abort the whole run on error (expected negative cases
# are the assertions below, not setup).
must() { "$@" || { echo "setup failed: $*" >&2; exit 1; }; }
# app NAME: fake NAME.app in the fake system Applications folder.
app() { must mkdir -p "$SYSTEM_APPS_DIR/$1.app"; }

new_env() {  # fresh HOME with spaces in the XDG path, snapshots linked in
  chmod -R u+w "$ROOT/home" 2>/dev/null
  rm -rf "$ROOT/home" "$ROOT/sys apps" "$ROOT/db" "$ROOT/target.json"
  must mkdir -p "$ROOT/home/xdg conf" "$ROOT/sys apps"
  export HOME="$ROOT/home" STUB_DB="$ROOT/db" SYSTEM_APPS_DIR="$ROOT/sys apps" DEFAULTS_BIN="$STUB"
  unset STUB_FAIL_IMPORT
  CONFIG="$HOME/xdg conf"
  must ln -s "$REPO/thor" "$CONFIG/thor"; must ln -s "$REPO/rectangle" "$CONFIG/rectangle"
  NATIVE="$HOME/Library/Application Support/Thor/apps.json"
  OUT=
}
. "$REPO/macos/app-configs.sh"
leftovers() { ls -A "$(dirname "$NATIVE")" 2>/dev/null | grep -c 'tmp' ; }

# Absent apps: nothing happens.
new_env; apply_thor_config; apply_rectangle_config
check "$([ -e "$NATIVE" ] && echo y || echo n)" n "absent Thor: no file"
check "$([ -e "$STUB_DB/com.knollsoft.Rectangle" ] && echo y || echo n)" n "absent Rectangle: no import"

# Fresh restore, then a second run.
new_env; app Thor; app Rectangle
apply_thor_config; apply_rectangle_config
check "$(cmp -s "$NATIVE" "$REPO/thor/apps.json" && echo same)" same "fresh Thor copy"
check "$(cat "$STUB_DB/me.alvinzhu.Thor")" "enableMenuBarIcon=false" "Thor menu setting"
check "$(cmp -s "$STUB_DB/com.knollsoft.Rectangle" "$REPO/rectangle/com.knollsoft.Rectangle.plist" && echo same)" same "fresh Rectangle import is a byte-for-byte copy"
check "$(leftovers)" 0 "no temp files after publish"
echo 'mine' > "$NATIVE"; : > "$STUB_DB/com.knollsoft.Rectangle"
apply_thor_config; apply_rectangle_config
check "$(cat "$NATIVE")" mine "second run keeps Thor file"
check "$(wc -c < "$STUB_DB/com.knollsoft.Rectangle" | tr -d ' ')" 0 "second run keeps Rectangle"

# Existing apps.json forms are preserved: [], zero-byte, symlink (also dangling).
for form in empty-array zero symlink dangling; do
  new_env; app Thor; must mkdir -p "$(dirname "$NATIVE")"
  case "$form" in
    empty-array) printf '[]' > "$NATIVE" ;;
    zero) : > "$NATIVE" ;;
    symlink) printf '[]' > "$ROOT/target.json"; must ln -s "$ROOT/target.json" "$NATIVE" ;;
    dangling) must ln -s "$ROOT/missing.json" "$NATIVE" ;;
  esac
  apply_thor_config
  case "$form" in
    empty-array) check "$(cat "$NATIVE")" "[]" "$form kept" ;;
    zero) check "$(wc -c < "$NATIVE" | tr -d ' ')" 0 "$form kept" ;;
    symlink) check "$([ -L "$NATIVE" ] && cat "$ROOT/target.json")" "[]" "$form kept" ;;
    dangling) check "$([ -L "$NATIVE" ] && [ ! -e "$ROOT/missing.json" ] && echo y)" y "$form kept" ;;
  esac
  check "$(leftovers)" 0 "$form: no temp files"
done

# A competing writer creates the destination during publish: it is kept.
# The fixture PATH holds a fake `link` that creates the rival, then runs /bin/link.
FAKEBIN="$ROOT/fakebin"; must mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/link" <<'EOF'
#!/bin/sh
case "$RIVAL" in
  file) printf rival > "$2" ;;
  dir)  mkdir "$2" ;;
esac
exec /bin/link "$@"
EOF
must chmod +x "$FAKEBIN/link"
link() { echo "shell function link must be bypassed" >&2; return 1; }   # like install.sh's

new_env; app Thor
RIVAL=file PATH="$FAKEBIN:$PATH" apply_thor_config
check "$(cat "$NATIVE")" rival "competing writer kept"
check "$(leftovers)" 0 "race: no temp files"

# A competing real directory: nothing is linked into it, and the temp is cleaned.
new_env; app Thor
RIVAL=dir PATH="$FAKEBIN:$PATH" apply_thor_config
check "$([ -d "$NATIVE" ] && echo dir)" dir "competing directory kept"
check "$(ls -A "$NATIVE" | wc -l | tr -d ' ')" 0 "competing directory stays empty"
check "$(leftovers)" 0 "dir race: no temp files"

# Failed publish (unwritable folder): no partial native file, and a retry works.
new_env; app Thor; must mkdir -p "$(dirname "$NATIVE")"; must chmod 555 "$(dirname "$NATIVE")"
apply_thor_config 2>/dev/null   # mktemp's "Permission denied" is the expected failure
check "$(printf '%s' "$OUT" | grep -c '^warn:could not copy')" 1 "failed publish warns"
check "$(ls -A "$(dirname "$NATIVE")" | wc -l | tr -d ' ')" 0 "failed publish leaves nothing"
must chmod 755 "$(dirname "$NATIVE")"; apply_thor_config
check "$(cmp -s "$NATIVE" "$REPO/thor/apps.json" && echo same)" same "retry after failed publish"

# Rectangle: failed import then retry; existing prefs plist (file or link) guards.
new_env; app Rectangle
STUB_FAIL_IMPORT=1 apply_rectangle_config
check "$(printf '%s' "$OUT" | grep -c '^warn:could not import')" 1 "failed import warns"
check "$([ -e "$STUB_DB/com.knollsoft.Rectangle" ] && echo y || echo n)" n "failed import leaves no domain"
apply_rectangle_config
check "$([ -e "$STUB_DB/com.knollsoft.Rectangle" ] && echo y)" y "retry imports"
for form in file link; do
  new_env; app Rectangle; must mkdir -p "$HOME/Library/Preferences"
  p="$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
  if [ "$form" = file ]; then : > "$p"; else must ln -s "$ROOT/nowhere.plist" "$p"; fi
  apply_rectangle_config
  check "$([ -e "$STUB_DB/com.knollsoft.Rectangle" ] && echo y || echo n)" n "prefs $form guards import"
done

# Home Applications counts as installed.
new_env; must mkdir -p "$HOME/Applications/Rectangle.app"; apply_rectangle_config
check "$([ -e "$STUB_DB/com.knollsoft.Rectangle" ] && echo y)" y "home Applications"

if [ "$FAILS" -eq 0 ]; then echo "all app-configs tests passed"; else echo "$FAILS failure(s)"; exit 1; fi
