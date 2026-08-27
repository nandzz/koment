# Koment

A menu-bar app for macOS 26. Select code in any editor, press one shortcut, type a note. The note
lands in a database the app owns — never in your project — and Claude Code reaches it through an
MCP server, so `/koment` applies your notes in any repository.

This is V0. It works in Xcode, VS Code, and anything else that shows text, because it never
talks to the editor.

Your notes and the code they quote stay in one SQLite file on your machine. Koment sends nothing
anywhere.

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

## Install

Koment needs **macOS 26**. Every window is SwiftUI and draws itself with the Liquid Glass
materials of macOS 26, so the deployment target is 26.0 and the app does not launch on an
earlier system.

Download `Koment-<version>.dmg` from [Releases](https://github.com/nandzz/koment/releases),
drag Koment to Applications, and open it. The build is signed with a Developer ID and notarized,
so Gatekeeper lets it through with no right-click and no `xattr`.

A setup window opens on first launch with three rows, and does nothing until you press a button:

| Row | Presses |
| --- | --- |
| Connect to Claude Code | `claude mcp add -s user koment -- <app>/Contents/Helpers/KomentMCP` |
| Allow Accessibility | opens System Settings at the right pane |
| Install the /koment command | copies `koment.md` out of the bundle into `~/.claude/commands` |

Each row shows the exact command before you run it and reads its own state back, so a row that
is already done says so. **Setup…** in the menu opens the window again at any time. The window
reopens by itself whenever a row stops being true — an app update that changes the command shows
the third row as out of date until you press it again.

The server and the command both travel inside the app, so nothing points at a checkout and the
app runs from wherever you keep it.

## Build from source

You also need **Xcode 26**.

```bash
Scripts/bundle.sh            # xcodebuild Release, then copy to build/Koment.app
open build/Koment.app
```

`Koment.xcodeproj` is the project — `open Koment.xcodeproj` to edit, debug and ⌘R.
`Scripts/bundle.sh` runs the same Release build from the terminal. It holds seven targets,
four that ship and three that test:

| Target | Product |
| --- | --- |
| `Koment` | the app itself, `LSUIElement` |
| `KomentCore` | a static library, shared by the app and the server |
| `MCPServer` | a static library holding the server itself — every tool, and the JSON-RPC around them |
| `KomentMCP` | the server binary, one `main.swift` over `MCPServer`, copied into `Contents/Helpers` and signed on the way in |
| `KomentCoreTests`, `MCPServerTests`, `KomentTests` | the three test bundles below |

`MCPServer` is a library rather than part of the executable for one reason: a test bundle cannot
be hosted in a command-line tool whose `main` blocks on standard input, and the server's does. The
executable is now the one line that starts it.

The source folders are synchronized groups, so a new file in `Sources/` or `Tests/` joins its
target with no project edit.

The interface is SwiftUI. `Theme.swift` holds every measurement, font, colour and duration as a
token, reached through the environment, so no view carries a number of its own. Five things stay
AppKit, because SwiftUI has no equivalent: the status item and its menu (`AppDelegate`,
`MainMenu`), the global shortcut (`HotkeyManager`), the ⌘C watcher (`CopyTapMonitor`), the
Accessibility capture (`SelectionCapture`, `Resolver`), and the terminal emulator, which reaches
SwiftUI through `TerminalStage`. The note editor is also an `NSTextView` — it is the only way to
keep return for save, shift-return for a new line, and esc for cancel.

The first build needs the network twice over: it fetches
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), the terminal emulator behind the panel in
the dashboard and the only dependency, and Xcode fetches its Metal toolchain, which SwiftTerm's
shader needs and Xcode 26 no longer ships. In Xcode, the first build also asks you to trust
SwiftTerm's build-tool plugin; `bundle.sh` passes `-skipPackagePluginValidation` instead.

`Package.swift` stays, and still builds everything with `xcrun swift build`. If your shell `swift`
comes from swiftly or another toolchain, it is probably too old; `xcodebuild` and
`xcrun swift build` both use Xcode's.

`Scripts/install-command.sh` installs the `/koment` command from the checkout, which is the
terminal equivalent of the third setup row.

The app still finds a checkout when it is running from one: the build stamps `SRCROOT` into the
bundle as `KomentDevelopmentRoot`, and the app walks up from its own bundle looking for
`Package.swift` when the stamp is absent. Nothing in setup depends on it any more — it is the
fallback that lets an Xcode ⌘R run, which lives in `DerivedData` and nowhere near the checkout,
still find the command file.

### Signing

`Signing.xcconfig` holds the signing settings for every target, and **ad-hoc signing is the
default**, so a fresh clone builds with no Apple account.

Ad-hoc has one cost worth knowing: macOS keys the Accessibility permission to the signature, and
an ad-hoc signature changes on every rebuild, so the system asks for the permission again each
time. To keep the approval, sign with a stable identity of your own:

