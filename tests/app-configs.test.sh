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

# Stub pgrep: "Thor is running" while $ROOT/thor-running exists.
PGSTUB="$ROOT/pgrep-stub"
printf '#!/bin/sh\n[ -e "%s/thor-running" ]\n' "$ROOT" > "$PGSTUB"
chmod +x "$PGSTUB"

# install.sh helpers, reduced to what the sourced file needs. backup() moves into
# $BACKUP like the real one and counts its calls.
info() { INFO+="$1"$'\n'; }; ok() { OUT+="ok:$1"$'\n'; }; warn() { OUT+="warn:$1"$'\n'; }
pretty() { printf '%s' "$1"; }
backup() {
  local rel="${1#"$HOME"/}"
  BACKUPS=$((BACKUPS+1))
  # RACE_ACTION simulates Thor saving (or the folder changing) just before the move.
  if [ "$1" = "$NATIVE_DIR" ] && [ -n "${RACE_ACTION-}" ]; then
    case "$RACE_ACTION" in
      edit)   printf '[{"a":2}]' > "$1/apps.json" ;;
      appear) printf '[{"b":1}]' > "$1/apps.json" ;;
      extra)  printf x > "$1/extra.txt" ;;
      vanish) rm -f "$1/apps.json" ;;
    esac
  fi
  mkdir -p "$(dirname "$BACKUP/$rel")" && mv "$1" "$BACKUP/$rel"
}
DIM= N=

# must CMD...: setup commands abort the whole run on error (expected negative cases
# are the assertions below, not setup).
must() { "$@" || { echo "setup failed: $*" >&2; exit 1; }; }
# app NAME: fake NAME.app in the fake system Applications folder.
app() { must mkdir -p "$SYSTEM_APPS_DIR/$1.app"; }

