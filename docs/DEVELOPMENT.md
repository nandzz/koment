# Build and contribute

To use the app, read the [README](../README.md). For the design, read
[ARCHITECTURE.md](ARCHITECTURE.md).

## Build from source

You need **macOS 26** and **Xcode 26**.

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

## The interface

The interface is SwiftUI. `Theme.swift` holds every measurement, font, colour and duration as a
token, reached through the environment, so no view carries a number of its own. Five things stay
AppKit, because SwiftUI has no equivalent: the status item and its menu (`AppDelegate`,
`MainMenu`), the global shortcut (`HotkeyManager`), the ⌘C watcher (`CopyTapMonitor`), the
Accessibility capture (`SelectionCapture`, `Resolver`), and the terminal emulator, which reaches
SwiftUI through `TerminalStage`. The note editor is also an `NSTextView` — it is the only way to
keep return for save, shift-return for a new line, and esc for cancel.

Every window draws itself with the Liquid Glass materials of macOS 26, which is why the
deployment target is 26.0.

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

## Signing

`Signing.xcconfig` holds the signing settings for every target, and **ad-hoc signing is the
default**, so a fresh clone builds with no Apple account.

Ad-hoc has one cost worth knowing: macOS keys the Accessibility permission to the signature, and
an ad-hoc signature changes on every rebuild, so the system asks for the permission again each
time. To keep the approval, sign with a stable identity of your own:

```bash
cp Signing.local.xcconfig.example Signing.local.xcconfig   # then write your team ID in it
```

`Signing.local.xcconfig` is git-ignored, so your identity never reaches the repository.

## Releasing

`Scripts/release.sh` takes the build all the way to a notarized DMG. It needs a stored notary
credential once:

```bash
xcrun notarytool store-credentials koment-notary \
    --apple-id you@example.com --team-id YOURTEAMID --password <app-specific-password>
```

Set `NOTARY_PROFILE` to use a profile under another name. Bump `CFBundleShortVersionString` in
`Resources/Info.plist` before you run it — the DMG is named from it.

The script stops before it reaches Apple unless the bundle passes three checks, each of which
Apple would otherwise reject:

| Check | Why it exists |
| --- | --- |
| A Developer ID signature | Ad-hoc is the default, so this catches a missing `Signing.local.xcconfig`. |
| A secure timestamp | `Signing.xcconfig` asks for `--timestamp` in Release only. Debug keeps `--timestamp=none`. |
| No `get-task-allow` | `xcodebuild build` injects the debug entitlement, so Release sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`. Debug keeps it, so a debugger still attaches. |

Notarization then runs **twice**, and the order matters. The app is notarized and stapled first,
and only then does the DMG get built from the stapled app and notarized in turn. A ticket stapled
to the DMG alone does not travel with the app a user drags out of it, so that app would need a
network on first launch. Homebrew copies the app out of the image, so this affects every brew
install.

The script prints the DMG path and its SHA-256 at the end. Both go into the cask.

## The Homebrew tap

The cask lives in [nandzz/homebrew-koment](https://github.com/nandzz/homebrew-koment), because
`homebrew/cask` takes a project only once it has 75 stars, 30 forks or 30 watchers.

After a release, set `version` and `sha256` in `Casks/koment.rb` to the values the release script
printed, then check the cask before you push it:

```bash
brew style nandzz/koment
brew audit --cask --online nandzz/koment/koment
```

Leave `--new` off. It adds the notability rule above, which applies only to `homebrew/cask`.