```bash
cp Signing.local.xcconfig.example Signing.local.xcconfig   # then write your team ID in it
```

`Signing.local.xcconfig` is git-ignored, so your identity never reaches the repository.

### Releasing

`Scripts/release.sh` builds Release, refuses to go on unless the bundle carries a Developer ID
signature, makes `dist/Koment-<version>.dmg`, notarizes it, staples the ticket and prints the
SHA-256 for a Homebrew cask. It needs a stored notary credential once:

```bash
xcrun notarytool store-credentials koment-notary \
    --apple-id you@example.com --team-id YOURTEAMID --password <app-specific-password>
```

Set `NOTARY_PROFILE` to use a profile under another name. Bump `CFBundleShortVersionString` in
`Resources/Info.plist` before you run it — the DMG is named from it.

## Tests

```bash
xcrun swift test        # or ⌘U in Xcode
```

297 tests in three targets, written with Swift Testing. They need no simulator and no
Accessibility permission, and the whole run takes under a second. ⌘U reports 302, because Xcode
counts each case of the one parameterized test on its own.

| Target | Covers |
| --- | --- |
| `KomentCoreTests` | the database, the store, the schema migration, the model, `Shell`, `Paths` and the setup steps |
| `MCPServerTests` | the tool catalogue, the protocol handshake, and every tool the server answers |
| `KomentTests` | `Resolver`, `ClaudeRunner`, `CommentPresentation`, `Config`, `Capture`, `FileOpener`, `Diagnostics` and `DashboardModel` |

The schema test is the one worth knowing about: it writes the first version of the table, sets
`user_version` back to 1, reopens the file and checks that the three window columns arrive and the
rows survive. That is the migration a released app will run once.

Each test that needs a database makes its own in a temporary folder, so a run never reads or
writes `comments.db`. No test opens a terminal, starts a Claude session or writes into `runs/`.
The one thing a run touches outside its own folder is the support folder itself, which
`Paths.prepare()` creates when it is not there.

Two of the three bundles have no host. `KomentTests` has one, because reaching inside an
application target needs it: ⌘U launches the app, runs the tests inside it, and quits. So a ⌘U
registers ⌃⌥⌘C for a second or two and may show the setup window on the way past. `swift test`
does not, which is the faster way in while you work.

## Use

1. Select the lines in your editor. Save the file first — see Limits.
2. Press **⌘C twice**, or press ⌃⌥⌘C.
3. Type the note. `return` saves, `shift-return` adds a line, `esc` cancels.
4. Either press **▶ Run in Claude** in the dashboard, which opens a Claude session in the
   terminal panel at the bottom of the window, or run `/koment` yourself in Claude Code.
   `/koment` and `/koment here` are this repository; `/koment all` is every project.
5. Nothing else. `/koment` closes what it applied, and the app notices at once.

## Configuration

`~/Library/Application Support/com.nandzz.koment/config.json`, written with defaults
on first launch:

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

`roots` is where steps 3 and 4 search. Keep it short; a wide root makes resolution slow.
`doubleTapCopy` is the ⌘C gesture below, and defaults to `true` when the key is absent.
`embeddedTerminal` keeps **Run in Claude** inside the app, in the terminal panel of the
dashboard, and defaults to `true`. Set it to `false` to go back to an external terminal.
`terminalApp` is the app that then opens, by name — `Warp`, `iTerm`, anything LaunchServices
knows. It defaults to `Terminal`, and falls back to `Terminal` when the named app refuses the
script. Reload the file from the menu after an edit.

## Two ways in

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

**⌃⌥⌘C** stays as the chord, for a selection you would rather not copy. Change it with
`hotkeyKey` and `hotkeyModifiers`, or set `doubleTapCopy` to `false` to leave ⌘C entirely alone.

## Storage

A comment is a row in one SQLite database, and nothing else anywhere:

