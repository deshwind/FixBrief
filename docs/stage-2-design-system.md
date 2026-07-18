# FixBrief Stage 2 — Liquid Glass design system and prototypes

## 1. Delivery summary

Stage 2 is complete. It adds a reusable, Material 3-based Liquid Glass visual
system and three navigable prototypes while preserving the architecture and
security boundaries from Stage 1. No authentication, database, storage, or AI
network implementation has been pulled forward from later stages.

The application starts on `/customer`. The header actions navigate to
`/assessment` and `/repairer`; each route uses a 420 ms fade-and-slide
transition that becomes immediate when platform animations are disabled.

## 2. Design-system structure

The design system is divided into theme primitives and reusable widgets:

| Layer | Responsibility |
|---|---|
| `LiquidGlassColors` | Semantic light/dark surfaces, text, borders, backgrounds, statuses, and repair-category accents. |
| `LiquidGlassTokens` | Blur, surface/border/highlight opacity, shadows, radii, navigation dimensions, and content spacing. |
| `LiquidGlassTypography` | Responsive Material text hierarchy with readable weights, line heights, and letter spacing. |
| `LiquidGlassTheme` | Complete light/dark `ThemeData`, Material component defaults, and registered theme extensions. |
| `MotionTokens` | 130–420 ms interaction durations, a restrained 20-second ambient loop, and shared curves. |
| `AccessibilityEffectsState` | Resolves full, reduced, or minimal effects against user preview controls and `MediaQuery`. |

Brand accents use cool blue, cyan, and soft teal. Category colours remain
centralised so later feature flows do not embed one-off colour values.

## 3. Reusable component library

| Component | Intended use |
|---|---|
| `LiquidGlassContainer` | Core clipped/blurred surface with opacity, border, radius, shadow, tint, and semantic overrides. |
| `LiquidGlassCard` | Optional tappable card with restrained press feedback. |
| `LiquidGlassButton` | Primary, secondary, and destructive actions with busy/disabled states. |
| `LiquidGlassNavigationBar` | Floating, safe-area-aware navigation with selected semantics and labels. |
| `LiquidGlassAppBar` | Glass header surface for later feature screens. |
| `LiquidGlassBottomSheet` | Bounded modal sheet with drag handle and keyboard-safe padding. |
| `LiquidGlassDialog` | Accessible dialog shell with reusable actions. |
| `LiquidGlassTextField` | Label, supporting/error text, prefixes/suffixes, and standard focus styling. |
| `LiquidGlassSearchBar` | Search-specific field composition. |
| `LiquidGlassChip` | Compact selectable/filter label. |
| `LiquidGlassStatusPill` | Semantic neutral/info/success/warning/danger statuses. |
| `LiquidGlassProgressIndicator` | Determinate or indeterminate progress with accessible labelling. |
| `FluidBackground` | Repaint-isolated ambient gradient and low-frequency moving glows. |
| `LiquidGlassPreviewSettingsButton` | Stage 2 theme, motion, and transparency preview controls. |

The component APIs accept content, callbacks, semantic labels, and visual
overrides without depending on customer or repairer feature classes.

## 4. Prototype screens

### Customer home — `/customer`

- Branded greeting and prominent repair-request action.
- Active repair summary, eight category entry points, safety reminder, and
  recent activity.
- Four-item customer floating navigation.
- Header shortcuts to both other Stage 2 prototypes.
- Later-stage actions produce an explicit stage message rather than pretending
  to save or contact a backend.

### Repairer dashboard — `/repairer`

- Daily metrics, privacy-safe matching requests using coarse areas and
  approximate distance, appointments, current job, and earnings summary.
- Five-item repairer floating navigation.
- No exact customer address or contact detail is exposed.

### AI assessment — `/assessment`

- The exact persistent disclaimer: **AI-assisted assessment — not a confirmed
  diagnosis.**
- A visual-only processing preview that explicitly states no request is sent.
- Structured example result with summary, possible categories, possible
  causes, confidence language, safety status, recommended professional, and
  follow-up questions.
- Wording avoids presenting the prototype result as a diagnosis.

## 5. Accessibility and effect fallback

Glass is decorative, not the only carrier of structure or status. The
accessibility effects controller combines preview preferences with platform
signals:

- high contrast or reduce-transparency selects the minimal mode;
- minimal mode removes blur and raises the surface opacity to `0.96`;
- reduced mode halves blur and increases surface opacity;
- reduce motion, disabled animations, accessible navigation, or minimal mode
  suppresses ambient motion;
- selected navigation destinations expose selected semantics as well as colour;
- important icons have tooltips/semantic labels, and status is always written
  as text;
- layouts use wrapping, grids, constraints, and scroll views to tolerate larger
  text and mobile/tablet widths.

## 6. Performance decisions

- `BackdropFilter` work is clipped to each rounded glass surface.
- The fluid background is inside a `RepaintBoundary` and repaints through its
  painter rather than rebuilding the widget tree.
- Ambient animation is slow and pauses when ticker policy or accessibility
  settings disable it.
- Minimal mode bypasses blur entirely.
- Prototype lists are deliberately small; later data-backed lists should use
  lazy slivers and pagination.