new_env() {  # fresh HOME with spaces in the XDG path, snapshots linked in
  chmod -R u+w "$ROOT/home" 2>/dev/null
  rm -rf "$ROOT/home" "$ROOT/sys apps" "$ROOT/db" "$ROOT/target.json" "$ROOT/backup" "$ROOT/other xdg" "$ROOT/thor-running" "$ROOT/foreign" "$ROOT/foreign2"
  must mkdir -p "$ROOT/home/xdg conf" "$ROOT/sys apps"
  export HOME="$ROOT/home" STUB_DB="$ROOT/db" SYSTEM_APPS_DIR="$ROOT/sys apps" DEFAULTS_BIN="$STUB" PGREP_BIN="$PGSTUB"
  unset STUB_FAIL_IMPORT
  DOTFILES="$REPO" BACKUP="$ROOT/backup"
  CONFIG="$HOME/xdg conf"
  # The previous installer's state: both snapshot links.
  must ln -s "$REPO/thor" "$CONFIG/thor"; must ln -s "$REPO/rectangle" "$CONFIG/rectangle"
  NATIVE_DIR="$HOME/Library/Application Support/Thor"
  NATIVE="$NATIVE_DIR/apps.json"
  OUT= INFO= BACKUPS=0
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
check "$(cat "$CONFIG/thor/apps.json")" rival "competing writer kept"
check "$([ -e "$NATIVE_DIR" ] || [ -L "$NATIVE_DIR" ] && echo y || echo n)" n "competing writer: Thor's folder not moved"
check "$(ls -A "$CONFIG/thor" | grep -c tmp)" 0 "race: no temp files"

# A competing real directory: nothing is linked into it, and the temp is cleaned.
new_env; app Thor
RIVAL=dir PATH="$FAKEBIN:$PATH" apply_thor_config
check "$([ -d "$CONFIG/thor/apps.json" ] && echo dir)" dir "competing directory kept"
check "$(ls -A "$CONFIG/thor/apps.json" | wc -l | tr -d ' ')" 0 "competing directory stays empty"
check "$(ls -A "$CONFIG/thor" | grep -c tmp)" 0 "dir race: no temp files"

# Failed publish (unwritable folder): no partial native file, and a retry works.
new_env; app Thor; must mkdir -p "$(dirname "$NATIVE")"; must chmod 555 "$(dirname "$NATIVE")"
apply_thor_config 2>/dev/null   # a "Permission denied" is the expected failure
# The unwritable folder can't be moved aside (warn), and the fallback copy fails too (warn).
check "$(printf '%s' "$OUT" | grep -c '^warn:could not move')" 1 "failed move warns"
check "$(printf '%s' "$OUT" | grep -c '^warn:could not copy')" 1 "failed publish warns"
check "$(leftovers)" 0 "failed publish leaves no temp files"
check "$([ -f "$NATIVE" ] && echo y || echo n)" n "failed publish leaves no partial apps.json"
check "$([ -d "$CONFIG/thor" ] && [ ! -L "$CONFIG/thor" ] && echo y)" y "failed move keeps the staged live folder"
check "$([ -L "$BACKUP/${CONFIG#"$HOME"/}/thor" ] && echo y)" y "failed move leaves the old link in the backup"
check "$([ -d "$NATIVE_DIR" ] && [ ! -L "$NATIVE_DIR" ] && echo y)" y "failed move keeps Thor's folder"
must chmod 755 "$(dirname "$NATIVE")"; apply_thor_config   # resumes from the staged copy
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

# ---- Thor relocation to a local folder under XDG_CONFIG_HOME ----
SEED_SUM="$(cksum < "$REPO/thor/apps.json")"
live_is_local() { [ -d "$CONFIG/thor" ] && [ ! -L "$CONFIG/thor" ] && [ "$(readlink "$NATIVE_DIR")" = "$CONFIG/thor" ]; }
seed_untouched() { [ "$(cksum < "$REPO/thor/apps.json")" = "$SEED_SUM" ]; }

# Prior installer link + no native folder: the link is replaced by a real folder.
new_env; app Thor
apply_thor_config
check "$(live_is_local && echo y)" y "old link: folder is local and linked from Library"
check "$(cmp -s "$CONFIG/thor/apps.json" "$REPO/thor/apps.json" && echo same)" same "old link: apps.json seeded"
check "$([ -L "$BACKUP/${CONFIG#"$HOME"/}/thor" ] && echo y)" y "old link: backed up"
check "$([ -L "$CONFIG/thor/defaults.plist" ] && [ "$CONFIG/thor/defaults.plist" -ef "$REPO/thor/defaults.plist" ] && echo y)" y "old link: defaults.plist snapshot still reachable"
# Live edits go through the directory link, replacing by name like Thor does.
printf '[{"edit":1}]' > "$NATIVE_DIR/apps.json.tmp" && mv "$NATIVE_DIR/apps.json.tmp" "$NATIVE_DIR/apps.json"
check "$(cat "$CONFIG/thor/apps.json")" '[{"edit":1}]' "live edit lands in the XDG folder"
check "$(seed_untouched && echo y)" y "live edit never reaches the tracked seed"
# Repeat run: nothing moves, the edit stays.
B0=$BACKUPS; apply_thor_config
check "$BACKUPS" "$B0" "repeat run makes no backup"
check "$(cat "$NATIVE")" '[{"edit":1}]' "repeat run keeps the live edit"
check "$(live_is_local && echo y)" y "repeat run keeps the layout"

# Fresh install without the old link.
new_env; app Thor; rm "$CONFIG/thor"
apply_thor_config
check "$(live_is_local && echo y)" y "fresh: local folder"
check "$(cmp -s "$NATIVE" "$REPO/thor/apps.json" && echo same)" same "fresh: seeded"
check "$BACKUPS" 0 "fresh: nothing backed up"

# Existing native settings move over and the original folder is backed up.
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[{"mine":1}]' > "$NATIVE"
apply_thor_config
check "$(live_is_local && echo y)" y "native: relocated"
check "$(cat "$CONFIG/thor/apps.json")" '[{"mine":1}]' "native: contents kept"
check "$(cat "$BACKUP/Library/Application Support/Thor/apps.json")" '[{"mine":1}]' "native: original folder backed up"
check "$(seed_untouched && echo y)" y "native: seed untouched"

# Conflicts leave everything as it was.
conflict_unchanged() {  # NAME: old link still there (unless said otherwise) and seed intact
  check "$(seed_untouched && echo y)" y "$1: seed untouched"
  check "$BACKUPS" 0 "$1: nothing backed up"
}
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[]' > "$NATIVE"; printf x > "$NATIVE_DIR/other.txt"
apply_thor_config
check "$([ -L "$CONFIG/thor" ] && [ ! -L "$NATIVE_DIR" ] && cat "$NATIVE_DIR/other.txt")" x "extra files: kept"
conflict_unchanged "extra files"

new_env; app Thor; must mkdir -p "$NATIVE_DIR" "$ROOT/foreign"; printf '[]' > "$NATIVE"
rm "$CONFIG/thor"; must mkdir "$CONFIG/thor"; printf live > "$CONFIG/thor/apps.json"
apply_thor_config
check "$(cat "$CONFIG/thor/apps.json")" live "both sides: live folder kept"
check "$(cat "$NATIVE")" "[]" "both sides: native kept"
conflict_unchanged "both sides"

new_env; app Thor; must mkdir -p "$NATIVE_DIR" "$ROOT/foreign"; printf '[]' > "$NATIVE"
rm "$CONFIG/thor"; printf 'secret' > "$ROOT/foreign/apps.json"; must ln -s "$ROOT/foreign" "$CONFIG/thor"
apply_thor_config
check "$(readlink "$CONFIG/thor")" "$ROOT/foreign" "foreign link: kept"
check "$(cat "$ROOT/foreign/apps.json")" secret "foreign link: target not followed or changed"
check "$(ls -A "$ROOT/foreign" | wc -l | tr -d ' ')" 1 "foreign link: nothing added to its target"
check "$(cat "$NATIVE")" "[]" "foreign link: native kept"
conflict_unchanged "foreign link"

new_env; app Thor; must mkdir -p "$(dirname "$NATIVE_DIR")" "$ROOT/foreign"; printf mine > "$ROOT/foreign/apps.json"
must ln -s "$ROOT/foreign" "$NATIVE_DIR"
apply_thor_config
check "$(readlink "$NATIVE_DIR")" "$ROOT/foreign" "foreign native link: kept"
check "$(ls -A "$ROOT/foreign")" apps.json "foreign native link: target untouched"
check "$([ -L "$CONFIG/thor" ] && echo y)" y "foreign native link: old link kept"
conflict_unchanged "foreign native link"

new_env; app Thor; must mkdir -p "$HOME/Library/Containers/me.alvinzhu.Thor" "$NATIVE_DIR"; printf '[]' > "$NATIVE"
apply_thor_config
check "$([ ! -L "$NATIVE_DIR" ] && [ -L "$CONFIG/thor" ] && echo y)" y "sandboxed: nothing moved"

# Thor running: the current setup stays, with a hint.
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[{"run":1}]' > "$NATIVE"; : > "$ROOT/thor-running"
apply_thor_config
check "$([ ! -L "$NATIVE_DIR" ] && [ -L "$CONFIG/thor" ] && cat "$NATIVE")" '[{"run":1}]' "running: setup kept"
check "$(printf '%s' "$INFO" | grep -c 'Quit Thor')" 1 "running: tells how to apply later"
conflict_unchanged "running"
rm "$ROOT/thor-running"; apply_thor_config
check "$(live_is_local && echo y)" y "after quitting: relocated"
check "$(cat "$NATIVE")" '[{"run":1}]' "after quitting: edit kept"

# pgrep unavailable or failing (not exit 0 or 1): defer, change nothing.
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[{"u":1}]' > "$NATIVE"
PGREP_BIN="$ROOT/no-such-pgrep" apply_thor_config
check "$([ ! -L "$NATIVE_DIR" ] && [ -L "$CONFIG/thor" ] && cat "$NATIVE")" '[{"u":1}]' "unknown pgrep: setup kept"
check "$(printf '%s' "$OUT" | grep -c '^warn:could not tell whether Thor is running')" 1 "unknown pgrep: reported"
conflict_unchanged "unknown pgrep"

# The old link is a link, so nothing live can land in the tracked folder.
new_env; app Thor; REPO_LIST="$(ls -A "$REPO/thor")"
apply_thor_config; printf '[{"x":1}]' > "$NATIVE"
check "$(ls -A "$REPO/thor")" "$REPO_LIST" "tracked thor/ gains no files"
check "$(seed_untouched && echo y)" y "tracked apps.json unchanged by live writes"

# Link creation loses a race: a real folder shows up at Thor's path. It is kept,
# and the previous folder stays in the backup.
real_exact_symlink() { python3 -I -c 'import os,sys; os.symlink(sys.argv[1], sys.argv[2])' "$1" "$2" 2>/dev/null; }
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[{"r":1}]' > "$NATIVE"
exact_symlink() { mkdir "$2"; real_exact_symlink "$@"; }
apply_thor_config
check "$([ -d "$NATIVE_DIR" ] && [ ! -L "$NATIVE_DIR" ] && [ -z "$(ls -A "$NATIVE_DIR")" ] && echo y)" y "link race: the new folder is kept untouched"
check "$(cat "$BACKUP/Library/Application Support/Thor/apps.json")" '[{"r":1}]' "link race: previous folder preserved"
check "$(cat "$CONFIG/thor/apps.json")" '[{"r":1}]' "link race: staged copy kept"

# Link creation fails with nothing in the way: the folder is put back, the staged copy stays,
# and a retry finishes.
new_env; app Thor; must mkdir -p "$NATIVE_DIR"; printf '[{"f":1}]' > "$NATIVE"
exact_symlink() { return 1; }
apply_thor_config
check "$([ -d "$NATIVE_DIR" ] && [ ! -L "$NATIVE_DIR" ] && cat "$NATIVE")" '[{"f":1}]' "failed link: folder restored"
check "$(cat "$CONFIG/thor/apps.json")" '[{"f":1}]' "failed link: staged copy kept"
exact_symlink() { real_exact_symlink "$@"; }
apply_thor_config
check "$(live_is_local && cat "$NATIVE")" '[{"f":1}]' "failed link: retry finishes"

# A managed link whose live folder lost apps.json: restoring fails loudly, never silently.
new_env; app Thor; must mkdir -p "$(dirname "$NATIVE_DIR")"; rm "$CONFIG/thor"; must mkdir "$CONFIG/thor"
must ln -s "$CONFIG/thor" "$NATIVE_DIR"; must chmod 555 "$CONFIG/thor"
apply_thor_config 2>/dev/null
check "$(printf '%s' "$OUT" | grep -c "^warn:.*apps.json is missing there")" 1 "missing live apps.json is reported"
check "$(printf '%s' "$OUT" | grep -c "^ok:Thor's apps.json lives")" 0 "missing live apps.json is not reported as done"
must chmod 755 "$CONFIG/thor"

# A backup destination that already exists blocks the move.
new_env; app Thor; must mkdir -p "$NATIVE_DIR" "$BACKUP/Library/Application Support/Thor"; printf '[]' > "$NATIVE"
apply_thor_config
check "$([ ! -L "$NATIVE_DIR" ] && cat "$NATIVE")" "[]" "existing backup destination: Thor's folder kept"

# Thor changes between the first look and the move: the folder goes back, both copies
# stay, nothing is relinked, no fallback write, no menu preference write.
for act in edit appear extra vanish; do
  new_env; app Thor; must mkdir -p "$NATIVE_DIR"
  if [ "$act" != appear ]; then printf '[{"a":1}]' > "$NATIVE"; fi
  RACE_ACTION=$act apply_thor_config
  check "$([ -d "$NATIVE_DIR" ] && [ ! -L "$NATIVE_DIR" ] && echo y)" y "native race ($act): folder restored"
  check "$(printf '%s' "$OUT" | grep -c '^warn:.*changed while it was being moved')" 1 "native race ($act): warned"
  check "$([ -e "$STUB_DB/me.alvinzhu.Thor" ] && echo y || echo n)" n "native race ($act): no preference write"
  case "$act" in
    edit)   check "$(cat "$NATIVE")" '[{"a":2}]' "native race (edit): the newer native save kept"
            check "$(cat "$CONFIG/thor/apps.json")" '[{"a":1}]' "native race (edit): staged copy kept" ;;
    appear) check "$(cat "$NATIVE")" '[{"b":1}]' "native race (appear): the new native file kept"
            check "$(cmp -s "$CONFIG/thor/apps.json" "$REPO/thor/apps.json" && echo same)" same "native race (appear): staged seed kept" ;;
    extra)  check "$(cat "$NATIVE_DIR/extra.txt")" x "native race (extra): extra entry kept"
            check "$(cat "$NATIVE")" '[{"a":1}]' "native race (extra): native apps.json kept" ;;
    vanish) check "$([ -e "$NATIVE" ] && echo y || echo n)" n "native race (vanish): nothing invented in native"
            check "$(cat "$CONFIG/thor/apps.json")" '[{"a":1}]' "native race (vanish): staged copy kept" ;;
  esac
  check "$(seed_untouched && echo y)" y "native race ($act): tracked seed untouched"
