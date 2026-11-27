#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="dist/Lab VPN.app"
mkdir -p "$app/Contents/MacOS" .build/modules
cp Info.plist "$app/Contents/Info.plist"
swiftc -target "$(uname -m)-apple-macosx13.0" -module-cache-path .build/modules -O Sources/*.swift -o "$app/Contents/MacOS/LabVPN"
payload="$app/Contents/Resources/Helper"
mkdir -p "$payload"
swiftc -target "$(uname -m)-apple-macosx13.0" -module-cache-path .build/modules -O Sources/Configuration.swift Sources/HelperProtocol.swift Helper/main.swift -o "$payload/lab-vpn-service"
codesign --force --sign - "$payload/lab-vpn-service"
python3 Helper/bundle-tools.py "$payload/tools"
cp Helper/install-service.sh "$payload/install-service.sh"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf 'Built %s\n' "$app"
