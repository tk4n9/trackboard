# Trackboard

Use your MacBook trackpad to handwrite Korean and English into the focused text
field. Trackboard is implemented as a macOS input source, with a handwriting
overlay and on-device recognition through Apple's Vision framework. Other
languages appear when the installed macOS recognizer supports them.

**Status: experimental, awaiting native macOS validation.** The portable logic
passes its tests on Linux. The macOS application has not yet been compiled or
tested on a MacBook; installation, real trackpad capture, recognition accuracy,
and compatibility across apps remain unverified. See [validation](docs/validation.md).

## Build and install on your Mac

Requirements: macOS 13 or later, a MacBook trackpad or Magic Trackpad, and Xcode
Command Line Tools with Swift 5.9 or later. The app has no third-party packages,
API keys, or model downloads.

Clone the repository, then build and install:

```sh
git clone git@github.com:tk4n9/trackboard.git
cd trackboard

# Install Apple's developer tools if needed:
xcode-select --install

./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
```

On macOS, these scripts put Swift's scratch directory and `Trackboard.app` under
`~/Library/Caches/Trackboard/<checkout-id>/`, outside the source checkout. This
also works when the repository is in Dropbox or another synced folder. The build
prints the app's full path, and the installer finds it automatically. Set
`TRACKBOARD_BUILD_DIR` to use another unsynced build location.

The build targets your Mac's architecture. For a
universal Apple silicon and Intel build, use
`TRACKBOARD_UNIVERSAL=1 ./scripts/build.sh`. Builds are signed locally by default;
set `TRACKBOARD_SIGN_IDENTITY` to use your own signing identity. Public distribution
and notarization have not been configured.

The installer copies the app to `~/Library/Input Methods/Trackboard.app`,
registers and enables it, and preserves any previous Trackboard installation in
`~/Library/Caches/Trackboard/backups/`. It does not switch your active input source.
Log out and back in after first installation or updates so macOS loads the new
input method. Add Trackboard in **System Settings → Keyboard → Text Input →
Edit → +**, under Korean or by searching its name, if it is not already enabled.

## Write into a text field

1. Click the field in your app, then select **Trackboard** in the macOS input menu.
2. Select **한국어 · Korean**, **English**, or another available language in the pad.
3. Write lightly with one finger anywhere on the trackpad. Do not press down.
   Lift between strokes. Write a character or a short word, then pause briefly.
4. Select the desired suggestion with the arrow keys or a click, and press
   **Return** to insert it. The pad stays open for your next word.
5. Press **Escape** to return to the app. **Control–Shift–Space** reopens the pad
   while Trackboard is the active input source.

**Space** inserts the selected suggestion followed by a space. **Delete** or
**Command–Z** removes the last stroke in the pad. **Tab** cycles suggestions.
**Clear** removes all ink. **Recognize** retries immediately. Hold **Option**
while moving the pointer to operate controls without drawing, then lift your
finger before writing again. A mouse can also draw in the pad by dragging.
Disable spelling suggestions for names or literal
character recognition. Outside the pad, physical keyboard input passes through.

The overlay covers connected displays during handwriting, keeping the original
field focused while allowing the pointer to move. Escape always dismisses it.
No Accessibility, Input Monitoring, screen recording, or clipboard access is
requested. Ink is rasterized in memory and recognized locally; it is not saved
or sent to a server. Only language and spelling preferences are persisted.

## Compatibility and limits

The goal is text entry across Mac apps using the standard input method system.
Native fields, browser inputs, rich text editors, and terminals require the
manual checks in [validation](docs/validation.md); none are yet claimed verified.
macOS or individual apps can disable third-party input methods in protected
password fields or custom controls. Those restrictions cannot be overridden by
this input source, so support for literally every text box is not guaranteed.

Vision recognizes a rendered image of the strokes. Its Korean language support
does not establish accuracy for arbitrary Korean handwriting; real handwriting
tests are required. If suggestions are wrong, try larger separate letters,
change the selected language, turn spelling correction off, or undo and redraw.

## Development and verification

```sh
./scripts/test.sh
./scripts/build.sh
python3 -m unittest discover -s Tests/ScriptTests

# Native text-field fixture:
swift Tests/Fixtures/NativeFields.swift

# Browser text-field fixture:
open Tests/Fixtures/input-fields.html
```

On Linux, `./scripts/test.sh` builds only the platform-independent core. On macOS it
also compiles the input source and tests the renderer and recognizer's supported
languages. The [macOS workflow](https://github.com/tk4n9/trackboard/actions)
builds and packages on hosted Mac runners. Check its results separately from the
physical trackpad and cross-application checks.

- `Sources/TrackboardCore/`: strokes, multitouch state, Unicode normalization,
  candidate ordering, and invalidation of stale recognition results.
- `Sources/InputMethodBridge/`: Objective-C InputMethodKit bridge. Remote client
  proxies stay out of Swift ARC and are resolved only at insertion time.
- `Sources/TrackboardMac/`: AppKit capture overlay, asynchronous Vision
  recognition, language selection, and input-session lifecycle.
- `Sources/Trackboard/`: application entry point.
- `Resources/` and `scripts/`: input source registration, packaging, and install.
- `Tests/`: portable and macOS unit tests, plus manual input-field fixtures.

Read [architecture](docs/architecture.md) for API references and design choices.
To uninstall, switch to another input source, remove Trackboard from Keyboard
settings, move its app out of `~/Library/Input Methods/`, and log out and back in.

## Code signing error in a synced folder

If signing reports `resource fork, Finder information, or similar detritus not
allowed`, run `git pull` and use `./scripts/test.sh` instead of plain `swift test`.
The wrapper keeps generated bundles outside the checkout, and the packaging
script removes inherited metadata from its newly generated app before signing.
It does not remove metadata from your source files or Dropbox folders. Plain
`swift test` still defaults to the checkout's `.build/` directory.

Apple explains the rejected metadata in
[Technical Q&A QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html).