done

# The fallback copy has its own guards: no write through a foreign native link, and
# none unless pgrep says Thor is closed, even when the XDG step returned "blocked".
new_env; app Thor; must mkdir -p "$(dirname "$NATIVE_DIR")" "$ROOT/foreign" "$ROOT/foreign2"
rm "$CONFIG/thor"; must ln -s "$ROOT/foreign" "$CONFIG/thor"; must ln -s "$ROOT/foreign2" "$NATIVE_DIR"
apply_thor_config
check "$({ ls -A "$ROOT/foreign2"; ls -A "$ROOT/foreign"; } | grep -c .)" 0 "fallback: foreign native link gets nothing"
check "$([ -e "$STUB_DB/me.alvinzhu.Thor" ] && echo y || echo n)" n "fallback: foreign native link, no preference write"
for how in unknown running; do
  new_env; app Thor; CONFIG="relative/xdg"   # relative XDG makes the XDG step return "blocked"
  case "$how" in
    unknown) PGREP_BIN="$ROOT/no-such-pgrep" apply_thor_config ;;
    running) : > "$ROOT/thor-running"; apply_thor_config ;;
  esac
  check "$([ -e "$NATIVE_DIR" ] || [ -L "$NATIVE_DIR" ] && echo y || echo n)" n "fallback ($how): nothing written to Thor's folder"
  check "$([ -e "$STUB_DB/me.alvinzhu.Thor" ] && echo y || echo n)" n "fallback ($how): no preference write"
