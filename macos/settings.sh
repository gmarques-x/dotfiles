#!/usr/bin/env bash
# macOS settings: the ones that differ from a fresh Mac, in System Settings
# (Appearance, Desktop & Dock, Control Center, Spotlight, Battery, Displays,
# Accessibility, Trackpad), Finder and screenshots. Run by install.sh; safe to
# run on its own and again. Some take effect only after logging out.

set -uo pipefail
failed=0
w() {
  defaults write "$@" 2>/dev/null || {
    printf '    ! could not set %s %s\n' "$1" "$2" >&2
    failed=1
    return 1
  }
}
wh() { defaults -currentHost write "$@" 2>/dev/null || { printf '    ! could not set %s %s (this Mac)\n' "$1" "$2" >&2; failed=1; }; }

# ---- Appearance
if defaults read NSGlobalDomain AppleAccentColor >/dev/null 2>&1; then
  defaults delete NSGlobalDomain AppleAccentColor || failed=1           # use the system accent
fi
w NSGlobalDomain AppleHighlightColor -string "1.000000 0.937255 0.690196 Yellow"
w NSGlobalDomain AppleShowScrollBars -string WhenScrolling              # scroll bars: when scrolling
w NSGlobalDomain AppleReduceDesktopTinting -bool true                   # wallpaper tinting in windows: off
w NSGlobalDomain NSGlassTintAmount -int 1                               # Liquid Glass: tinted
w NSGlobalDomain NSTableViewDefaultSizeMode -int 1                      # sidebar icon size: small

# ---- Language & Region
w NSGlobalDomain AppleLanguages -array en-US pt-PT
w NSGlobalDomain AppleLocale -string 'en_US@rg=ptzzzz'                   # English (US), region Portugal

# ---- Desktop & Dock
w com.apple.dock orientation -string right
w com.apple.dock tilesize -int 33
w com.apple.dock autohide -bool true
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

# Seed the Dock with the apps that are installed. Done once per Mac,
# so later changes to the Dock stay.
tile() {
  printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://%s/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>' "${1// /%20}"
}
state="$HOME/.local/state/dotfiles"
if [ ! -f "$state/dock-apps-set" ]; then
  tiles=()
  for app in "/Applications/Ghostty.app" "/Applications/Claude.app" \
    "/Applications/ChatGPT.app" "/Applications/Gemini.app" "/Applications/Google Chrome.app" \
    "/System/Applications/System Settings.app"; do
    [ -d "$app" ] && tiles+=("$(tile "$app")")
  done
  if [ "${#tiles[@]}" -gt 0 ]; then
    if w com.apple.dock persistent-apps -array "${tiles[@]}" &&
      w com.apple.dock persistent-others -array; then
      mkdir -p "$state" && date +%F > "$state/dock-apps-set" || failed=1
    fi
  fi
fi

# ---- Control Center and menu bar
w com.apple.menuextra.clock ShowAMPM -bool true
w com.apple.menuextra.clock ShowDate -int 0                              # date: when space allows
w com.apple.menuextra.clock ShowDayOfWeek -bool true
wh com.apple.controlcenter BatteryShowPercentage -bool true             # battery: show percentage
wh com.apple.controlcenter BatteryShowEnergyMode -int 0                 # battery: don't show Energy Mode
wh com.apple.controlcenter Timer -int 8                                 # timer: don't show in menu bar
wh com.apple.controlcenter Spotlight -int 8                             # Spotlight: don't show in menu bar
wh com.apple.Spotlight MenuItemHidden -bool true
wh com.apple.controlcenter ShowSuggestions -bool true
w com.apple.controlcenter RemoteLiveActivitiesEnabled -bool true        # iPhone Live Activities: on
w com.apple.controlcenter ShowLiveActivitiesAtLockScreen -bool false    # ... but not on the lock screen
defaults delete com.apple.campo "NSStatusItem VisibleCC Item-0" 2>/dev/null || true   # Siri AI: not in menu bar

# ---- Spotlight and Siri
# Search results: apps, files, folders, menu items, OneDrive, related content.
w com.apple.Spotlight EnabledPreferenceRules -array Custom.relatedContents \
  "FileProvider.com.microsoft.OneDrive.FileProvider/OneDrive" System.files System.folders \
  System.iphoneApps System.menuItems
w com.apple.assistant.support "Search Queries Data Sharing Status" -int 2   # help Apple improve Search: off

