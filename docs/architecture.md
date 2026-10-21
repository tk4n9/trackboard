# Architecture and evidence

Trackboard uses the macOS text input system to deliver recognized Unicode at
the client's insertion point. It does not paste through the clipboard or retain
an Accessibility element as a substitute for the active text input session.

## Input source

An `IMKServer` creates `TBInputController` instances for client input sessions.
The Objective-C controller forwards activation, deactivation, and key events to
the Swift coordinator. It retrieves its current client only when inserting text
and calls `insertText:replacementRange:` with an `NSNotFound` replacement
location. The active input client handles the selection and edit operation.
See Apple's [IMKInputController](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller)
and [IMKServerInput](https://developer.apple.com/documentation/inputmethodkit/imkserverinput).

Client proxies do not cross into Swift or survive asynchronous recognition work.
All input-session state stays on the main actor. When a session deactivates,
the overlay closes and candidates and ink are cleared. Recognition tokens also
change when ink, language, or correction settings change, so a worker completing
late cannot populate a newer session.

## Capture overlay

Nonactivating panels preserve the target application's focus. A panel on every
connected display accepts indirect `NSTouch` events, mapping normalized trackpad
positions to the drawing surface. This covers pointer motion without private
trackpad APIs, event taps, or cursor locking. The physical trackpad's aspect ratio
is preserved when rendering. Simultaneous nonresting fingers cancel an unfinished
stroke and require all fingers to lift; completed strokes remain intact.

`StrokeCapture` in the portable core owns the transitions used by this adapter.
Clear, Undo, Option navigation, and cancellation cannot restart a stroke midway
through the same contact. Raw touch input also takes ownership from duplicate
mouse events, preventing one physical gesture from producing two strokes.

Apple documents [trackpad events and normalized coordinates](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html)
and [nonactivating panels](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel).
Full-screen display behavior needs native checks; the window-level choice follows
[Apple DTS guidance](https://developer.apple.com/forums/thread/826308).

## Recognition

The worker rasterizes strokes on a padded white background, excluding all UI.
Vision revision 3 runs accurate text recognition in the selected supported
language. Candidate combinations are ranked and duplicate strings removed.
Text is normalized to NFC, preserving Hangul syllables. Explicit insertion avoids
committing low-confidence guesses automatically.

Apple's [Vision request documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
defines the supported-language query and recognition options. Apple's
[WWDC22 presentation](https://developer.apple.com/videos/play/wwdc2022/10024/)
introduces Korean recognition in revision 3. These sources establish API support,
not the accuracy of this app on handwriting. That must be measured on a Mac.

## Packaging

Swift Package Manager builds a standalone executable plus its linked bridge and
core. `scripts/build.sh` places it in an input-method app bundle and signs it.
`scripts/install.sh` installs only for the current account. Input source
registration uses Carbon's Text Input Source Services. A normal physical keyboard
continues to work when the pad is closed; the pad shortcut is handled only while
Trackboard is the selected input method.

On macOS, `scripts/build-paths.sh` chooses a per-checkout directory under
`~/Library/Caches/Trackboard/` for Swift scratch files and the app. Both test and
build wrappers use it so cloud-sync metadata cannot attach to generated bundles.
Packaging copies source resources without extended attributes and strips any
remaining attributes only from the generated app before signing. Source files
are not rewritten or stripped. See
[Apple QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html).

No network requests, handwriting persistence, analytics, or clipboard operations
are implemented. `UserDefaults` stores two preferences: recognition language
and spelling correction.
