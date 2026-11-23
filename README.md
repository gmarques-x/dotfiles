# dotfiles

A baseline macOS setup for zsh, Ghostty, terminal tools and apps, with one theme across all of them.

## Install

On a fresh Mac, open Terminal and run:

```sh
curl -fsSL https://raw.githubusercontent.com/gmarques-x/dotfiles/main/install.sh | bash
```

It installs Apple's Command Line Tools first (click **Install** in the window that opens; the script waits), clones this repo to `~/Developer/dotfiles`, and carries on from there. On a Mac that already has the repo, run `~/Developer/dotfiles/install.sh` instead.

You can clone the public repository without signing in. The installer asks you to sign in with `gh` during Git and GitHub setup.

The installer runs these steps in order, and is safe to run again; finished steps are skipped. Before each step it shows the whole list: ✓ done, ! done with warnings, – skipped, ▸ running now, ○ still to come.

1. **Command Line Tools and Homebrew**: installs each if missing (Homebrew asks for your Mac password).
2. **OneDrive**: installs it, opens it, and **waits** while you sign in and let it sync. Press Return when the wizard is done.
3. **Apps and command-line tools**:
   - Fonts and command-line tools from the [`Brewfile`](Brewfile), always: JetBrains Mono, SF Pro, starship, eza, bat, zoxide, fzf, ripgrep, fd, jq, wget, watch, htop, dust, duf, glow, fastfetch, gh, git-delta, atuin, the zsh plugins, Neovim (with tree-sitter for LazyVim), lazygit, Python, mtr, nmap, ipcalc, and yazi with its preview helpers (poppler, sevenzip, resvg, ffmpeg, imagemagick).
   - Then the apps in [`Brewfile.apps`](Brewfile.apps), as a list to choose from: Ghostty, Google Chrome, VS Code, Keka, balenaEtcher, WhatsApp, Microsoft Teams, Steam, Modrinth, Vorssaint, Wireshark, ChatGPT, Codex, Claude and Claude Code. **Space** marks or unmarks an app, **⌃A** marks all, **Return** installs the marked ones (none marked: no apps). The first time nothing is marked; after that, your last choice is (it's kept in `~/.local/state/dotfiles/apps`, and `dots-sync` reuses it without asking). Unmarking an app doesn't uninstall it.
   - Rosetta is installed first when Steam is chosen (Steam is an Intel app), and Chrome is made the default browser when chosen (macOS asks you to confirm).
   - An app that's already in /Applications but wasn't installed by Homebrew is left alone. Sign in to each app and CLI on first launch.
4. **Folders and configs**: creates `~/Developer`, `~/.hushlogin` and the XDG folders (`~/.config`, `~/.cache`, `~/.local/share`, `~/.local/state`, `~/.local/bin`), links the configs into place (see below), and moves dotfiles that used to land in `~/` (`.zsh_history`, `.zsh_sessions`, `.zcompdump*`, `.lesshst`, `.python_history`, `.vimrc`, `.vim`, `.viminfo`, `.wget-hsts`, `.atuin`) to their XDG places or the backup. Claude Code's settings live in `~/.config/claude` (`CLAUDE_CONFIG_DIR`). The installer copies missing files from an existing `~/.claude`, backs up the old folder or link, and links `~/.claude` to `~/.config/claude`. It also migrates a legacy `~/.claude.json` and backs it up. Apps opened from the Dock or Finder don't read zsh's files, so a login item (`~/Library/LaunchAgents/local.dotfiles.environment.plist`) sets `CODEX_HOME` and `CLAUDE_CONFIG_DIR` for them at every login (apps already open when you install need a restart). It also imports your zsh history into atuin (once), installs yazi's plugins and flavors (`ya pkg install`), and downloads Neovim's plugins (LazyVim).
5. **`~/.ssh`**: becomes a link to the `dot-ssh` folder in your OneDrive (a link to any other folder is replaced). Anything already in `~/.ssh` that OneDrive doesn't have is copied across first. If you have more than one OneDrive folder (personal and work), it asks which one.
6. **Codex**: Codex's folder (settings, memory, sessions) lives in `~/.config/codex` (`CODEX_HOME`, set in `zsh/.zshenv`) and is a link to the `codex` folder in your OneDrive, the same way as `~/.ssh`. The OneDrive folder is created if it doesn't exist. Anything in an old `~/.codex` that OneDrive doesn't have is copied across, and `~/.codex` goes to the backup. Codex CLI and app-server SQLite databases live on this Mac in `~/.local/state/codex/sqlite` (`CODEX_SQLITE_HOME`). On an existing installation, quit ChatGPT and Codex CLI sessions once. The login item waits for the databases to close, copies and checks them, then enables the local directory for new launches.
7. **Git and GitHub**: asks for your name and email, logs in to GitHub with `gh` in the browser, then picks your SSH key: `~/.ssh/id_ed25519` if it exists, otherwise any key in `~/.ssh` that GitHub already has for logging in (pointed at github.com in `~/.ssh/config.d/github`). It creates a new `id_ed25519` only when there's none, and asks first if `~/.ssh` isn't linked to OneDrive. It writes the git identity and makes sure the key is on GitHub as both an authentication and a signing key. Commits and tags are signed with that key.

8. **macOS settings**: [`macos/settings.sh`](macos/settings.sh) applies these preferences:
   - **Appearance**: scroll bars only while scrolling, no wallpaper tinting, tinted Liquid Glass. Light or dark, the accent and folder colours, and the wallpaper come from the theme (step 10). Text highlights are always yellow.
   - **Language & Region**: English (US) first, Portuguese (Portugal) second, with Portugal as the region
   - **Dock**: on the right, size 34, no magnification, hides automatically with no delay and a quick slide, Scale effect, minimise into the app icon, dots under open apps, no suggested or recent apps. On the first run it pins Ghostty, ChatGPT, Chrome and System Settings (those installed) and leaves nothing on the right of the separator (no Downloads).
   - **Desktop and windows**: no icons or widgets on the desktop; nothing shows the desktop (clicking the wallpaper, the F11 shortcuts, the spread-fingers gesture and hot corners are all off); Stage Manager off; Mission Control groups windows by app and rearranges Spaces by recent use; documents use tabs only when requested, and closing asks whether to keep changes.
   - **Keyboard**: fast key repeat with a short delay, held keys repeat (no accent popup), no autocorrect, automatic capitals, smart dashes, smart quotes or double-space period
   - **Keyboard shortcuts**: ⌥⇧H tiles the active window left, ⌥⇧J bottom, ⌥⇧K top, and ⌥⇧L right. ⌥⇧U and ⌥⇧I tile to the top-left and top-right quarters. ⌥⇧N and ⌥⇧M tile to the bottom-left and bottom-right quarters. ⌥⇧Return fills the desktop. ⌘⇧A copies the whole screen to the clipboard, ⌘⇧S copies a selected area to the clipboard, ⌘⇧D opens the screenshot options. (⌘S stays Save.)
   - **Accessibility**: Everforest green pointer (`#A7C080`), Live Captions in JetBrains Mono 32
   - **Trackpad**: tap to click (also on the login screen), tap-drag, natural scrolling off, three fingers down for App Exposé
   - **Control Center and menu bar**: digital clock with the day of the week and AM/PM, the date when space allows; Focus shown when on; battery percentage; Energy Mode, Timer, Spotlight and Siri AI hidden. iPhone Live Activities are enabled and hidden on the lock screen.
   - **Spotlight and Siri**: results only from apps, files, folders, menu items, OneDrive and related content; "Help Apple improve Search" off
   - **Finder**: List view with the path and status bars, all filename extensions, folders on top (windows and desktop), no disks on the desktop, new windows open your home folder, search the current folder, no warning when changing an extension, ⌘Q quits Finder, Trash emptied after 30 days without a warning, no tags in the sidebar or tag tint on folders, small sidebar icons, toolbar without the Group and Tags buttons. The sidebar's Favourites start with Applications, then your home folder, then Developer ([`macos/sidebar.swift`](macos/sidebar.swift)).
   - **Files**: no `.DS_Store` files on network or USB drives; Save and Print dialogs open expanded
   - **Screen capture**: screenshots go to the clipboard; screen recordings save to `~/Pictures/Screenshots`, as PNG without the window shadow
   - **Battery**: display turns off after 10 minutes on battery (asks for your password when it changes it)
   - **Displays**: built-in display at "More Space", 1920 × 1243 (with `displayplacer` from the Brewfile)

   Run it on its own with `macos/settings.sh`. Some settings need a log out. If the Accessibility ones report an error, give your terminal Full Disk Access and run it again.

   In System Settings, choose **Portuguese** under **Keyboard → Text Input → Edit**.

9. **Siri, suggestions and ads off**: [`macos/debloat.sh`](macos/debloat.sh) turns off Siri ("Hey Siri" and its menu item too), Look Up suggestions, personalised ads and Game Center, then [`macos/agents.sh`](macos/agents.sh) stops about 15 Apple background agents for them (Siri, suggestions, ads, News, Tips; for your user only, no sudo, SIP stays on). They stop at your next login. `macos/agents.sh status` shows them, `macos/agents.sh enable` turns them back on.
10. **Remove Apple apps**: lists whichever of GarageBand, iMovie, Keynote, Numbers and Pages are installed, plus GarageBand's sound library (several GB, kept if Logic Pro is installed), and after you confirm moves them to the Trash. They can be reinstalled from the App Store. The other built-in apps (Safari, Mail, Music, Photos, News, Stocks, ...) are on the read-only system volume, so macOS doesn't let them be removed.
11. **Theme**: applies the theme (Nord the first time); see [Themes](#themes).

Options, as environment variables:

| Variable | Effect |
| --- | --- |
| `ONEDRIVE_SSH_DIR=name` | Use a different folder in OneDrive instead of `dot-ssh` |
| `ONEDRIVE_CODEX_DIR=name` | Use a different folder in OneDrive instead of `codex` |
| `DOTFILES_SKIP="onedrive brew ssh codex github macos debloat trash theme"` | Skip any of those steps (`trash` is removing the Apple apps) |

## What goes where

| In this repo | Linked as |
| --- | --- |
| `zsh/.zshenv` | `~/.zshenv` (sets `ZDOTDIR=~/.config/zsh` and the XDG folders) |
| `zsh/`, `ghostty/`, `starship/`, `git/` | `~/.config/zsh`, `~/.config/ghostty`, `~/.config/starship`, `~/.config/git` |
| `eza/`, `bat/`, `yazi/`, `fastfetch/`, `htop/`, `glow/`, `lazygit/`, `atuin/`, `wget/` | the same names in `~/.config` |
| `nvim/` | `~/.config/nvim` (LazyVim) |
| `vim/` | `~/.config/vim` (Vim 9.1 reads `~/.config/vim/vimrc`, so there's no `~/.vimrc`) |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `bin/theme`, `bin/dots-sync` | `~/.local/bin/theme`, `~/.local/bin/dots-sync` |
| `ssh/config` | copied to `~/.ssh/config` only if there isn't one |

VS Code's "Home" workspace is written to `~/.config/vscode/home.code-workspace` (drag it into the Dock to open VS Code on your home folder).

Because the configs are links, editing a file in `~/.config` edits the repo. Commit from here.

Anything replaced (an old `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.ssh`, `~/.codex`, `~/.zsh_history`, `~/.vimrc`, ...) is moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never deleted. `git/local` and `git/allowed_signers` are generated per Mac and not tracked, nor are the colour files `theme` writes.

Only four things the dotfiles set up stay directly in `~/`: `~/.zshenv` (zsh reads it only from there; it points zsh at `~/.config/zsh`), `~/.ssh` (ssh only looks there), `~/.hushlogin` (an empty file that hides the "Last login" line in new terminals; macOS only looks there) and `~/.vscode` (VS Code's extensions; it has no setting to move them).

## Keeping Macs in sync

`dots-sync` syncs this repo both ways: it commits every change made on this Mac (one commit, "Update from <Mac name>", listing the files), pulls what other Macs pushed (rebasing your commit on top), pushes, and then applies what came in. Applying re-links the configs, and re-runs the Brewfile, the macOS settings, debloat or the theme only when their files changed, without asking anything (the app choice, git identity and OneDrive steps aren't repeated). `dots-sync --all` re-applies everything; `dots-sync --dry-run` only shows what would be committed and applied. The shell reloads afterwards.

## zsh

`.zshrc` loads `zsh/conf.d/*.zsh` in order:

| File | What |
| --- | --- |
| `05-theme` | the theme's colours for fzf, autosuggestions and highlighting, `BAT_THEME`, `GLOW_STYLE`; open shells pick up a new theme at their next prompt |
| `10-history` | 50k-line shared history in `~/.local/state/zsh/history` |
| `20-aliases` | `ls`/`ll`/`lt` (eza), `cat` (bat), `top` (htop), `du` (dust), `df` (duf), `vi` (nvim), `vs` (VS Code), `g` (git), `lg` (lazygit), `python`/`pip` (python3/pip3), `dev`, `dots`, `..`/`...`/`....`, `mkcd`, `finder` (yazi that leaves you in the folder you quit in), `dots-sync` (commit, pull, push and apply), `brewup`, `zalias`, `zedit`, `cls` |
| `30-completion` | completion with Homebrew's completions, case-insensitive, menu select; `theme <Tab>` lists the themes |
| `40-tools` | zoxide as `cd`; fzf on ⌃T files, ⌥C folders and ⌃G git commits (their hashes go on the command line), and on anything piped into `fzf`; atuin on ⌃R history |
| `85-autosuggest` | history suggestions; → accepts |
| `90-prompt` | starship: blocks for the Mac and you, the folder, git, the project's language and the time, in the theme's colours (icon-free version in Terminal.app) |
| `95-fetch` | fastfetch once per new window, with a dotted ghost for a logo (`DOTFILES_NO_FETCH=1` turns it off) |
| `98-highlight` | syntax highlighting |

`EDITOR` and `VISUAL` are Neovim.

Put machine-specific settings in `zsh/conf.d/local.zsh`; git ignores it.

## Ghostty

JetBrains Mono 12, the theme's colours, and ⌃` toggles a quick terminal from any app (allow Ghostty under System Settings › Privacy & Security › Accessibility). Left ⌥ acts as Alt.

## OneDrive: SSH and Codex

Keys stay in OneDrive, so every Mac signed in to the same account shares them. In Finder, right-click the OneDrive `dot-ssh` and `codex` folders and choose **Always Keep on This Device** so they are never cloud-only placeholders.

The `codex` folder also holds live session files, so use it from one Mac at a time; two Macs running Codex against it at once make OneDrive conflict copies.

## Themes

`theme` opens the Themes pane. Tab or Ctrl-W switches between Themes and Wallpapers. Each pane previews the highlighted item. Enter applies it and keeps the picker open. Esc quits. Selecting a theme loads its default wallpaper. Selecting a wallpaper changes only the desktop picture. `theme <name>` selects a theme directly, `theme list` lists themes, and `theme apply` reapplies the current theme and wallpaper.

| Family | Variants |
| --- | --- |
| Atlas | Dark survey ink with light Tagus estuary wallpapers |
| Catppuccin | Latte, Frappé, Macchiato, Mocha |
| Everforest | Dark and Light, each Hard, Medium or Soft |
| Gruvbox | Dark and Light, each Hard, Medium or Soft |
| Nord | Nord |
| Rosé Pine | Rosé Pine, Moon, Dawn |
| Tokyo Night | Night, Storm, Moon, Day |

A theme recolours Ghostty, the prompt, zsh, fzf, eza, bat, delta (git diffs), lazygit, atuin, glow, yazi (its flavor and its header), Neovim, Vim, htop (through the terminal's colours) and VS Code (installing its theme extension), and sets macOS to light or dark, the native accent preset for the theme’s main hue, a Finder folder tint using the variant’s accent RGB, yellow text highlights, and a matching wallpaper on every Mission Control Space across all displays. Open Ghostty windows, Neovims and shells change on the spot. Each Mac keeps its own choice (`~/.local/state/dotfiles/theme`). Use `theme wallpaper list` to list image IDs, `theme wallpaper <image>` to select one, and `theme wallpaper current` to show the current image. The `realistic` and `illustrated` shortcuts select the current theme’s default and illustration respectively. Every bundled theme defaults to a photograph. All six Everforest variants use the rocky coastline, and Nord uses the Arctic radar station. Other themes use `wallpapers/realistic/<name>.jpg`, falling back to `wallpapers/<name>.jpg` or a gradient in the theme colours when artwork is missing.

The ChatGPT desktop app (including Codex) gets the selected theme's light or dark mode, background, text, accent and diff colors. Reopen the app to pick up the saved palette. Set `THEME_NO_CODEX=1` to skip this when running `theme`. The palette is stored in `$CODEX_HOME/config.toml`, so it also syncs with OneDrive if your Codex folder is linked there.

## Editors

- **Neovim** is [LazyVim](https://lazyvim.github.io), with relative line numbers, 2-space indents, the macOS clipboard, no swap files and a transparent background (`nvim/lua/config/options.lua`). Its plugins download on install; `:Lazy` shows and updates them. The colourscheme follows `theme`.
- **Vim** is kept minimal for quick edits (`vim/vimrc`), with its state in `~/.local/state/vim`.
- **VS Code** settings are linked from `vscode/settings.json`; `theme` changes its colour theme there.
