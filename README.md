<div align="center">

<img src="logo.png" width="120" alt="Koment">

# Koment

**Leave comments on your code. Let Claude Code fix them.**

A macOS menu-bar app. Select code in any editor, press one shortcut, type a note.
Claude Code reads your notes and applies them.

[![Release](https://img.shields.io/github/v/release/nandzz/koment?style=flat-square&color=1f6feb&label=release)](https://github.com/nandzz/koment/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/nandzz/koment/total?style=flat-square&color=1f6feb&label=downloads)](https://github.com/nandzz/koment/releases)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?style=flat-square&logo=apple&logoColor=white)](#you-also-need)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-1f6feb?style=flat-square)](LICENSE)

[Install](#install) ·
[Set up](#set-up) ·
[Everyday use](#everyday-use) ·
[How it works](docs/ARCHITECTURE.md) ·
[Contribute](docs/DEVELOPMENT.md)

</div>

---

## Install

### With Homebrew

```sh
brew install --cask nandzz/koment/koment
```

One command. It adds the tap and installs the app.

### Or download the app

1. Download `Koment-<version>.dmg` from the
   [latest release](https://github.com/nandzz/koment/releases/latest).
2. Drag **Koment** into your **Applications** folder.
3. Open it.

The app is signed and notarized by Apple, so it opens with no warning and no right-click.

> **Koment has no window of its own.** Look for its icon in the menu bar, at the top right
> of your screen.

### You also need

| | |
| --- | --- |
| **macOS 26** or later | The app does not launch on an earlier system. |
| **[Claude Code](https://claude.com/claude-code)** | Working in your terminal. `brew install --cask claude-code` |

### Keeping it up to date

| Command | Does |
| --- | --- |
| `brew upgrade --cask koment` | Installs the newest version |
| `brew uninstall --cask koment` | Removes the app, keeps your notes |
| `brew uninstall --zap --cask koment` | Removes the app **and every note you ever took** |

Do you prefer to build it yourself? See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Set up

A setup window opens the first time you launch the app. It has three rows, and each row has
one button. Nothing happens until you press it.

| Row | What the button does |
| --- | --- |
| **Connect to Claude Code** | Registers Koment with Claude Code, so Claude can read your notes. |
| **Allow Accessibility** | Opens System Settings at the right pane. Switch **Koment** on. macOS needs this permission to read the text you select. |
| **Install the /koment command** | Adds the `/koment` command to Claude Code. |

Each row shows you the exact command before it runs, and each row reads its own state, so a
row that is already done says so.

You can open this window again at any time: **Setup…** in the menu-bar menu.

> **After an app update**, the setup window can open again. That means one row is no longer
> true — usually the `/koment` command, which travels inside the app. Press the button again.

### Your first comment

1. **Save your file.** Koment reads files on disk, so unsaved text cannot be found.
2. **Select two or three lines** in your editor.
3. **Press ⌘C twice**, quickly.
4. **Type your note** — for example, `this should use the spacing token`.
   Press `return` to save.
5. **Open your project in a terminal and run `/koment` in Claude Code.**

Claude finds the code, makes the change, and closes the note.

That is the whole loop. Everything below is detail.

---

## What Koment does

You read code and you see something to change, but you do not want to stop and change it now.
Today you write a `// TODO`, or a note in another app, or you forget it.

Koment gives you a third option. Select the lines, press ⌘C twice, and type what you want.
The note is saved with the code it quotes. Later, you run one command in Claude Code and
Claude applies every note you left.

Your notes never go into your project. There is no `// TODO` in the diff, no scratch file
in the repository, and nothing to clean up afterwards.

## Features

| | |
| --- | --- |
| **Works in every editor** | Xcode, VS Code, a browser, Slack, a PDF — anything that shows text. Koment reads the selection through macOS, so it needs no plugin. |
| **One gesture** | Press ⌘C twice, or use a shortcut of your own. The note panel opens on your selection. |
| **Comments find their own file** | Koment finds the file and the line from the selected text, and remembers the code around it, so the note still fits after the file changes. |
| **Claude Code applies them** | Run `/koment` in any repository. Claude reads the notes, changes the code, and closes each note with a record of what it changed. |
| **Or run it from the app** | Press **▶ Run in Claude** in the dashboard and a Claude session opens in the app itself. |
| **A dashboard for everything** | See every note, open or done, by project and by file. Filter, read, delete. |
| **Notes without a file** | Comment on a Slack message, a Jira ticket or a web page. Koment keeps the window title and the address, and Claude works out the rest. |
| **Fully private** | Everything stays in one file on your Mac. Koment sends nothing anywhere and has no account. |

## Everyday use

### Two ways to open the note panel

**⌘C twice** is the everyday one. Copy as you always would, then press ⌘C again straight
away. Koment never blocks your ⌘C — the first press copies exactly as before.

**⌃⌥⌘C** is the alternative, for a selection you would rather not copy. You can change this
shortcut, or switch the ⌘C gesture off, in [Configuration](#configuration).

### In the note panel

| Key | Does |
| --- | --- |
| `return` | Save the note |
| `shift-return` | Start a new line |
| `esc` | Cancel |

### Commenting on something that is not code

Sometimes there is no text to select — a Slack message, a chat window, an app that gives
macOS nothing to read. Koment then offers **Comment on this window**. The note is saved
against the window title and the page address instead of a file. These notes still run:
Claude reads the title and asks you if the note does not say enough.

### Applying your notes

In Claude Code, in your project:

| Command | Applies |
| --- | --- |
| `/koment` | The open notes of this repository |
| `/koment all` | The open notes of every project |

Claude gives each file to its own worker, so several files are done at the same time.
When a note does not say enough, Claude leaves that file alone and asks you at the end,
rather than guessing.

### The dashboard

**Dashboard…** in the menu, or ⌘D, opens the list of your notes.

- **Open / Resolved / All** — Open holds your outstanding work. A red row is one where Claude
  could not find the code any more, and it wants a human.
- **A filter field** narrows the list by note, file, project or app.
- **A detail pane** shows the selected note in full, with the file, the line and the code
  you selected.
- **Double-click** a row to show the file in Finder. **Right-click** to copy the path or
  the note.
- **Delete** removes a note for good — one row, or every row the filter shows. Both ask
  first, and neither can be undone.
- **▶ Run in Claude** (⌘R) applies the selected notes without leaving the app.

### Run in Claude

Select rows in the dashboard and press **▶ Run in Claude**. A real Claude session opens in
a panel at the bottom of the window — one tab per project, with a green dot while it runs.

It is an ordinary interactive session, so Claude can ask you about a note, and you can
answer it and you can stop it. Sessions keep running when you close the dashboard, and
stop when you quit the app.

**Restart** runs a finished tab again. **Close** ends the session. **Terminal** in the
toolbar hides and shows the panel.

Do you prefer your own terminal? Set `embeddedTerminal` to `false`.

### The menu-bar menu

| Item | Does |
| --- | --- |
| **Dashboard…** (⌘D) | Opens the list of your notes |
| **Setup…** | Opens the setup window again |
| **How it works…** | A short reminder of all of the above |
| **Reveal database in Finder** | Shows where your notes are stored |
| **Open diagnostics log** | Shows what the last capture saw. Useful when a note found no file |
| **Reload configuration** | Reads `config.json` again after you edit it |
| **Quit** | Stops the app and any running Claude session |

## Configuration

Koment writes this file on first launch:

```
~/Library/Application Support/com.nandzz.koment/config.json
```

```json
{
  "doubleTapCopy": true,
  "embeddedTerminal": true,
  "hotkeyKey": "c",
  "hotkeyModifiers": ["control", "option", "command"],
  "roots": ["~/Desktop/Workspace"],
  "terminalApp": "Terminal"
}
```

| Key | Does |
| --- | --- |
| `roots` | The folders that hold your projects. Koment searches these to find the file you commented on. **Set this to your own workspace.** Keep the list short — a wide root makes the search slow. |
| `doubleTapCopy` | The ⌘C ⌘C gesture. Set to `false` to leave ⌘C alone. |
| `hotkeyKey`, `hotkeyModifiers` | The shortcut. Modifiers are `control`, `option`, `command` and `shift`. |
| `embeddedTerminal` | Keeps **Run in Claude** inside the app. Set to `false` to use your own terminal. |
| `terminalApp` | The terminal that then opens, by name — `Terminal`, `iTerm`, `Warp`. |

Choose **Reload configuration** in the menu after you edit the file.

## Where your data lives

```
~/Library/Application Support/com.nandzz.koment/
    comments.db        every note, open and closed
    config.json        the file above
    diagnostics.log    what the last capture saw
    runs/              temporary scripts, swept after a day
```

Nothing goes into your projects, and nothing leaves your Mac. Back up `comments.db` if the
notes matter to you — there is no sync yet.

## Known limits

| | |
| --- | --- |
| **Save the file first** | Koment reads files on disk. Text you typed and did not save cannot be found, and the note is saved with no file. |
| **Select two or three lines** | One word can match many lines. A longer selection is found exactly. |
| **VS Code needs accessibility on** | Electron apps expose their text only when accessibility support is on. Without it, Koment falls back to the clipboard, which still works. |
| **A note with no file stays that way** | A Slack or web note is not a location. Claude can act on it, but nothing can re-find it for you. |
| **Notes do not travel** | Because they never touch your source, a note stays on the machine that took it. It is not in the diff and not in the repository. |
| **One Mac, no sync** | There is no export yet. |

## What comes next

- Find moved code inside the app, and flag a note before Claude reads it.
- A VS Code extension, for the exact file and line with no search.
- Replies: an answer from Claude written back onto the note.
- An export, so a note can leave this machine.

## Learn more

- **[How it works](docs/ARCHITECTURE.md)** — how a note finds its file, what a row holds, and
  how Claude reads it.
- **[Build and contribute](docs/DEVELOPMENT.md)** — the project, the tests, signing and
  releases.

## Licence

MIT. See [LICENSE](LICENSE).
