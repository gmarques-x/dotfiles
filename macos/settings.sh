#!/usr/bin/env bash
# macOS settings: the ones that differ from a fresh Mac, in System Settings
# (Appearance, Desktop & Dock, Control Center, Spotlight, Battery, Displays,
# Accessibility, Keyboard, Trackpad), Finder and screenshots. Run by install.sh; safe to
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

# ---- Appearance (light or dark, the accent, folder and highlight colours and the
# wallpaper come from `theme`)
w NSGlobalDomain AppleShowScrollBars -string WhenScrolling              # scroll bars: when scrolling
w NSGlobalDomain AppleReduceDesktopTinting -bool true                   # wallpaper tinting in windows: off
w NSGlobalDomain NSGlassTintAmount -int 1                               # Liquid Glass: tinted
w NSGlobalDomain NSTableViewDefaultSizeMode -int 1                      # sidebar icon size: small

# ---- Language & Region
w NSGlobalDomain AppleLanguages -array en-US pt-PT
w NSGlobalDomain AppleLocale -string 'en_US@rg=ptzzzz'                   # English (US), region Portugal

# ---- Desktop & Dock
w com.apple.dock orientation -string right
w com.apple.dock tilesize -int 34
w com.apple.dock magnification -bool false
w com.apple.dock autohide -bool true
w com.apple.dock autohide-delay -float 0                                # show it straight away
w com.apple.dock autohide-time-modifier -float 0.3                      # quick slide
w com.apple.dock mineffect -string scale
w com.apple.dock minimize-to-application -bool true
w com.apple.dock show-process-indicators -bool true                     # dots under open apps
w com.apple.dock show-recents -bool false                               # no suggested or recent apps
w com.apple.dock expose-group-apps -bool true                           # Mission Control: group windows by app
w com.apple.dock mru-spaces -bool true                                  # rearrange Spaces by most recent use
for corner in tl tr bl br; do                                           # hot corners: none
  w com.apple.dock "wvous-$corner-corner" -int 1
  w com.apple.dock "wvous-$corner-modifier" -int 0
done
w NSGlobalDomain AppleWindowTabbingMode -string manual                  # prefer tabs: never
w NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool true                # ask to keep changes when closing
w com.apple.WindowManager StandardHideDesktopIcons -bool true           # show items on desktop: off
w com.apple.WindowManager StandardHideWidgets -bool true                # show widgets on desktop: off
w com.apple.WindowManager StageManagerHideWidgets -bool true
w com.apple.WindowManager HideDesktop -bool true
w com.apple.WindowManager EnableStandardClickToShowDesktop -bool false  # click wallpaper to show desktop: off
w com.apple.WindowManager EnableDesktopClickToShowDesktop -bool false
w com.apple.WindowManager GloballyEnabled -bool false                   # Stage Manager: off
w com.apple.WindowManager EnableStageManagerDesktopIcons -bool false
w com.apple.WindowManager ShowRecentApps -bool false
w com.apple.WindowManager EnableTiledWindowMargins -bool false          # tiled windows have margins: off
w com.apple.WindowManager AppWindowGroupingBehavior -int 0              # Stage Manager: one window at a time
w com.apple.WindowManager AutoHide -bool true                           # Stage Manager: hide recent apps

# Seed the Dock with the apps that are installed, and nothing on the right of
# the separator (no Downloads). Done once per Mac, so later changes to the Dock stay.
tile() {
  printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://%s/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>' "${1// /%20}"
}
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
if [ ! -f "$state/dock-apps-set" ]; then
  tiles=()
  for app in "/Applications/Ghostty.app" \
    "/Applications/ChatGPT.app" "/Applications/Google Chrome.app" \
    "/System/Applications/System Settings.app"; do
    [ -d "$app" ] && tiles+=("$(tile "$app")")
  done
  if { [ "${#tiles[@]}" -eq 0 ] || w com.apple.dock persistent-apps -array "${tiles[@]}"; } &&
    w com.apple.dock persistent-others -array; then
    mkdir -p "$state" && date +%F > "$state/dock-apps-set" || failed=1
  fi
fi

