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
3. **Terminal tools**: everything in the [`Brewfile`](Brewfile): Ghostty, JetBrains Mono, starship, eza, bat, yazi, zoxide, fzf, ripgrep, fd, jq, fastfetch, gh, and the zsh plugins.
4. **Configs**: links them into place (see below).
5. **`~/.ssh`**: becomes a link to the `ssh` folder in your OneDrive. Anything already in `~/.ssh` that OneDrive doesn't have is copied across first. If you have more than one OneDrive folder (personal and work), it asks which one.
6. **Git and GitHub**: asks for your name and email, writes the git identity, creates an `id_ed25519` key if there isn't one, logs in to GitHub with `gh` in the browser, and uploads the key to GitHub as both an authentication and a signing key. Commits and tags are signed with that key.

Options, as environment variables:

| Variable | Effect |
| --- | --- |
| `ONEDRIVE_SSH_DIR=name` | Use a different folder in OneDrive instead of `ssh` |
| `DOTFILES_SKIP="onedrive ssh github"` | Skip any of those steps |

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
| `20-aliases` | `ls`/`ll`/`lt` (eza), `cat` (bat), `y` or `finder` (yazi that leaves you in the folder you quit in), `zalias`, `zedit`, `cls` |
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
