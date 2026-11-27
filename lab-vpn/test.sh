#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/modules
swiftc -module-cache-path .build/modules Sources/Configuration.swift Sources/Profiles.swift Sources/HelperProtocol.swift Sources/WireGuard.swift Tests/main.swift -o .build/profile-tests
.build/profile-tests