done
new_env; app Thor; CONFIG="relative/xdg"; must mkdir -p "$(dirname "$NATIVE_DIR")" "$ROOT/foreign"; must ln -s "$ROOT/foreign" "$NATIVE_DIR"
apply_thor_config
check "$(ls -A "$ROOT/foreign" | wc -l | tr -d ' ')" 0 "fallback: relative XDG plus foreign native link writes nothing"

# Not installed: the old link and everything else stay.
new_env; apply_thor_config
check "$([ -L "$CONFIG/thor" ] && [ ! -e "$NATIVE_DIR" ] && echo y)" y "uninstalled: untouched"

# Custom absolute XDG_CONFIG_HOME, and a relative one (falls back to the old behavior).
new_env; app Thor; CONFIG="$ROOT/other xdg"; must mkdir -p "$CONFIG"
apply_thor_config
check "$([ "$(readlink "$NATIVE_DIR")" = "$ROOT/other xdg/thor" ] && [ -f "$ROOT/other xdg/thor/apps.json" ] && echo y)" y "custom XDG: used"
new_env; app Thor; CONFIG="relative/xdg"
apply_thor_config
check "$([ ! -L "$NATIVE_DIR" ] && cmp -s "$NATIVE" "$REPO/thor/apps.json" && echo same)" same "relative XDG: old behavior"
check "$(printf '%s' "$OUT" | grep -c "^warn:XDG_CONFIG_HOME isn't an absolute")" 1 "relative XDG: warns"

