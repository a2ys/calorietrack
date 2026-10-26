# Handoff: CalorieApp (Flutter) — what's left

Paste this into Opus. Project: `C:\Aayush\Projects\CalorieApp` (Flutter 3.47, Riverpod, go_router, Drift/SQLite, Plus Jakarta Sans). Windows + Android device (Motorola edge 70).

## Taste (from the user)
Premium, minimal, Uber-like (black/white, rounded, little clutter). Subtle springy motion, light haptics. **Logging food must be instant** (search a big catalog, one tap, no setup). Light mode default. App size up to ~100 MB is fine. They said the design "is premium now" — don't redesign, extend.

## Already built (don't redo)
Search-first Add food sheet (6k USDA + ~280 curated incl. Indian, aliases like "chawal"), Meals tab + meal builder + 18 preset plates, name/avatar onboarding, time-based greeting, haptic strength slider (default 70%, Settings only), water tracking (3 L default goal, editable), spring/press/sheet motion, swipe-down sheets, Twemoji (flat) for food/macros, Phosphor SVG icons for UI.

## Conventions (follow these)
- Design tokens only from `lib/core/theme/app_theme.dart` (spacing, radii, `AppMotion`, palette, type).
- Icons: `AppIcon(AppIcons.x)` (SVGs in `assets/icons`). **Do not add `phosphor_flutter`** — it doesn't compile on this Flutter. Emoji: `Emoji('🍛')`; art in `assets/emoji` (Twemoji SVG); new emoji need their SVG + an entry in `lib/core/widgets/emoji_assets.dart` (script approach: codepoint-named files from jsdelivr `jdecked/twemoji`).
- Sheets: `showAppSheet` (DraggableScrollableSheet + `SheetScope`/`sheetScrollPhysics`); dialogs: `showAppDialog`; haptics only via `Haptics.*`.
- Prefs live in the `Prefs` table via `AppPrefs`/`PrefKeys`. Schema is **v3**; after table changes add a migration and run `dart run build_runner build --delete-conflicting-outputs`.
- Font: Plus Jakarta Sans is **bundled** (`assets/fonts`, family `PlusJakartaSans`). Don't use `google_fonts` — release Android builds have no INTERNET permission, so runtime fetching silently fell back to Roboto.
- **Network features (photo AI, Open Food Facts) need `<uses-permission android:name="android.permission.INTERNET"/>`** added to `android/app/src/main/AndroidManifest.xml` (only debug/profile manifests have it today). The Settings copy says "stored on this device only" — update it honestly once photo/barcode send data out.
- Windows shell: inline bash heredocs with backslashes/quotes break — write scripts to files.

## Remaining work (priority order)
1. **Photo → meal (CalAI-style).** Reference screenshots: `C:\Aayush\Projects\CalorieTracker\onephoto.png`, `second.png`, `third.png`. Scanner screen (mode strip: Scan food / Barcode / Gallery / Saved / Manual, shutter, flash) → result sheet over the photo: floating ingredient labels, meal-type chip + time, quantity stepper, Calories/Carbs/Protein/Fats cards, health score, ingredients, "Fix Results" + "Done". Use the Claude API with vision returning structured JSON (dish name, items with grams + kcal/P/C/F, meal type guess); default meal type/time from `MealType.forTime(now)`, editable; log via `db.addEntry` (or as `MealItem`s). **Decide key handling first** (recommend a tiny backend proxy; a user-entered key in Settings is an acceptable stopgap). Use the `claude-api` skill for current model IDs. Needs `image_picker`/`camera` + Android CAMERA permission.
2. **Barcode scanning** (`mobile_scanner`) → Open Food Facts (`world.openfoodfacts.org/api/v2/product/{code}.json`, nutriments per 100 g) → "how much did you eat?" input (default 100 g, any grams) → scale macros (`Food.per100g` exists in `lib/core/data/food.dart`). Entry points: Add food + Meals builder. Not found → prefilled custom food. Cache scanned products.
3. **Tests never run after the last changes:** `haptics_test`, `water_test`, new DB water/prefs tests, `add_food_sheet_test` (incl. fling-to-dismiss). `flutter test` was blocked by a stale `flutter_tester` process locking `build\native_assets\windows\sqlite3.dll` — kill it first (`taskkill /F /IM flutter_tester.exe`). The widget-test teardown was changed to not close the Drift DB (it hung); verify.
4. Verify on a real phone: quick-flick swipe-down on sheets (only long drags were confirmed in headless Chrome), haptic feel, Twemoji look. If the flat emoji still isn't the wanted "iOS" look, Fluent 3D (MIT) is the closest open set (single files via jsdelivr `microsoft/fluentui-emoji`, names not codepoints).
5. Polish backlog: dark-mode pass over new screens (water, meals, builder), water on Progress tab, app icon/name.

## Handy
Headless screenshot harness (puppeteer-core + `flutter build web --dart-define=SEED=true`) was used for visual checks; `SEED=true` loads sample data. Install on phone: `flutter build apk --release` then `flutter install -d <id>`.