```
~/Library/Application Support/com.nandzz.koment/
    comments.db        every comment, open and closed
    config.json        the file above
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
tools are how it reads and writes. There is no other way in — the app and Claude never edit the same thing behind each
other's back.

## Who closes a comment

Claude does, by calling `resolve_comment` as the last step of applying one: the row's `status`
becomes `resolved`, `resolved_at` is stamped, and `resolution` records what changed. `drifted`
is the honest alternative when the code cannot be found.

The app hears about it at once. The MCP server posts a Darwin notification after every write and
the app listens for it, so an open dashboard redraws in the moment. No file watching, no
polling timer, and no repair pass — there is nothing to repair when state is a column.

## Dashboard

**Dashboard…** (⌘D from the menu) reads the database and shows what it says, with the terminal
panel under it:

- **Open / Resolved / All** — the Open tab holds the outstanding work, which is the open comments
  and the drifted ones (red, because a drifted comment still wants a human). The Resolved tab
  holds what Claude closed.
- A **filter field** narrows by note, file, project or capturing app.
- Columns: when it was captured with the capture method, its status with the resolution
  confidence, the project, the file with its folder inside the project, and the note.
- A **detail pane** under the table shows the selected comment in full — the whole note, the
  absolute path with its line span, the dates, and the text that was selected.
- Double-click a row to reveal the file in Finder; right-click to copy the path or the note.
- **▶ Run in Claude** applies the selected comments without leaving the app, in the terminal
  panel. See below.
- **Terminal** in the toolbar shows or hides that panel, and says how many sessions run.
- **Delete** removes a comment for good. `delete` on the selected row, or right-click and
  **Delete comment…**, takes one. **Delete all shown…** takes the whole list — which is the list
  the tabs and the filter field have narrowed to, so "every resolved comment in this project" is
  a filter away. Both ask first, and neither can be undone: the row leaves the database and there
  is no bin.

Rows are multi-select, so **Resolve** and **Delete…** now act on every selected row, not the
last one clicked.

The window holds a row list for what is on screen and nothing else. Closing it drops that list;
opening it queries again; a write from Claude rebuilds it and keeps your selected row. It never
caches comment state, so it cannot disagree with the database. The terminal sessions are the one
thing that outlives a close, because a running Claude must not die when you tidy the screen away.

**How it works…** in the menu opens a window that says all of the above in short, for the day
you come back to the app and forget which key does what.

## Run in Claude

Select rows and press **▶ Run in Claude** — the button in the detail pane, the same item in the
right-click menu, or ⌘R. The app writes a short script into `runs/`:

```sh
#!/bin/zsh
cd "/Users/you/Workspace/app" || exit 1
exec "/Users/you/.local/bin/claude" "/koment 9C1F… A4B2…"
```

and runs it with `/bin/zsh -l` inside a pseudo-terminal, in a tab of the panel at the bottom of
the dashboard. A login shell, so the session gets the `PATH` your terminal gives you rather than
the one a GUI app inherits. The session is a normal interactive one, so Claude can ask you about
a note that does not say enough, and you can answer it, and you can stop it.

The panel is a terminal, not a log:

- **One tab per session**, named after the project, with a dot that is green while the session
  runs and grey or red once it ends.
- **Restart** runs the same script again in a tab that ended; **Close** ends the session and
  takes the tab away. The scrollback stays until you close the tab.
- Drag the divider to change the height of the panel; the app remembers it. **Terminal** in the
  toolbar hides and shows it.
- Sessions keep running when you close the dashboard window, and stop when you quit the app.
- Nothing is created until you press **Run in Claude** for the first time, so a session you never
  start costs nothing.

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

The app learns the outcome the way it always has: `/koment` calls `resolve_comment`, and the
open dashboard turns the row green in the moment. Nothing polls, and no comment carries a
"running" state that could go stale.

A comment saved without a project — a Slack note, a web page — still runs. It has no repository
of its own, so Claude starts in the first entry of `roots` and reads `window_title`, `source_url`
and `bundle_id` to work out what the note is asking for, asking you when the note does not say
enough. These comments are never handed to a sub-agent, because an agent cannot ask you anything
and these are the ones most likely to need a question. The only way one is left out is a `roots`
that names no folder that exists, and the app says so.

`/koment all` uses the same fan-out from the command line, over every project holding open
comments rather than one.

## Limits

- **Unsaved buffers.** Steps 2 to 4 search files on disk. Text you just typed and did not save
  is not there, so resolution fails and the note is saved unanchored. Save first.
- **Anchor drift.** V0 stores the anchor and leaves re-anchoring to `/koment`. There is no
  drift check in the app and no repair when a file changes a lot.
- **Ambiguous selections.** A one-word selection can match many lines. Step 4 needs eight
  characters and takes the first hit in the first repository. Select two or three lines.
- **VS Code accessibility.** Electron exposes its accessibility tree only when accessibility
  support is on. Without it, step 1 and the selected-text read fail and the app falls back to
  the clipboard.
- **A comment with no file is still a comment with no file.** The window title says which chat
  or which page, which is enough for Claude to ask a good question, but it is not a location. It
  cannot be re-anchored, and it never resolves itself.
- **Comments never reach your source.** That is the point of the app, and it is also why a
  reviewer looking only at the diff cannot see them — and why a comment does not travel with the
  repository to another machine.
- **A sub-agent cannot ask you anything.** When the fan-out is on and a note does not say enough,
  the agent leaves the file alone and hands the question back, and the session puts it to you at
  the end. So a batch run finishes with some comments still open, by design, rather than with a
  guess written to disk.
- **One database, one machine.** There is no sync and no export yet. Back up
  `~/Library/Application Support/com.nandzz.koment/comments.db` if the notes matter.

## V1, when V0 proves itself

- Re-anchor inside the app, so a comment is flagged as drifted before Claude ever reads it.
- A VS Code extension that posts the exact file and line to the app, skipping steps 3 and 4.
- Threads: a reply from Claude written back to the comment.
- An export, so a comment can leave this machine.

## Licence

MIT. See [LICENSE](LICENSE).