# An existing XDG defaults.plist is kept (already-relocated layout, repeat run).
new_env; app Thor; rm "$CONFIG/thor"; must mkdir "$CONFIG/thor"
printf '[]' > "$CONFIG/thor/apps.json"; printf mine > "$CONFIG/thor/defaults.plist"
must mkdir -p "$(dirname "$NATIVE_DIR")"; must ln -s "$CONFIG/thor" "$NATIVE_DIR"
apply_thor_config
check "$(cat "$CONFIG/thor/defaults.plist")" mine "existing defaults.plist kept"
check "$([ -L "$CONFIG/thor/defaults.plist" ] && echo y || echo n)" n "existing defaults.plist not replaced by a link"

# XDG_CONFIG_HOME that is, or links into, the dotfiles checkout: Thor is not touched.
FAKE="$ROOT/fake checkout"; rm -rf "$FAKE" "$ROOT/alias"
must mkdir -p "$FAKE/thor" "$FAKE/sub"; printf '[{"git":1}]' > "$FAKE/thor/apps.json"; printf '<plist/>' > "$FAKE/thor/defaults.plist"
must ln -s "$FAKE" "$ROOT/alias"
FAKE_SUM="$(cksum < "$FAKE/thor/apps.json")"; FAKE_LIST="$(ls -A "$FAKE/thor")"
for base in "$FAKE" "$ROOT/alias" "$ROOT/alias/sub" "$ROOT/alias/not-yet/deeper"; do
  new_env; app Thor; DOTFILES="$FAKE"; CONFIG="$base"
  must mkdir -p "$NATIVE_DIR"; printf '[{"mine":1}]' > "$NATIVE"
  apply_thor_config
  check "$([ ! -L "$NATIVE_DIR" ] && cat "$NATIVE")" '[{"mine":1}]' "repo guard ($base): native untouched"
  check "$(cksum < "$FAKE/thor/apps.json")" "$FAKE_SUM" "repo guard ($base): tracked apps.json untouched"
  check "$(ls -A "$FAKE/thor")" "$FAKE_LIST" "repo guard ($base): tracked thor/ gains nothing"
  check "$(printf '%s' "$OUT" | grep -c '^warn:XDG_CONFIG_HOME is, or links into')" 1 "repo guard ($base): reported"
  check "$BACKUPS" 0 "repo guard ($base): nothing moved"
