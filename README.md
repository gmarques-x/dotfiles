# dotfiles

A baseline macOS setup for zsh, Ghostty and terminal tools.

## Install

On a fresh Mac, open Terminal and run:

```sh
git clone https://github.com/gmarques-x/dotfiles.git ~/Developer/dotfiles
~/Developer/dotfiles/install.sh
```

(On a brand-new Mac, `git` will first ask to install the Command Line Tools; accept, then run the two lines again.)

The installer runs these steps in order, and is safe to run again; finished steps are skipped:

1. **Homebrew**: installs it if missing (asks for your Mac password).
2. **OneDrive**: installs it, opens it, and **waits** while you sign in and let it sync. Press Return when the wizard is done.
3. **Terminal tools and apps**: everything in the [`Brewfile`](Brewfile): Ghostty, Google Chrome, the JetBrains Mono and SF Pro fonts, starship, eza, bat, yazi, zoxide, fzf, ripgrep, fd, jq, fastfetch, gh, the zsh plugins, and the AI apps:

   | | Desktop app | CLI |
   | --- | --- | --- |
   | Claude | Claude | Claude Code (`claude`) |
   | ChatGPT | ChatGPT | Codex (`codex`) |
   | Gemini | Gemini (macOS 15+, Apple Silicon) | Antigravity CLI (`agy`), Google's replacement for Gemini CLI |

   An app that's already in /Applications but wasn't installed by Homebrew (Chrome, Claude, ...) is left alone. Sign in to each app and CLI on first launch.
4. **Configs**: links them into place (see below).
5. **`~/.ssh`**: becomes a link to the `ssh` folder in your OneDrive. Anything already in `~/.ssh` that OneDrive doesn't have is copied across first. If you have more than one OneDrive folder (personal and work), it asks which one.
6. **Git and GitHub**: asks for your name and email, writes the git identity, creates an `id_ed25519` key if there isn't one, logs in to GitHub with `gh` in the browser, and uploads the key to GitHub as both an authentication and a signing key. Commits and tags are signed with that key.

7. **macOS settings**: [`macos/settings.sh`](macos/settings.sh) applies the settings that differ from a fresh Mac:
   - **Appearance**: blue accent, `#434C5E` highlight, scroll bars only while scrolling, no wallpaper tinting, tinted Liquid Glass
   - **Desktop & Dock**: Dock on the right, small, Scale effect, minimise into the app icon, no indicators or recents, only Ghostty and Chrome in it (set once); windows grouped by app; no desktop icons or widgets; documents never open as tabs; closing asks to keep changes
   - **Accessibility**: Everforest green pointer (`#A7C080`), Live Captions in JetBrains Mono 32
   - **Trackpad**: tap to click, tap-drag, natural scrolling off, App Exposé gesture on, Show Desktop gesture off
   - **Control Center and menu bar**: battery percentage on, Energy Mode, Timer, Spotlight and Siri AI not in the menu bar, iPhone Live Activities on but not on the lock screen
   - **Spotlight and Siri**: results only from apps, files, folders, menu items, OneDrive and related content; "Help Apple improve Search" off
   - **Finder**: all filename extensions, folders on top (windows and desktop), no disks on the desktop, new windows open your home folder, search the current folder, Trash emptied after 30 days without a warning, no tag tint on folders, small sidebar icons, toolbar without Group and Tags
   - **Screenshots**: saved to a file, not the clipboard
   - **Battery**: display turns off after 10 minutes on battery (asks for your password when it changes it)
   - **Displays**: built-in display at "More Space", 1920 × 1243 (with `displayplacer` from the Brewfile)

   Run it on its own with `macos/settings.sh`. Some settings need a log out. If the Accessibility ones report an error, give your terminal Full Disk Access and run it again.

8. **Debloat**: lists whichever of GarageBand, iMovie, Keynote, Numbers and Pages are installed, plus GarageBand's sound library (several GB, kept if Logic Pro is installed), and after you confirm moves them to the Trash. They can be reinstalled from the App Store. The other built-in apps (Safari, Mail, Music, Photos, News, Stocks, ...) are on the read-only system volume, so macOS doesn't let them be removed.

Options, as environment variables:

| Variable | Effect |
| --- | --- |
| `ONEDRIVE_SSH_DIR=name` | Use a different folder in OneDrive instead of `ssh` |
| `DOTFILES_SKIP="onedrive ssh github macos debloat"` | Skip any of those steps |

## What goes where

| In this repo | Linked as |
| --- | --- |
| `zsh/.zshenv` | `~/.zshenv` (sets `ZDOTDIR=~/.config/zsh`) |
| `zsh/` | `~/.config/zsh` |
| `ghostty/` | `~/.config/ghostty` |
| `starship/starship.toml`, `starship-plain.toml` | `~/.config/starship.toml`, `~/.config/starship-plain.toml` |
| `eza/`, `bat/`, `yazi/` | `~/.config/eza`, `~/.config/bat`, `~/.config/yazi` |
| `git/` | `~/.config/git` |
| `ssh/config` | copied to `~/.ssh/config` only if there isn't one |

Because the configs are links, editing a file in `~/.config` edits the repo. Commit from here.

Anything replaced (an old `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.ssh`, ...) is moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never deleted. `git/local` and `git/allowed_signers` are generated per Mac and not tracked.

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
| `95-fetch` | fastfetch once per new window (`DOTFILES_NO_FETCH=1` turns it off) |
| `98-highlight` | syntax highlighting |

Put machine-specific settings in `zsh/conf.d/local.zsh`; git ignores it.

## Ghostty

JetBrains Mono 12, Nord colours, and ⌃` toggles a quick terminal from any app (allow Ghostty under System Settings › Privacy & Security › Accessibility). Left ⌥ acts as Alt.

## OneDrive and SSH

Keys stay in OneDrive, so every Mac signed in to the same account shares them. In Finder, right-click the OneDrive `ssh` folder and choose **Always Keep on This Device** so the keys are never cloud-only placeholders.
