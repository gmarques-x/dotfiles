#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022
label=com.gmarques.lab-vpn
parent=/Library/PrivilegedHelperTools
target="$parent/$label"
plist="/Library/LaunchDaemons/$label.plist"
source="$1"
uid="$2"
[[ $EUID == 0 && "$uid" =~ ^[1-9][0-9]*$ ]]
/usr/bin/id "$uid" >/dev/null
[[ ! -e "$target" && ! -L "$target" && ! -e "$plist" && ! -L "$plist" ]]
/usr/bin/install -d -o root -g wheel -m 0755 "$parent"
stage="$(mktemp -d "$parent/.lab-vpn.XXXXXXXX")"
staged_plist="$(mktemp /Library/LaunchDaemons/.lab-vpn.XXXXXXXX)"
installed=0
cleanup() {
    rm -rf "$stage"
    rm -f "$staged_plist"
    if [[ $installed == 1 ]]; then
        launchctl bootout "system/$label" >/dev/null 2>&1 || true
        rm -rf "$target"
        rm -f "$plist"
    fi
}
trap cleanup EXIT
install -m 0755 "$source/lab-vpn-service" "$stage/lab-vpn-service"
install -d -m 0755 "$stage/tools"
for file in "$source"/tools/*; do
    [[ -f "$file" && ! -L "$file" ]]
    install -m 0755 "$file" "$stage/tools"
done
for binary in "$stage/lab-vpn-service" "$stage/tools/bash" "$stage/tools/wg" "$stage/tools/wireguard-go"; do
    codesign --verify --strict "$binary"
done
"$stage/tools/bash" --version >/dev/null
chown -R root:wheel "$stage"
chmod 0755 "$stage"
cat > "$staged_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$label</string>
<key>ProgramArguments</key><array><string>$target/lab-vpn-service</string><string>$uid</string></array>
<key>inetdCompatibility</key><dict><key>Wait</key><false/></dict>
<key>Sockets</key><dict><key>Control</key><dict>
<key>SockPathName</key><string>$target/control.sock</string>
<key>SockPathMode</key><integer>438</integer>
</dict></dict>
<key>AbandonProcessGroup</key><true/>
</dict></plist>
PLIST
plutil -lint "$staged_plist"
chown root:wheel "$staged_plist"
chmod 0644 "$staged_plist"
mv "$stage" "$target"
installed=1
mv "$staged_plist" "$plist"
launchctl bootstrap system "$plist"
[[ -S "$target/control.sock" ]]
installed=0