## 7. Run and verification commands

Flutter 3.44.6 and Dart 3.12.2 are installed at `C:\src\flutter`.

```powershell
cd C:\Users\User\Desktop\RepairQuote
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\dart.bat run build_runner build --delete-conflicting-outputs
C:\src\flutter\bin\dart.bat format --output=none --set-exit-if-changed lib test
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat build apk --debug
C:\src\flutter\bin\flutter.bat run --dart-define-from-file=config/env.dev.json
```

The Stage 2 automated suite covers initial routing through all three prototypes,
the AI disclaimer/content, repairer matching content, floating-navigation
selection, and accessibility effect resolution.

Verified on this workstation:

- `build_runner`: successful, with no source generators required yet;
- `flutter analyze`: no issues;
- `flutter test`: five tests passed;
- Android debug build: successful at
  `build/app/outputs/flutter-apk/app-debug.apk`.

## 8. Client environment and manual Supabase work

Copy `config/env.example.json` to the ignored `config/env.dev.json` and provide:

| Name | Client-safe value |
|---|---|
| `APP_ENV` | `development`, `staging`, or `production` |
| `SUPABASE_URL` | The environment's Project URL |
| `SUPABASE_ANON_KEY` | Its anon or publishable client key |

Stage 2 requires no new manual Supabase work. Do not create tables, policies,
buckets, or Edge Functions for this stage. Supabase client initialisation starts
with Stage 3, migrations and row-level security arrive in Stage 4, and the AI
Edge Function arrives in Stage 6.

## 9. Stage 2 file manifest

### Application and routing

| Path | Purpose |
|---|---|
| `lib/app/app.dart` | Riverpod-aware root app with light/dark Liquid Glass themes. |
| `lib/core/routing/app_paths.dart` | Prototype route constants. |
| `lib/core/routing/app_router.dart` | Three routes and accessibility-aware page transitions. |
| `android/build.gradle.kts` | Generated Android build plus a scoped `file_picker` AGP 9/Kotlin compatibility bridge. |

### Theme

| Path | Purpose |
|---|---|
| `lib/core/theme/accessibility_effects_controller.dart` | Effect preferences and platform fallback resolution. |
| `lib/core/theme/app_theme_mode.dart` | System/light/dark theme state. |
| `lib/core/theme/liquid_glass_colors.dart` | Semantic and category colour extension. |
| `lib/core/theme/liquid_glass_theme.dart` | Light and dark Material themes. |
| `lib/core/theme/liquid_glass_tokens.dart` | Glass effect and shape tokens. |
| `lib/core/theme/liquid_glass_typography.dart` | Shared type scale. |
| `lib/core/theme/motion_tokens.dart` | Durations and curves. |

### Components

| Path |
|---|
| `lib/core/widgets/liquid_glass/fluid_background.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_app_bar.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_bottom_sheet.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_button.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_card.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_chip.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_container.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_dialog.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_navigation_bar.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_preview_settings.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_progress_indicator.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_search_bar.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_status_pill.dart` |
| `lib/core/widgets/liquid_glass/liquid_glass_text_field.dart` |

### Prototypes and tests

| Path | Purpose |
|---|---|
| `lib/features/customer_home/presentation/screens/customer_home_screen.dart` | Customer home prototype. |
| `lib/features/repairer_dashboard/presentation/screens/repairer_dashboard_screen.dart` | Repairer dashboard prototype. |
| `lib/features/ai_assessment/presentation/screens/ai_assessment_screen.dart` | AI assessment prototype. |
| `test/app_smoke_test.dart` | Cross-prototype navigation and content smoke test. |
| `test/core/theme/accessibility_effects_controller_test.dart` | Effect fallback unit tests. |
| `test/core/widgets/liquid_glass_navigation_bar_test.dart` | Floating-navigation widget test. |

The Flutter host projects and dependency lock were also generated:
`android/`, `ios/`, `.metadata`, and `pubspec.lock`.

## 10. Known limitations

- All displayed repair, quote, appointment, matching, earnings, and assessment
  data is static prototype data.
- Theme/effect choices are preview-only and are not persisted yet.
- Customer and repairer secondary destinations show stage messages; their
  feature flows arrive in later stages.
- No backend request, authentication, upload, local database, geolocation,
  notification, or AI call occurs in Stage 2.
- Native signing, production identifiers, permissions, and deployment checks
  remain later-stage work.
- `file_picker 11.0.2` does not honour Flutter's
  `android.builtInKotlin=false` compatibility flag under AGP 9. The Android
  root build temporarily applies Kotlin/JVM 17 to that plugin. Remove the
  bridge after a compatible stable plugin release is adopted.
- `flutter doctor` still reports the Android SDK command-line tools package as
  missing even though the debug APK builds. Install **Android SDK Command-line
  Tools (latest)** from Android Studio's SDK Manager and run
  `flutter doctor --android-licenses` before CI/release setup.
- Windows desktop tooling is not installed and is not required for the scoped
  Android/iOS mobile project. iOS compilation requires macOS/Xcode later.

Stage 2 stops here. Do not begin Stage 3 until the user says **continue**.
