#!/usr/bin/env bash
# Turn off Apple features that aren't used: Siri, Look Up suggestions,
# personalised ads, Game Center. Then stop their background agents (agents.sh).
# Run by install.sh; safe to run again. Undo the agents with: agents.sh enable
set -uo pipefail
failed=0
w() { defaults write "$@" 2>/dev/null || { printf '    ! could not set %s %s\n' "$1" "$2" >&2; failed=1; }; }

w com.apple.assistant.support "Assistant Enabled" -bool false       # Siri off
w com.apple.Siri StatusMenuVisible -bool false                      # no Siri in the menu bar
w com.apple.Siri VoiceTriggerUserEnabled -bool false                # no "Hey Siri"
w com.apple.lookup.shared LookupSuggestionsDisabled -bool true      # no Look Up suggestions
w com.apple.AdLib allowApplePersonalizedAdvertising -bool false     # no personalised ads
w com.apple.AdLib allowIdentifierForAdvertising -bool false
w com.apple.gamed Disabled -bool true                               # Game Center off (Steam doesn't need it)

bash "$(dirname "$0")/agents.sh" disable || failed=1
exit "$failed"
