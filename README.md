# dotfiles

A baseline macOS setup for zsh, Ghostty and terminal tools.

## Install

On a fresh Mac, open Terminal and run:

```sh
git clone https://github.com/gmarques-x/dotfiles.git ~/Developer/dotfiles
~/Developer/dotfiles/install.sh
```

(On a brand-new Mac, `git` will first ask to install the Command Line Tools; accept, then run the two lines again.)

The repository is private, so `git clone` asks you to sign in: give your GitHub username and, as the password, a [personal access token](https://github.com/settings/tokens) with `repo` access (GitHub no longer accepts account passwords there). The installer then logs you in to GitHub with `gh` for everything after.

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
5. **`~/.ssh`**: becomes a link to the `dot-ssh` folder in your OneDrive (a link to any other folder is replaced). Anything already in `~/.ssh` that OneDrive doesn't have is copied across first. If you have more than one OneDrive folder (personal and work), it asks which one.
6. **`~/.claude`**: Claude Code's folder (settings, `CLAUDE.md`, skills, memory) becomes a link to the `claude` folder in your OneDrive, the same way as `~/.ssh`. `~/.claude.json` (app state and caches) stays on the Mac. Codex's `~/.codex/AGENTS.md` and Gemini's `~/.gemini/GEMINI.md` become links to the team instructions kept in `~/.claude/team/teammates/`.
7. **Git and GitHub**: asks for your name and email, logs in to GitHub with `gh` in the browser, then picks your SSH key: `~/.ssh/id_ed25519` if it exists, otherwise any key in `~/.ssh` that GitHub already has for logging in (pointed at github.com in `~/.ssh/config.d/github`). It creates a new `id_ed25519` only when there's none, and asks first if `~/.ssh` isn't linked to OneDrive. It writes the git identity and makes sure the key is on GitHub as both an authentication and a signing key. Commits and tags are signed with that key.

8. **macOS settings**: [`macos/settings.sh`](macos/settings.sh) applies the settings that differ from a fresh Mac:
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

9. **Debloat**: lists whichever of GarageBand, iMovie, Keynote, Numbers and Pages are installed, plus GarageBand's sound library (several GB, kept if Logic Pro is installed), and after you confirm moves them to the Trash. They can be reinstalled from the App Store. The other built-in apps (Safari, Mail, Music, Photos, News, Stocks, ...) are on the read-only system volume, so macOS doesn't let them be removed.

Options, as environment variables:

| Variable | Effect |
| --- | --- |
| `ONEDRIVE_SSH_DIR=name` | Use a different folder in OneDrive instead of `dot-ssh` |
| `ONEDRIVE_CLAUDE_DIR=name` | Use a different folder in OneDrive instead of `claude` |
| `DOTFILES_SKIP="onedrive ssh claude github macos debloat"` | Skip any of those steps |

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

Anything replaced (an old `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.ssh`, `~/.claude`, ...) is moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never deleted. `git/local` and `git/allowed_signers` are generated per Mac and not tracked.

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

## OneDrive: SSH and Claude Code

Keys stay in OneDrive, so every Mac signed in to the same account shares them. In Finder, right-click the OneDrive `dot-ssh` and `claude` folders and choose **Always Keep on This Device** so they are never cloud-only placeholders.

The `claude` folder also holds live session files, so use it from one Mac at a time; two Macs running Claude Code against it at once make OneDrive conflict copies.
