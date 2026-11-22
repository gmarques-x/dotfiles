#!/usr/bin/env bash
# macOS settings: the ones that differ from a fresh Mac, in System Settings'
# Appearance, Desktop & Dock, Accessibility and Trackpad. Run by install.sh;
# safe to run on its own and again. Some take effect only after logging out.

set -uo pipefail
w() { defaults write "$@" || printf '    ! could not set %s %s\n' "$1" "$2" >&2; }

# ---- Appearance
w NSGlobalDomain AppleAccentColor -int 4                                # accent: blue
w NSGlobalDomain AppleHighlightColor -string "0.262745 0.298039 0.368627 Other"  # highlight: #434C5E
w NSGlobalDomain AppleShowScrollBars -string WhenScrolling              # scroll bars: when scrolling
w NSGlobalDomain AppleReduceDesktopTinting -bool true                   # wallpaper tinting in windows: off
w NSGlobalDomain NSGlassTintAmount -int 1                               # Liquid Glass: tinted

# ---- Desktop & Dock
w com.apple.dock orientation -string right
w com.apple.dock tilesize -int 33
w com.apple.dock mineffect -string scale
w com.apple.dock minimize-to-application -bool true
w com.apple.dock show-process-indicators -bool false
w com.apple.dock show-recents -bool false
w com.apple.dock expose-group-apps -bool true                           # Mission Control: group windows by app
w NSGlobalDomain AppleWindowTabbingMode -string manual                  # prefer tabs: never
w NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true                # ask to keep changes when closing
w com.apple.WindowManager StandardHideDesktopIcons -bool true           # show items on desktop: off
w com.apple.WindowManager StandardHideWidgets -bool true                # show widgets on desktop: off
w com.apple.WindowManager StageManagerHideWidgets -bool true
w com.apple.WindowManager HideDesktop -bool true
w com.apple.WindowManager EnableStandardClickToShowDesktop -bool false  # click wallpaper: only in Stage Manager
w com.apple.WindowManager EnableTiledWindowMargins -bool false          # tiled windows have margins: off
w com.apple.WindowManager AppWindowGroupingBehavior -int 0              # Stage Manager: one window at a time
w com.apple.WindowManager AutoHide -bool true                           # Stage Manager: hide recent apps

# Dock apps: just Ghostty. Done once per Mac, so later changes to the Dock stay.
state="$HOME/.local/state/dotfiles"
if [ ! -f "$state/dock-apps-set" ] && [ -d /Applications/Ghostty.app ]; then
  w com.apple.dock persistent-apps -array \
    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file:///Applications/Ghostty.app/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>'
  w com.apple.dock persistent-others -array
  mkdir -p "$state" && date +%F > "$state/dock-apps-set"
fi

# ---- Trackpad (built-in and Magic Trackpad)
for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  w "$d" Clicking -bool true                                            # tap to click
  w "$d" Dragging -bool true                                            # tap-drag, without drag lock
  w "$d" DragLock -bool false
done
w NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 2 || true
w NSGlobalDomain com.apple.swipescrolldirection -bool false             # natural scrolling: off
w com.apple.dock showDesktopGestureEnabled -bool false                  # spread thumb and fingers: off
w com.apple.dock showAppExposeGestureEnabled -bool true                 # App Exposé: swipe down

# ---- Accessibility (the terminal may need Full Disk Access for these)
ua=com.apple.universalaccess
w $ua cursorIsCustomized -bool true
w $ua cursorFill -dict red -float 0.513725 green -float 0.752941 blue -float 0.572549 alpha -float 1
w $ua cursorOutline -dict red -float 0 green -float 0 blue -float 0 alpha -float 1
w $ua systemTranscriptionTranscriptionViewFont -dict fontName -string "JetBrains Mono" fontSize -int 32  # Live Captions

# Restart what reads these.
killall Dock SystemUIServer cfprefsd 2>/dev/null || true