done
# An ordinary parent (not the checkout) still works with a fake checkout elsewhere.
new_env; app Thor; DOTFILES="$FAKE"; rm "$CONFIG/thor"; apply_thor_config
check "$(live_is_local && echo y)" y "ordinary XDG parent still relocates"
check "$(cksum < "$FAKE/thor/apps.json")" "$FAKE_SUM" "ordinary parent: fake checkout untouched"
rm -rf "$FAKE" "$ROOT/alias"

# ---- Thor and the checkout: exact git-path guards ----
FAKE="$ROOT/fake checkout"; rm -rf "$FAKE"
must mkdir -p "$FAKE/thor" "$FAKE/appsup"; printf '[{"git":1}]' > "$FAKE/thor/apps.json"; printf '<plist/>' > "$FAKE/thor/defaults.plist"
printf '{"git":1}' > "$FAKE/live.json"
FAKE_LIST="$(ls -AR "$FAKE")"
nothing_changed() {  # NAME: checkout intact, no preference write, no relink
  check "$(ls -AR "$FAKE")" "$FAKE_LIST" "$1: checkout gains nothing"
  check "$(cat "$FAKE/live.json")" '{"git":1}' "$1: tracked file unchanged"
  check "$([ -e "$STUB_DB/me.alvinzhu.Thor" ] && echo y || echo n)" n "$1: no preference write"
}
# 1. A real local XDG folder whose apps.json is a link into the checkout, native absent or present.
for native in absent present; do
  new_env; app Thor; DOTFILES="$FAKE"; rm "$CONFIG/thor"; must mkdir "$CONFIG/thor"
  must ln -s "$FAKE/live.json" "$CONFIG/thor/apps.json"
  if [ "$native" = present ]; then must mkdir -p "$NATIVE_DIR"; printf '[{"n":1}]' > "$NATIVE"; fi
  apply_thor_config
  check "$([ -L "$CONFIG/thor/apps.json" ] && [ "$(readlink "$CONFIG/thor/apps.json")" = "$FAKE/live.json" ] && echo y)" y "live link guard ($native): link preserved"
  check "$(printf '%s' "$OUT" | grep -c "^warn:.*isn't a plain file, so nothing was changed")" 1 "live link guard ($native): reported"
  if [ "$native" = absent ]; then check "$([ -e "$NATIVE_DIR" ] || [ -L "$NATIVE_DIR" ] && echo y || echo n)" n "live link guard: no native folder or link"
  else check "$([ ! -L "$NATIVE_DIR" ] && cat "$NATIVE")" '[{"n":1}]' "live link guard: native kept"; fi
  nothing_changed "live link guard ($native)"
