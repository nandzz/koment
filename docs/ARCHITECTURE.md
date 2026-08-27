# How Koment works

This document is for the curious and for contributors. To use the app, read the
[README](../README.md).

## How a comment finds its file

The app cannot ask an editor "which line is selected". It reads the selected *text* through the
Accessibility API and resolves the location itself, in four steps, most exact first:

| Step | Method | Confidence stored |
| --- | --- | --- |
| 1 | Window `AXDocument` gives the file, `AXLineForIndex` gives the line | `ax-exact` |
| 2 | `AXDocument` gives the file, the selected text gives the line | `document-search` |
| 2b | `AXDocument` gives the file, no line matches the selected text | `document-only` |
| 3 | The window title gives the file name, `find` locates it, the text gives the line | `title-search` |
| 4 | `git grep` over every repository under the configured roots | `repo-search` |

Xcode reaches step 1, so it gets an exact line with no search. VS Code exposes `AXDocument`
but no focused element, so it reaches step 2 through the clipboard fallback. A file outside any
git repository anchors to the nearest ancestor holding a `.claude` folder instead. When every
step fails, the note is saved unanchored — a comment with no project — and the panel says so.

Fallback for the selection itself: when the focused element exposes no selected text, the app
sends ⌘C, reads the clipboard, and puts the old clipboard back.

When that also gives nothing, the app cannot tell an empty selection from a window that refused
to answer, so it asks instead of guessing: the message offers **Comment on this window**, which
opens the same panel with no snippet and saves the note against `windowTitle`, `sourceURL` and
`bundleIdentifier`, with `method` set to `window`. Use it to speak about a web page, a chat, or
a whole file.

## The two ways in

**⌘C twice** is the everyday one: copy as you always would, then press ⌘C again within 400 ms
and the panel opens on that selection.

A single ⌘C cannot be the trigger. A registered hotkey *consumes* the combination, so ⌘C would
stop copying in every app on the machine — and the app posts ⌘C itself to read a selection an
editor will not hand over (step 2 of the table above), so it would trigger itself. The double tap
avoids both: the app installs a **listen-only** event tap, which observes ⌘C and never swallows
it, so the first press copies exactly as before. It also ignores its own synthetic ⌘C, marked
with `eventSourceUserData`, and key repeats. The tap needs the same Accessibility permission the
app already needs; the menu says so when it is missing.

The gesture also means the selection is already on the clipboard by the time the panel opens,
which is what the clipboard fallback wants anyway.

**⌃⌥⌘C** stays as the chord, for a selection you would rather not copy.

## Storage

A comment is a row in one SQLite database, and nothing else anywhere:

```
~/Library/Application Support/com.nandzz.koment/
    comments.db        every comment, open and closed
    config.json        the configuration file
    diagnostics.log    what the last capture saw
    runs/              one throw-away script per Run in Claude, swept after a day
```

Not one byte goes into your projects. `status` is a column — `open`, `resolved`, or `drifted` —
so a comment never moves between files as its state changes, and there is no second copy to fall
out of step with the first. A comment whose file could not be resolved is a row with an empty
`project_root`; it needs no special file. The list of projects is
`SELECT DISTINCT project_root`, so the app no longer sweeps your disk with `find` to remember
where it has been.

The database is in WAL mode with a busy timeout, because two processes write it: the app when
you save a note, and the MCP server when Claude closes one. That is the part the old JSON files
could not do at all.

A row looks like this:

| Column | Value |
| --- | --- |
| `id` | `9C1F…` |
| `created_at` | `2026-08-25T13:40:12Z` |
| `status` | `open` |
| `note` | `this must use the Tasty spacing token` |
| `path` | `/Users/you/Workspace/app/Sources/Foo/Bar.swift` |
| `project_root` | `/Users/you/Workspace/app` |
| `file` | `Sources/Foo/Bar.swift` |
| `line`, `end_line` | `42`, `44` |
| `selected_text` | `.padding(16)` |
| `before_lines`, `after_lines` | the three lines either side |
| `blob` | `a1b2c3…` |
| `confidence` | `ax-exact` |
| `captured_in`, `method` | `Xcode`, `ax-selected-text` |
| `window_title` | `Bar.swift` — or `#checkout (TheFork) - Slack` |
| `bundle_id` | `com.apple.dt.Xcode` |
| `source_url` | empty here; the page address when the window has one |
| `resolved_at`, `resolution` | empty until Claude closes it |

`path` is the absolute file and is what `/koment` opens. `file` is the same file relative to
`project_root`, kept for reading rather than resolving. `line` is a hint, not the truth; the
anchor columns are how `/koment` finds the code after it moves.

## Where a comment came from

Three columns record the window a comment was taken from, so a note keeps its context even when
there is no file to point at:

