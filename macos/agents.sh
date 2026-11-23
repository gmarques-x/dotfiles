#!/usr/bin/env bash
# Stop Apple background agents that aren't used. For your user only, no sudo,
# System Integrity Protection stays on.
#   agents.sh            turn them off (they stop at your next login; SIP blocks stopping them sooner)
#   agents.sh enable     undo: turn them all back on
#   agents.sh status     show each one's state
set -uo pipefail

AGENTS=(
  # Siri (switched off in debloat.sh; these are its helpers)
  com.apple.siriknowledged
  com.apple.siriactionsd
  com.apple.siriinferenced
  com.apple.sirittsd
  com.apple.SiriTTSTrainingAgent
  com.apple.assistantd          # also used by dictation
  com.apple.assistant_cdmd
  # Apps and features not used
  com.apple.newsd
  com.apple.tipsd
  com.apple.gamed               # Game Center (not needed by Steam)
  # Suggestions
  com.apple.suggestd            # Siri suggestions in Spotlight, Mail, contacts
  com.apple.parsecd             # Spotlight web suggestions
  com.apple.knowledge-agent
  # Ads
  com.apple.ap.adprivacyd
  com.apple.ap.promotedcontentd
)

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
domain="gui/$(id -u)"
case ${1:-disable} in
  disable)
    for a in "${AGENTS[@]}"; do launchctl disable "$domain/$a"; done
    echo "    Turned off ${#AGENTS[@]} Apple agents; they stop at your next login. Undo: $self enable" ;;
  enable)
    for a in "${AGENTS[@]}"; do launchctl enable "$domain/$a"; done
    echo "    Turned ${#AGENTS[@]} Apple agents back on; they return at your next login." ;;
  status)
    disabled=$(launchctl print-disabled "$domain")
    for a in "${AGENTS[@]}"; do
      d=$(grep -q "\"$a\" => disabled" <<<"$disabled" && echo off || echo on)
      r=$(launchctl print "$domain/$a" 2>/dev/null | grep -q 'state = running' && echo running || echo stopped)
      printf '  %-34s %-4s %s\n' "$a" "$d" "$r"
    done ;;
  *) echo "Usage: agents.sh [disable|enable|status]"; exit 2 ;;
esac