done
# 2. Application Support (or Thor's apps.json) links into the checkout: migration and fallback refuse.
for route in migrate fallback; do
  for shape in parent file; do
    new_env; app Thor; DOTFILES="$FAKE"
    if [ "$route" = fallback ]; then CONFIG="relative/xdg"; fi   # relative XDG makes the XDG step return "blocked"
    if [ "$shape" = parent ]; then
      must mkdir -p "$HOME/Library"; must ln -s "$FAKE/appsup" "$HOME/Library/Application Support"
    else
      must mkdir -p "$NATIVE_DIR"; must ln -s "$FAKE/live.json" "$NATIVE"
    fi
    apply_thor_config
    check "$(printf '%s' "$OUT" | grep -c "^warn:Thor's folder or its apps.json lies in or links into the dotfiles checkout")" 1 "native guard ($route, $shape): reported"
    check "$([ -L "$CONFIG/thor" ] || [ "$route" = fallback ] && echo y)" y "native guard ($route, $shape): old link kept"
    check "$BACKUPS" 0 "native guard ($route, $shape): nothing moved"
    nothing_changed "native guard ($route, $shape)"
  done
done
rm -rf "$FAKE"

# ---- BetterCmdTab config.json ----
BC() { echo "$CONFIG/bettercmdtab/config.json"; }
new_env; apply_bettercmdtab_config
check "$([ -e "$CONFIG/bettercmdtab" ] && echo y || echo n)" n "BetterCmdTab absent: nothing created"
new_env; app BetterCmdTab; apply_bettercmdtab_config
check "$(cat "$(BC)")" "{}" "BetterCmdTab: partial seed"
check "$(ls -A "$CONFIG/bettercmdtab" | wc -l | tr -d ' ')" 1 "BetterCmdTab: no temp files"
printf '{"a":1}' > "$(BC)"; apply_bettercmdtab_config
check "$(cat "$(BC)")" '{"a":1}' "BetterCmdTab: repeat keeps values"
new_env; app BetterCmdTab; must mkdir -p "$CONFIG/bettercmdtab"; must ln -s "$ROOT/nowhere.json" "$(BC)"
apply_bettercmdtab_config
check "$([ -L "$(BC)" ] && [ ! -e "$ROOT/nowhere.json" ] && echo y)" y "BetterCmdTab: dangling link kept"
new_env; app BetterCmdTab; CONFIG="relative/xdg"; apply_bettercmdtab_config
check "$([ -e relative ] && echo y || echo n)" n "BetterCmdTab: relative XDG skipped"
new_env; app BetterCmdTab; apply_bettercmdtab_config
check "$([ -e "$CONFIG/vorssaint" ] && echo y || echo n)" n "Vorssaint: never seeded"

# BetterCmdTab's config never lands in, or follows a link into, the checkout.
FAKE="$ROOT/fake checkout"; rm -rf "$FAKE" "$ROOT/alias" "$ROOT/cfg"
must mkdir -p "$FAKE/sub"; printf '{"git":1}' > "$FAKE/live.json"; must ln -s "$FAKE" "$ROOT/alias"
FAKE_LIST="$(ls -AR "$FAKE")"
# XDG itself is the checkout, or an alias of it (also one that doesn't exist yet below the alias).
for base in "$FAKE" "$ROOT/alias" "$ROOT/alias/sub" "$ROOT/alias/not-yet"; do
  new_env; app BetterCmdTab; DOTFILES="$FAKE"; CONFIG="$base"; apply_bettercmdtab_config
  check "$(ls -AR "$FAKE")" "$FAKE_LIST" "BetterCmdTab ($base): checkout gains nothing"
  check "$(printf '%s' "$OUT" | grep -c '^warn:.*links into the dotfiles checkout')" 1 "BetterCmdTab ($base): reported"