| Column | Where it comes from | Slack | A browser | An editor |
| --- | --- | --- | --- | --- |
| `window_title` | the window's `AXTitle` | `Federica Giordano (DM) - Tripadvisor - 7 new items - Slack` | the page title | the file name |
| `bundle_id` | the frontmost app | `com.tinyspeck.slackmacgap` | `com.google.Chrome` | `com.apple.dt.Xcode` |
| `source_url` | the window's `AXURL` | empty | the Notion page or Jira ticket | empty, or a file URL |

Slack is the case that shows why this matters. It is an Electron app that exposes no focused
element, so there is no selected text to read, no surrounding context and no line — the app falls
back to the clipboard and the comment is saved unanchored. The window title is the only thing
that says *which conversation*, and it is enough: Slack names the channel or the person in it.

The title is stored **raw and never parsed**. That Slack example carries `7 new items`, an unread
counter that differs between two captures of the same conversation, so any parser would be wrong
by the next message. Claude reads the string and works it out.

A real permalink to a Slack message is not in the accessibility tree at all. That needs Slack's
own **Copy link** or its API, and this app does not go there.

The dashboard shows all of this: the window title sits under the file name in the list and
beside the app in the detail pane, the URL takes the place of the path when there is no file, and
the filter field searches both.

## How Claude reads them

Through an MCP server — `Sources/KomentMCP`, one stdio process Claude Code starts on
demand. It talks to the database, never to the app, so it works whether or not the app is
running.

| Tool | Does |
| --- | --- |
| `list_comments` | the open comments of the current repository, newest first |
| `get_comment` | one comment in full, with its anchor |
| `resolve_comment` | close one, recording what changed |
| `mark_drifted` | record that the code could not be found, instead of guessing |
| `list_projects` | every project holding comments, with how many are open |

With no `project` argument the server scopes itself to `git rev-parse --show-toplevel` of the
directory Claude Code started it in, which is your project. Nothing to configure per repository.

`/koment` is the prompt that says how to re-anchor and apply, and how to fan the work out; the
tools are how it reads and writes. There is no other way in — the app and Claude never edit the
same thing behind each other's back.

## Who closes a comment

Claude does, by calling `resolve_comment` as the last step of applying one: the row's `status`
becomes `resolved`, `resolved_at` is stamped, and `resolution` records what changed. `drifted`
is the honest alternative when the code cannot be found.

The app hears about it at once. The MCP server posts a Darwin notification after every write and
the app listens for it, so an open dashboard redraws in the moment. No file watching, no
polling timer, and no repair pass — there is nothing to repair when state is a column.

## Run in Claude

The app writes a short script into `runs/`:

```sh
#!/bin/zsh
cd "/Users/you/Workspace/app" || exit 1
exec "/Users/you/.local/bin/claude" "/koment 9C1F… A4B2…"
```

and runs it with `/bin/zsh -l` inside a pseudo-terminal, in a tab of the panel at the bottom of
the dashboard. A login shell, so the session gets the `PATH` your terminal gives you rather than
the one a GUI app inherits. The session is a normal interactive one, so Claude can ask you about
a note that does not say enough, and you can answer it, and you can stop it.

Set `embeddedTerminal` to `false` and the same script opens in `terminalApp` instead, through
`open -a`. That was the only way in the first version: a script and `open -a`, rather than
AppleScript, because driving another app needs Automation permission on top of the Accessibility
permission the app already asks for, and needs a different script per terminal.

Two rules shape what happens next:

- **One session per project.** A Claude session is rooted in one repository, because the comment
  server scopes itself to the `git` top level of the directory it starts in. Select comments from
  three projects and three tabs open, one per project, after the app asks first.
- **One agent per file.** Inside a session, `/koment` groups the comments by file and gives
  each file to its own sub-agent, so the files are done at the same time and no two agents ever
  write the same file. One file means no agent at all.

A comment saved without a project — a Slack note, a web page — still runs. It has no repository
of its own, so Claude starts in the first entry of `roots` and reads `window_title`, `source_url`
and `bundle_id` to work out what the note is asking for, asking you when the note does not say
enough. These comments are never handed to a sub-agent, because an agent cannot ask you anything
and these are the ones most likely to need a question. The only way one is left out is a `roots`
that names no folder that exists, and the app says so.

`/koment all` uses the same fan-out from the command line, over every project holding open
comments rather than one.

## The dashboard

**Dashboard…** (⌘D from the menu) reads the database and shows what it says, with the terminal
panel under it. The window holds a row list for what is on screen and nothing else. Closing it
drops that list; opening it queries again; a write from Claude rebuilds it and keeps your
selected row. It never caches comment state, so it cannot disagree with the database. The
terminal sessions are the one thing that outlives a close, because a running Claude must not die
when you tidy the screen away.

Rows are multi-select, so **Resolve** and **Delete…** act on every selected row, not the last
one clicked.