# ---- Finder
w NSGlobalDomain AppleShowAllExtensions -bool true                      # show all filename extensions
w NSGlobalDomain AppleDisableTagBasedIconTinting -bool true             # don't tint folders with tag colours
w com.apple.finder NewWindowTarget -string PfHm                         # new windows: home folder
w com.apple.finder FXPreferredViewStyle -string Nlsv                    # preferred view: List
w com.apple.finder ShowPathbar -bool true
w com.apple.finder ShowStatusBar -bool true
w com.apple.finder FXDefaultSearchScope -string SCcf                    # search the current folder
w com.apple.finder _FXSortFoldersFirst -bool true                       # folders on top: in windows
w com.apple.finder _FXSortFoldersFirstOnDesktop -bool true              # ... and on the desktop
w com.apple.finder ShowHardDrivesOnDesktop -bool false
w com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
w com.apple.finder ShowRemovableMediaOnDesktop -bool false
w com.apple.finder FXRemoveOldTrashItems -bool true                     # empty Trash items after 30 days
w com.apple.finder WarnOnEmptyTrash -bool false
# Toolbar: Back, View, Share, Action, Search (no Group or Tags).
w com.apple.finder "NSToolbar Configuration Browser" '<dict>
  <key>TB Display Mode</key><integer>2</integer>
  <key>TB Icon Size Mode</key><integer>1</integer>
  <key>TB Is Shown</key><true/>
  <key>TB Size Mode</key><integer>1</integer>
  <key>TB Item Identifiers</key><array>
    <string>com.apple.finder.BACK</string><string>com.apple.finder.SWCH</string>
    <string>NSToolbarSpaceItem</string><string>com.apple.finder.SHAR</string>
    <string>com.apple.finder.ACTN</string><string>NSToolbarSpaceItem</string>
    <string>com.apple.finder.SRCH</string>
  </array>
</dict>'

# ---- Screenshots
w com.apple.screencapture target -string clipboard
w com.apple.screencapture target-screenshot -string clipboard
w com.apple.screencapture target-screenrecording -string file

# ---- Battery: turn the display off after 10 minutes on battery too.
# Changing it asks for your password, so only when it differs.
battery_displaysleep() { pmset -g custom | awk '/^Battery Power/{b=1} /^AC Power/{b=0} b && $1=="displaysleep"{print $2}'; }
if [ "$(battery_displaysleep)" != 10 ]; then
  sudo pmset -b displaysleep 10 || { printf '    ! could not set the battery display sleep\n' >&2; failed=1; }
fi

# ---- Displays: built-in display at "More Space" (1920 × 1243), via displayplacer.
if command -v displayplacer >/dev/null; then
  builtin_id="$(displayplacer list | awk '/^Persistent screen id:/{id=$4} /^Type:.*built in/{print id; exit}')"
  if [ -n "$builtin_id" ]; then
    displayplacer "id:$builtin_id res:1920x1243 scaling:on" >/dev/null 2>&1 \
      || { printf '    ! could not set the built-in display to 1920 x 1243\n' >&2; failed=1; }
  fi
else
  printf '    ! skipped the display resolution: displayplacer is not installed (brew install displayplacer)\n' >&2
  failed=1
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

# ---- Accessibility
# macOS lets only apps with Full Disk Access write this domain, so check once
# and say how to fix it rather than failing on every key.
ua=com.apple.universalaccess
if defaults write $ua dotfilesWriteProbe -bool true 2>/dev/null; then
  defaults delete $ua dotfilesWriteProbe 2>/dev/null
  w $ua cursorIsCustomized -bool true
  w $ua cursorFill -dict red -float 0.654902 green -float 0.752941 blue -float 0.501961 alpha -float 1   # Everforest green #A7C080
  w $ua cursorOutline -dict red -float 0 green -float 0 blue -float 0 alpha -float 1
  w $ua systemTranscriptionTranscriptionViewFont -dict fontName -string "JetBrains Mono" fontSize -int 32  # Live Captions
else
  failed=1
  printf '    ! skipped Accessibility (pointer colour, Live Captions font): this terminal needs Full Disk Access.\n' >&2
  printf '      Turn it on in System Settings > Privacy & Security > Full Disk Access, quit and reopen\n' >&2
  printf '      the terminal, then run: %s\n' "$0" >&2
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
fi

# Restart what reads these.
killall Dock Finder ControlCenter SystemUIServer cfprefsd 2>/dev/null || true

exit "$failed"