done
# The bettercmdtab folder, or config.json itself, is a link into the checkout.
new_env; app BetterCmdTab; DOTFILES="$FAKE"; CONFIG="$ROOT/cfg"; must mkdir -p "$CONFIG"; must ln -s "$FAKE/sub" "$CONFIG/bettercmdtab"
apply_bettercmdtab_config
check "$(ls -AR "$FAKE")" "$FAKE_LIST" "BetterCmdTab: folder link into checkout gains nothing"
check "$([ "$(readlink "$CONFIG/bettercmdtab")" = "$FAKE/sub" ] && echo y)" y "BetterCmdTab: folder link kept"
check "$(printf '%s' "$OUT" | grep -c '^warn:')" 1 "BetterCmdTab: folder link reported"
for target in live.json missing.json; do
  new_env; app BetterCmdTab; DOTFILES="$FAKE"; CONFIG="$ROOT/cfg"; rm -rf "$CONFIG"; must mkdir -p "$CONFIG/bettercmdtab"
  must ln -s "$FAKE/$target" "$CONFIG/bettercmdtab/config.json"
  apply_bettercmdtab_config
  check "$(ls -AR "$FAKE")" "$FAKE_LIST" "BetterCmdTab: file link to $target gains nothing"
  check "$(readlink "$CONFIG/bettercmdtab/config.json")" "$FAKE/$target" "BetterCmdTab: file link to $target kept"
  check "$(printf '%s' "$OUT" | grep -c '^warn:.*links into the dotfiles checkout; kept')" 1 "BetterCmdTab: file link to $target reported"
done
check "$(cat "$FAKE/live.json")" '{"git":1}' "BetterCmdTab: tracked file unchanged"
# A local config next to a checkout elsewhere still gets its seed.
new_env; app BetterCmdTab; DOTFILES="$FAKE"; apply_bettercmdtab_config
check "$(cat "$CONFIG/bettercmdtab/config.json")" "{}" "BetterCmdTab: local seed with a checkout elsewhere"
rm -rf "$FAKE" "$ROOT/alias" "$ROOT/cfg"

# ---- VS Code link ----
VS="$CONFIG/vscode/settings.json"
new_env; apply_vscode_xdg_link
check "$([ -L "$CONFIG/vscode/settings.json" ] && [ "$CONFIG/vscode/settings.json" -ef "$REPO/vscode/settings.json" ] && echo y)" y "VS Code: linked"
apply_vscode_xdg_link
check "$(printf '%s' "$OUT" | grep -c '^warn:')" 0 "VS Code: repeat run is quiet"
new_env; must mkdir -p "$CONFIG/vscode"; printf '{"mine":1}' > "$CONFIG/vscode/settings.json"
printf '{"ws":1}' > "$CONFIG/vscode/home.code-workspace"
apply_vscode_xdg_link
check "$(cat "$CONFIG/vscode/settings.json")" '{"mine":1}' "VS Code: existing settings kept"
check "$(cat "$CONFIG/vscode/home.code-workspace")" '{"ws":1}' "VS Code: workspace untouched"
check "$(printf '%s' "$OUT" | grep -c '^warn:')" 1 "VS Code: conflict warns"
new_env; must mkdir -p "$CONFIG/vscode"; must ln -s "$ROOT/nowhere.json" "$CONFIG/vscode/settings.json"
apply_vscode_xdg_link
check "$(readlink "$CONFIG/vscode/settings.json")" "$ROOT/nowhere.json" "VS Code: foreign link kept"

if [ "$FAILS" -eq 0 ]; then echo "all app-configs tests passed"; else echo "$FAILS failure(s)"; exit 1; fi
