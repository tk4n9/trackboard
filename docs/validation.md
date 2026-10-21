# Validation status and MacBook acceptance checks

The development host is Linux. The 28 portable Swift tests and six build-script
tests pass locally. Hosted macOS 14 and 15 runners also passed the Swift tests,
native compilation, and signed app packaging for code commit `8cd29f0` in
[run 39629089287](https://github.com/tk4n9/trackboard/actions/runs/39629089287).
Packaging passed after Finder metadata and a resource fork were added to the
source plist. Installation on a user's Mac, physical touch capture, recognition
quality, and cross-app insertion are **pending**; hosted tests do not establish
that end-to-end behavior.

## Automated checks on a Mac

Run `./scripts/test.sh` and `./scripts/build.sh` from the repository. The wrappers
keep generated bundles outside synced source folders. The tests cover
stroke separation and cancellation, multitouch recovery, candidate ordering,
Hangul normalization, late-result rejection, raster dimensions, and availability
of Korean and English in Vision. The macOS-only tests do not measure recognition
accuracy or exercise a real InputMethodKit client.

The [GitHub workflow](https://github.com/tk4n9/trackboard/actions) performs these
native build and API checks on `macos-14` and `macos-15`. Check the run for the
commit being tested; a successful hosted build does not verify physical trackpad
capture or cross-application behavior.

The packaging job adds Finder metadata and a resource fork to the source plist
before building, then verifies the signature on the clean generated app. Script
tests also check paths with spaces, cache isolation, and test-argument forwarding.

## Manual acceptance

Record the macOS version, processor, trackpad type, app versions, and observations
with any results. Do not mark a row as passed based on unit tests or code review.

| Check | Expected result | Current result |
| --- | --- | --- |
| Install and log back in | Trackboard is listed and can be selected | Pending |
| Select a native text field | Pad opens while the original field retains focus | Pending |
| Light single-finger strokes | Complete strokes appear without pressing the trackpad | Pending |
| Lift and start another stroke | No artificial connecting line | Pending |
| Add a second finger, then lift both | Unfinished stroke cancels; drawing resumes cleanly | Pending |
| Write `hello`, `world`, `Trackboard` in English | Intended result appears among suggestions and inserts correctly | Pending |
| Write `안녕`, `한글`, `대한민국` in Korean | Intended result appears among suggestions and inserts as complete Hangul | Pending |
| Return, then write another word | First word inserts once; pad clears and accepts next word | Pending |
| Space after a suggestion | One word and one trailing space insert, without duplication | Pending |
| Select existing text before handwriting | Insertion replaces that selection | Pending |
| Close pad, Edit → Undo | Host application undoes the insertion normally | Pending |
| Switch field/app while recognition runs | Old result does not insert or appear in the new session | Pending |
| Change language, clear, or undo while recognizing | Results for the previous ink/settings are ignored | Pending |
| Escape and Control–Shift–Space | Pad closes and reopens without changing target focus | Pending |
| Physical keyboard with pad closed | Normal text and application shortcuts pass through | Pending |
| Option held while moving pointer | Pointer moves without adding ink | Pending |
| Release Option with finger still down | Ink resumes only after lifting and touching again | Pending |
| Clear or Undo during a contact | Cleared/undone contact cannot leave a trailing stroke | Pending |
| One physical trackpad press | Raw touch and mouse events do not produce duplicate ink | Pending |
| Full-screen app and multiple displays | Touch capture remains usable and panel dismisses normally | Pending |
| Sleep or disconnect a display | Overlay closes; no stale insertion on resume | Pending |
| Relaunch or log back in | Input source starts without duplicate servers or crashes | Pending |

## Text-field coverage

Use `swift Tests/Fixtures/NativeFields.swift` for `NSTextField`, `NSTextView`, and
`NSSecureTextField`. Open `Tests/Fixtures/input-fields.html` in Safari and Chrome
for single-line input, textarea, contenteditable, and protected input.

Also test Apple Notes, TextEdit, Terminal, and an Electron editor such as VS Code.
For every supported field, check Korean, English, selection replacement, normal
Undo, and focus changes. Test Terminal with harmless text without pressing its
Return key until the result has been inspected.

Protected fields and custom editors may reject third-party input methods. Record
those restrictions as compatibility limits; do not report support for all fields
without runtime evidence. No such compatibility testing has been completed yet.