# ---- Control Center and menu bar
w com.apple.menuextra.clock IsAnalog -bool false                        # digital clock
w com.apple.menuextra.clock ShowAMPM -bool true
w com.apple.menuextra.clock ShowDate -int 0                              # date: when space allows
w com.apple.menuextra.clock ShowDayOfWeek -bool true
wh com.apple.controlcenter BatteryShowPercentage -bool true             # battery: show percentage
wh com.apple.controlcenter BatteryShowEnergyMode -int 0                 # battery: don't show Energy Mode
wh com.apple.controlcenter FocusModes -int 8                            # Focus: show in menu bar when active
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
w com.apple.finder NewWindowTargetPath -string "file://$HOME/"
w com.apple.finder FXEnableExtensionChangeWarning -bool false           # no warning when changing an extension
w com.apple.finder QuitMenuItem -bool true                              # ⌘Q quits Finder
w com.apple.finder ShowRecentTags -bool false                           # no Tags in the sidebar
w com.apple.finder FavoriteTagNames -array ""                           # ... nor in menus
w com.apple.desktopservices DSDontWriteNetworkStores -bool true         # no .DS_Store on network drives
w com.apple.desktopservices DSDontWriteUSBStores -bool true             # ... nor on USB drives
w NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true          # Save dialogs open expanded
w NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
w NSGlobalDomain PMPrintingExpandedStateForPrint -bool true             # Print dialogs open expanded
w NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
# Sidebar favourites: Applications, then the home folder, then Developer.
mkdir -p "$HOME/Developer"
swift "$(dirname "$0")/sidebar.swift" /Applications "$HOME" "$HOME/Developer" 2>/dev/null \
  || { printf '    ! could not arrange the Finder sidebar\n' >&2; failed=1; }
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

# ---- Screenshots: to the clipboard; recordings (and the "save to file"
# shortcuts) go to ~/Pictures/Screenshots, as PNG without the window shadow.
mkdir -p "$HOME/Pictures/Screenshots"
w com.apple.screencapture target -string clipboard
w com.apple.screencapture target-screenshot -string clipboard
w com.apple.screencapture target-screenrecording -string file
w com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
w com.apple.screencapture type -string png
w com.apple.screencapture disable-shadow -bool true

# ---- Keyboard shortcuts (System Settings › Keyboard › Keyboard Shortcuts)
# hotkey ID on|off CHAR KEYCODE MODIFIERS; modifiers: ⇧ 131072, ⌃ 262144,
# ⌥ 524288, ⌘ 1048576 (added together).
hotkey() {
  w com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
    "<dict><key>enabled</key><$2/><key>value</key><dict><key>parameters</key><array><integer>$3</integer><integer>$4</integer><integer>$5</integer></array><key>type</key><string>standard</string></dict></dict>"
}
hotkey_off() { w com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" "<dict><key>enabled</key><false/></dict>"; }
hotkey 29  true 97  0 1179648   # Screenshots: the whole screen to the clipboard, ⌘⇧A
hotkey 31  true 115 1 1179648   # Screenshots: a selected area to the clipboard, ⌘⇧S
hotkey 184 true 100 2 1179648   # Screenshots: the options toolbar, ⌘⇧D
hotkey_off 36                   # Show Desktop (F11): off
hotkey_off 37                   # Show Desktop, its other key: off
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

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

# ---- Keyboard: fast key repeat, and no automatic text changes
w NSGlobalDomain KeyRepeat -int 2
w NSGlobalDomain InitialKeyRepeat -int 15                               # short delay before repeating
w NSGlobalDomain ApplePressAndHoldEnabled -bool false                   # hold a key to repeat it, not for accents
w NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false       # no autocorrect
w NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false
w NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false           # no automatic capitals
w NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false         # no smart dashes
w NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false        # no smart quotes
w NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false       # no period on double space

# ---- Trackpad (built-in and Magic Trackpad)
for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  w "$d" Clicking -bool true                                            # tap to click
  w "$d" Dragging -bool true                                            # tap-drag, without drag lock
  w "$d" DragLock -bool false
  w "$d" TrackpadThreeFingerVertSwipeGesture -int 2                     # three fingers down: App Exposé
done
w NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 2 || true
# Tap to click on the login screen too (asks for your password, once).
if [ "$(defaults read /Library/Preferences/.GlobalPreferences com.apple.mouse.tapBehavior 2>/dev/null)" != 1 ]; then
  sudo defaults write /Library/Preferences/.GlobalPreferences com.apple.mouse.tapBehavior -int 1 \
    || { printf '    ! could not set tap to click on the login screen\n' >&2; failed=1; }
fi
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
