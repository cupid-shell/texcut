# texcut

A fast, **ad-free, fully-unlocked** text expander for Android. Define short
triggers like `;email` or `;br` and texcut types the full text for you — inside
the app *and system-wide* in any other app, powered by a native Android
accessibility service.

There is no premium tier, no paywall, and no tracking. Every feature is on by
default and all your data stays on the device.

## Features

- **System-wide expansion** — type a shortcut in any app and it expands in
  place, via an Android `AccessibilityService`.
- **Dynamic tokens** in expansions:
  - `{date}`, `{time}`, `{datetime}` — current date/time using your formats
  - `{date:PATTERN}` — a custom date pattern (e.g. `{date:EEE, MMM d}`)
  - `{clipboard}` — current clipboard contents
  - `{cursor}` — where the caret lands after expansion
  - `{{` / `}}` — literal braces
- **Trigger modes** — expand *instantly* on an exact match, or only *after a
  delimiter* (space/punctuation) to avoid expanding prefixes of real words.
- **Word-boundary protection**, optional **case sensitivity**, and **haptic
  feedback** on expansion.
- **Groups, search, enable/disable** per snippet.
- **Live preview** and a "try it" field in the editor that runs the real
  expansion engine.
- **Backup**: export the whole library to JSON / import it back (merge or
  replace).

## Project layout

```
.
├── lib/                      # Flutter app (UI + canonical expansion engine)
│   ├── models/               # Snippet, ExpansionSettings
│   ├── services/             # Expander, repository, native bridge, seed data
│   ├── state/                # AppState (ChangeNotifier)
│   └── ui/                   # screens, widgets, theme
├── test/                     # Unit tests for the expansion engine & models
└── android/                  # Native Android host + accessibility service
    └── app/src/main/kotlin/com/texcut/app/
        ├── MainActivity.kt                      # MethodChannel bridge
        ├── TextExpanderAccessibilityService.kt  # system-wide expansion
        ├── ExpansionEngine.kt                   # Kotlin port of the Dart engine
        └── SnippetStore.kt                      # reads the shared prefs
```

### How the two sides stay in sync

The Flutter `shared_preferences` plugin and the native service share **one
source of truth**: the same `FlutterSharedPreferences` file. Flutter writes the
snippet list and settings as JSON under `texcut.snippets` / `texcut.settings`;
the accessibility service reads them back (the plugin prefixes keys with
`flutter.`, so natively they are `flutter.texcut.snippets` etc.). A tiny
`MethodChannel` (`com.texcut.app/accessibility`) is used only to check the
service status and open the system settings screen.

The expansion logic exists twice — `lib/services/expander.dart` (canonical) and
`android/.../ExpansionEngine.kt` (a faithful port) — kept behaviourally
identical so expansions feel the same everywhere. The Dart version is covered by
unit tests in `test/expander_test.dart`.

## Getting started

This repository contains the full source. The Flutter tool regenerates the
machine-specific bits on first build (`local.properties`, the Gradle wrapper
jar, plugin registrants — all git-ignored).

```bash
flutter pub get
flutter test          # run the expansion-engine unit tests
flutter run           # build & launch on a connected Android device
```

Requirements: Flutter ≥ 3.19 (Dart ≥ 3.3), Android `minSdk` 26 (Android 8.0).

### Enabling system-wide expansion

1. Launch texcut and add or keep a few snippets.
2. Tap **Open** on the banner (or **Settings → Accessibility service**).
3. In Android's *Accessibility* settings, enable **texcut text expander**.
4. Type a shortcut in any app — it expands in place.

> Note: On Android 10+ the OS only lets foreground/IME/default apps read the
> clipboard, so `{clipboard}` may resolve to empty when expanding in the
> background. All other tokens work everywhere.
