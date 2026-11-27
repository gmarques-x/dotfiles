#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

applications="${1:?Expected an Applications directory}"
backup="${2:?Expected a backup directory}"
name="Lab VPN.app"
source="dist/$name"
destination="$applications/$name"

./build.sh
if [ ! -L "$destination" ] && [ -d "$destination" ] &&
   /usr/bin/diff -qr "$source" "$destination" >/dev/null &&
   /usr/bin/codesign --verify --strict "$destination"; then
  exit 0
fi

mkdir -p "$applications"
stage="$(mktemp -d "$applications/.lab-vpn.XXXXXXXX")"
trap '/bin/rm -rf "$stage"' EXIT
/usr/bin/ditto "$source" "$stage/$name"
/usr/bin/codesign --verify --strict "$stage/$name"

previous=""
if [ -e "$destination" ] || [ -L "$destination" ]; then
  mkdir -p "$backup"
  previous="$(mktemp -d "$backup/lab-vpn.XXXXXXXX")/$name"
  mv "$destination" "$previous"
fi

if ! mv "$stage/$name" "$destination"; then
  if [ -n "$previous" ]; then mv "$previous" "$destination"; fi
  exit 1
fi
