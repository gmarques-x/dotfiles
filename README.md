# dotfiles

A baseline macOS setup for zsh, Ghostty and terminal tools.

## Install

On a fresh Mac, open Terminal and run:

```sh
git clone https://github.com/gmarques-x/dotfiles.git ~/Developer/dotfiles
~/Developer/dotfiles/install.sh
```

(On a brand-new Mac, `git` will first ask to install the Command Line Tools; accept, then run the two lines again.)

You can clone the public repository without signing in. The installer asks you to sign in with `gh` during Git and GitHub setup.

The installer runs these steps in order, and is safe to run again; finished steps are skipped:

1. **Homebrew**: installs it if missing (asks for your Mac password).
2. **OneDrive**: installs it, opens it, and **waits** while you sign in and let it sync. Press Return when the wizard is done.
3. **Terminal tools and apps**: everything in the [`Brewfile`](Brewfile): Ghostty, Google Chrome, the JetBrains Mono and SF Pro fonts, starship, eza, bat, yazi, zoxide, fzf, ripgrep, fd, jq, fastfetch, gh, the zsh plugins, the ChatGPT desktop app, and the Codex CLI (`codex`).

   An app that's already in /Applications but wasn't installed by Homebrew (such as Chrome or ChatGPT) is left alone. Sign in to each app and CLI on first launch.
4. **Folders and configs**: creates `~/Developer` and the XDG folders (`~/.config`, `~/.cache`, `~/.local/share`, `~/.local/state`, `~/.local/bin`), links the configs into place (see below), and moves dotfiles that zsh, less and Python used to leave in `~/` (`.zsh_history`, `.zsh_sessions`, `.zcompdump*`, `.lesshst`, `.python_history`) to their XDG places or the backup.
5. **`~/.ssh`**: becomes a link to the `dot-ssh` folder in your OneDrive (a link to any other folder is replaced). Anything already in `~/.ssh` that OneDrive doesn't have is copied across first. If you have more than one OneDrive folder (personal and work), it asks which one.
6. **Codex**: Codex's folder (settings, memory, sessions) lives in `~/.config/codex` (`CODEX_HOME`, set in `zsh/.zshenv`) and is a link to the `codex` folder in your OneDrive, the same way as `~/.ssh`. The OneDrive folder is created if it doesn't exist. Anything in an old `~/.codex` that OneDrive doesn't have is copied across, and `~/.codex` goes to the backup. Apps opened from the Dock or Finder don't read zsh's files, so a login item (`~/Library/LaunchAgents/local.dotfiles.codex-home.plist`) sets `CODEX_HOME` for them at every login; apps already open when you install need a restart.
7. **Git and GitHub**: asks for your name and email, logs in to GitHub with `gh` in the browser, then picks your SSH key: `~/.ssh/id_ed25519` if it exists, otherwise any key in `~/.ssh` that GitHub already has for logging in (pointed at github.com in `~/.ssh/config.d/github`). It creates a new `id_ed25519` only when there's none, and asks first if `~/.ssh` isn't linked to OneDrive. It writes the git identity and makes sure the key is on GitHub as both an authentication and a signing key. Commits and tags are signed with that key.

8. **macOS settings**: [`macos/settings.sh`](macos/settings.sh) applies these preferences:
   - **Appearance**: system accent, yellow highlight, scroll bars only while scrolling, no wallpaper tinting, tinted Liquid Glass
   - **Language & Region**: English (US) first, Portuguese (Portugal) second, with Portugal as the region
   - **Desktop & Dock**: small, auto-hiding Dock on the right, Scale effect, minimise into the app icon, no indicators or recents. On the first run, it pins Ghostty, ChatGPT, Chrome and System Settings if installed. Mission Control groups windows by app, the desktop hides icons and widgets, documents use tabs only when requested, and closing asks whether to keep changes.
   - **Accessibility**: Everforest green pointer (`#A7C080`), Live Captions in JetBrains Mono 32
   - **Trackpad**: tap to click, tap-drag, natural scrolling off, App Exposé gesture on, Show Desktop gesture off
   - **Control Center and menu bar**: clock shows the day of the week and AM/PM, with the date when space allows. The menu bar shows battery percentage and hides Energy Mode, Timer, Spotlight and Siri AI. iPhone Live Activities are enabled and hidden on the lock screen.
   - **Spotlight and Siri**: results only from apps, files, folders, menu items, OneDrive and related content; "Help Apple improve Search" off
   - **Finder**: List view with the path and status bars visible, all filename extensions, folders on top (windows and desktop), no disks on the desktop, new windows open your home folder, search the current folder, Trash emptied after 30 days without a warning, no tag tint on folders, small sidebar icons, toolbar without Group and Tags
   - **Screen capture**: screenshots go to the clipboard and screen recordings save to a file
   - **Battery**: display turns off after 10 minutes on battery (asks for your password when it changes it)
   - **Displays**: built-in display at "More Space", 1920 × 1243 (with `displayplacer` from the Brewfile)

   Run it on its own with `macos/settings.sh`. Some settings need a log out. If the Accessibility ones report an error, give your terminal Full Disk Access and run it again.

   In System Settings, choose **Google Chrome** under **Desktop & Dock → Default web browser** and **Portuguese** under **Keyboard → Text Input → Edit**. Set up your Finder sidebar favorites in Finder if needed.

