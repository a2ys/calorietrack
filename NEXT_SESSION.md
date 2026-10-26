# Next session: fix sound lag and square corners (CalorieApp, Flutter)

Project: `C:\Aayush\Projects\CalorieApp`. Read `OPUS_HANDOFF.md` and the memory note on design preferences first. Last commits: `e17e59e` (UX fixes, gram logging), `30b0fbd` (sounds, 697-food library, swipe guards, macro check). Test on the real phone (Motorola edge 70, id `ZD2232FM22`, Android 17), not only headless Chrome: both bugs below only show on the device.

## 1. Sound effects lag and play late (top priority)
On the phone, sounds cause noticeable UI lag and don't play on the frame of the tap.

Current setup (`lib/core/utils/sounds.dart`): `audioplayers` 6.8.1 with an `AudioPool` per cue in `PlayerMode.lowLatency`, initialized in `main()` (not awaited). `Sounds.play` is called from every `Haptics.*` method (`lib/core/utils/haptics.dart`), so it fires very often: chips, steppers, tabs, every log. Cues are Kenney CC0 WAVs in `assets/sfx` (44.1 kHz, some stereo).

Likely causes to verify (measure, don't guess):
- `AudioPool.start()` runs inside a lock and awaits `setVolume` and then `resume` over the method channel on every play. That's several platform round trips per tap, and new players get created when the pool is busy.
- Six pools initializing at startup on the main isolate, which can cause jank at launch and on first plays.
- Stereo/44.1 kHz files, and possibly a decode on first play.

Direction: switch to a low-latency engine that plays preloaded buffers with no per-play round trips. Evaluate `flutter_soloud` (FFI, built for game/UI SFX) or a SoundPool-based approach. Keep the public API the same (`Sounds.init`, `Sounds.play(Sfx)`, `Sfx` enum, `Sounds.enabled`, `Sounds.debugOnPlay`) so `Haptics` and `test/sounds_test.dart` keep working. Also:
- Preload after the first frame, never block startup.
- Never await anything in `play()`.
- Convert cues to mono, short, trimmed PCM/OGG.
- Keep the existing rules: don't take audio focus or pause the user's music, stay muted in silent mode, throttle repeats.

Confirm on the device: no frame drops while tapping fast (check with a profile build / `flutter run --profile` performance overlay), and sound lands with the haptic.

## 2. Rounded shapes show a square/rectangular edge
On the phone, the rounded corners aren't truly round: a rectangle edge or border shows behind them in:
- The **bottom toasts** (SnackBars: floating, themed in `lib/core/theme/app_theme.dart` `snackBarTheme`, shape `AppRadii.tile`). Also check the inline undo pill in `lib/features/water/water_sheet.dart`.
- The **swipe animations** (`Dismissible` in `lib/core/widgets/entry_tile.dart`, `lib/features/meals/meal_builder_screen.dart`, `lib/features/water/water_sheet.dart`): the colored background and/or the sliding card show square corners or a rectangular outline while dragging.

Investigate with real screenshots (`C:\Studio\platform-tools\adb.exe -s ZD2232FM22 exec-out screencap -p > shot.png`), mid-swipe and with a toast showing. Suspects:
- Material 3 SnackBar elevation/shadow or surface tint drawn as a rectangle.
- Clip behavior: Dismissible's slide and size transitions clip to a rectangle, the background radius (`AppRadii.card` vs `AppRadii.tile`) doesn't match the card's radius, the background has a `margin` the card doesn't, and the shadow is drawn outside the rounded clip.

Fix so every rounded surface stays round through the whole animation, in light and dark mode. Sweep the app for the same pattern anywhere else (sheets, dialogs, cards with shadows, chips).

## Rules (learned the hard way)
- **Install with `adb install -r`** (`C:\Studio\platform-tools\adb.exe -s ZD2232FM22 install -r build\app\outputs\flutter-apk\app-release.apk`). Never `flutter install`: it uninstalls first and wipes the user's data.
- A release build takes about 8 min (`flutter build apk --release`). Don't wrap it in a `timeout`, which killed it last time. Run it in the background and check the log for "✓ Built" before installing.
- Don't run `dart format` (long-line codebase). Font is Plus Jakarta Sans only. Design tokens only from `app_theme.dart`. All feedback goes through `Haptics.*`, which also plays the sound.
- On Windows bash, inline heredocs mangle backslashes: write scripts to files.
- Before finishing: `flutter analyze` clean, `flutter test` green (95 tests now; kill a stale `flutter_tester.exe` if tests hang), verify on the phone, then commit.

## After those two, if time allows
- Spot-check chain-restaurant and brand nutrition in `lib/core/data/common_foods.dart` (McDonald's, KFC, Subway, Domino's, Starbucks, Haldiram's): values were entered from memory and are approximate.
- Remaining items in `OPUS_HANDOFF.md` (photo → meal, barcode scanning).