9. **Debloat**: lists whichever of GarageBand, iMovie, Keynote, Numbers and Pages are installed, plus GarageBand's sound library (several GB, kept if Logic Pro is installed), and after you confirm moves them to the Trash. They can be reinstalled from the App Store. The other built-in apps (Safari, Mail, Music, Photos, News, Stocks, ...) are on the read-only system volume, so macOS doesn't let them be removed.

Options, as environment variables:

| Variable | Effect |
| --- | --- |
| `ONEDRIVE_SSH_DIR=name` | Use a different folder in OneDrive instead of `dot-ssh` |
| `ONEDRIVE_CODEX_DIR=name` | Use a different folder in OneDrive instead of `codex` |
| `DOTFILES_SKIP="onedrive ssh codex github macos debloat"` | Skip any of those steps |

## What goes where

| In this repo | Linked as |
| --- | --- |
| `zsh/.zshenv` | `~/.zshenv` (sets `ZDOTDIR=~/.config/zsh`) |
| `zsh/` | `~/.config/zsh` |
| `ghostty/` | `~/.config/ghostty` |
| `starship/starship.toml`, `starship-plain.toml` | `~/.config/starship.toml`, `~/.config/starship-plain.toml` |
| `eza/`, `bat/`, `yazi/`, `fastfetch/` | `~/.config/eza`, `~/.config/bat`, `~/.config/yazi`, `~/.config/fastfetch` |
| `git/` | `~/.config/git` |
| `ssh/config` | copied to `~/.ssh/config` only if there isn't one |

Because the configs are links, editing a file in `~/.config` edits the repo. Commit from here.

Anything replaced (an old `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.ssh`, `~/.codex`, `~/.zsh_history`, ...) is moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never deleted. `git/local` and `git/allowed_signers` are generated per Mac and not tracked.

## zsh

`.zshrc` loads `zsh/conf.d/*.zsh` in order:

| File | What |
| --- | --- |
| `10-history` | 50k-line shared history in `~/.local/state/zsh/history` |
| `20-aliases` | `ls`/`ll`/`lt` (eza), `cat` (bat), `finder` (yazi that leaves you in the folder you quit in), `zalias`, `zedit`, `cls` |
| `30-completion` | completion with Homebrew's completions, case-insensitive, menu select |
| `40-tools` | zoxide as `cd`; fzf on ⌃R history, ⌃T files, ⌥C folders |
| `85-autosuggest` | history suggestions; → accepts |
| `90-prompt` | starship (icon-free version in Terminal.app) |
| `95-fetch` | fastfetch once per new window, with a dotted ghost for a logo (`DOTFILES_NO_FETCH=1` turns it off) |
| `98-highlight` | syntax highlighting |

Put machine-specific settings in `zsh/conf.d/local.zsh`; git ignores it.

## Ghostty

JetBrains Mono 12, Nord colours, and ⌃` toggles a quick terminal from any app (allow Ghostty under System Settings › Privacy & Security › Accessibility). Left ⌥ acts as Alt.

## OneDrive: SSH and Codex

Keys stay in OneDrive, so every Mac signed in to the same account shares them. In Finder, right-click the OneDrive `dot-ssh` and `codex` folders and choose **Always Keep on This Device** so they are never cloud-only placeholders.

The `codex` folder also holds live session files, so use it from one Mac at a time; two Macs running Codex against it at once make OneDrive conflict copies.

