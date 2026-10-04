# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`cupertino_native_better` is a Flutter plugin (published to pub.dev) that renders **native iOS/macOS UIKit/AppKit/SwiftUI controls** — including iOS 26 Liquid Glass — inside Flutter via platform views and per-instance method channels. Dart in `lib/`, Swift in `ios/` and `macos/`, demo app in `example/`.

Flutter SDK is pinned with FVM to **3.44.0** (`.fvm/fvm_config.json`). Prefix commands with `fvm ` if the global Flutter differs.

## Commands

```bash
flutter analyze                 # ALWAYS run after editing Dart (see AGENTS.md)
flutter test                    # unit/widget tests in test/
flutter test test/widget_test.dart                        # single file
flutter test test/widget_test.dart --plain-name 'CNSearchBar'   # single test/group

cd example && flutter run                                  # demo app (iOS 26 sim/device for glass)
cd example && flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=pr69
cd example && flutter test integration_test/plugin_integration_test.dart

tool/capture_docs.sh            # captures docs screenshots/videos from the example app via simctl
```

Lints: `analysis_options.yaml` enables `public_member_api_docs`, so **every public member under `lib/` needs a doc comment** or analyze fails. `example/`, `ios/`, `macos/` are excluded.

## Architecture

### Dart widget → native view contract

Every component follows the same shape (`lib/components/switch.dart` is the cleanest reference):

1. `build()` first decides **fallback vs native** — non-Apple platforms get a Material widget, iOS/macOS < 26 get a Cupertino widget, iOS/macOS 26+ get the platform view.
2. Gate creation on `PlatformViewGuard.isReady` where relevant, then check `ModalHideMixin.maybeHiddenPlaceholder(...)` and return the placeholder if non-null.
3. Build `creationParams` (a plain `Map<String, dynamic>`; colors go through `encodeStyle`/`resolveColorToArgb` in `lib/channel/params.dart` which resolve `CupertinoDynamicColor` against the current context and encode ARGB ints).
4. Render `UiKitView` (iOS) / `AppKitView` (macOS) with a `viewType` string like `CupertinoNativeSwitch`.
5. In `onPlatformViewCreated(id)`, open `MethodChannel('<viewType>_$id')` — **one channel per view instance** — and use it for imperative updates (`setValue`, `setStyle`, `setBrightness`, `setEnabled`, `setInteractive`) and for native→Dart callbacks via `setMethodCallHandler`.
6. State is diffed against `_lastX` fields in `didUpdateWidget`/`didChangeDependencies` so only changed properties cross the channel.

Public controllers (`CNSliderController`, `CNSwitchController`) are thin wrappers that `_attach`/`_detach` that same channel.

There is also one app-wide channel, `cupertino_native`, registered in `CupertinoNativePlugin.register` for `getPlatformVersion`, `getMajorOSVersion`, `beginTransition`, `endTransition`.

### Native side layout (mirrored for iOS and macOS)

`<platform>/cupertino_native_better/Sources/cupertino_native_better/`
- `CupertinoNativePlugin.swift` — registers every platform-view factory under its `viewType` id. A new widget must be registered here.
- `Factories/` — `FlutterPlatformViewFactory` per widget; creates the view and its `MethodChannel`.
- `Views/` — the actual `UIView`/`NSView` (or SwiftUI-hosting) implementation and its channel handler.
- `Shared/` — config structs shared between factory and view; `Utils/` — image/SVG loading, caching, spotlight, transition observation.

Both SPM (`Package.swift`, depends on SVGKit) and CocoaPods (`*.podspec`) packaging exist; keep both working when adding sources.

### Version detection

`PlatformVersion` (`lib/utils/version_detector.dart`) parses `Platform.operatingSystemVersion` **instead of** using a platform channel — this is the package's headline fix, because the channel approach returned null in release builds. It auto-initializes on first access and caches; on parse failure it assumes 26. Don't reintroduce async/channel-based version checks in widget build paths.

### PlatformView z-order / modal coordination

This is the subsystem most bugs live in, and it spans several files. On iOS, hybrid composition puts *all* `UiKitView`s from *all* routes into one shared container, so native pixels bleed through Flutter modals and glass halos leak over sheets.

- `CNTabBarRouteObserver` (in `lib/components/tab_bar.dart`) is the hub: a `NavigatorObserver` holding static `modalDepth`, `anyModalDepth`, and `topModalRect` notifiers. Apps must register it in `navigatorObservers`. `markAnyModalActive()`/`markAnyModalInactive()` cover overlays the observer can't see (e.g. `Scaffold.showBottomSheet`).
- `ModalHideMixin` (`lib/utils/modal_hide_mixin.dart`) destroys a widget's PlatformView while a sheet covers it, swapping in a same-size placeholder. It is **position-aware** when `topModalRect` is published, and uses a mount-depth snapshot so widgets *inside* a sheet don't self-destroy. Every PlatformView widget exposes `autoHideOnModal` to opt out.
- `CNBottomSheet` / `CNSheetGeometryProbe` (`lib/components/bottom_sheet.dart`) publish the live sheet rect each frame; raw `showModalBottomSheet` falls back to "hide everything on the route".
- `CNTransitionObserver` (`lib/utils/transition_observer.dart`) brackets route transitions with `beginTransition`/`endTransition` on the app-wide channel so native glass is suspended during animations.
- `PlatformViewGuard` (`lib/utils/platform_view_guard.dart`) delays platform-view creation by 500 ms **in debug only**, to dodge the hot-restart `recreating_view` exception without showing a fallback flash in release.

### Paint order vs platform views (route-transition artifacts)

The `PlatformViewLayer` artifacts filed under Issue #29 / #35 — a grey rectangle or band appearing mid-transition, often nowhere near the native control — are triggered by **Flutter content painted above a platform view**, not by the platform view's own presence.

On iOS, Flutter cannot paint over a native view directly; it cuts an *overlay layer* for any of its own content that paints after one. Under a route's transform that overlay can land in the wrong place and be filled with background, clipping whatever Flutter widget happened to be there — mid-widget, which is how you tell it from a layout bug.

Observed on Flutter 3.47.1 / iOS 26.2, three pages, consistent:

| page | shape | artifact |
|---|---|---|
| `pr66_glass_image_asset_tint_test.dart` | glass buttons inside the `ListView`, nothing painted after | none |
| `issue29_transition_test.dart` | `Column`: `CNButton`s, then `Text`s painted after them | yes — the page is named for it |
| `soft_chat_ui_demo.dart` (before) | `Column`: `Stack(list, top bar)`, then the composer painted after | grey box over the composer |
| `soft_chat_ui_demo.dart` (after) | one `Stack`, top bar painted last | none |

So the rule for any screen hosting CN widgets: **keep native controls last in their route's paint order.** A bottom bar, FAB, or snackbar painted after one re-introduces the whole class.

The package's own mitigation is different and heavier-handed: `CNTabBar.autoHideOnPageTransition` unmounts the platform view for the duration of the animation (`tab_bar.dart:256`), and the note at `tab_bar.dart:248` describes the symptom as a hybrid-composition limitation "not something the Swift side can fix". True, but avoidable in Dart by ordering — and no equivalent flag exists on `CNButton`, `CNGlassButtonGroup` or the other glass widgets, so ordering is the only lever a consumer has there. `autoHideOnPageTransition` also only watches `secondaryAnimation` (another route animating *over* the bar), never the route's own `animation`, so a page animating in or out is unprotected either way.

### Icons

All icon-bearing widgets resolve, in priority order: `imageAsset` (PNG/SVG/JPG, resolution-picked 1x–4x) → `customIcon` (`IconData`) → `icon` (`CNSymbol`, an SF Symbol). `lib/utils/icon_renderer.dart` rasterizes `IconData` to bytes and **memoizes by future identity** — callers rely on getting the same `Future` instance back so `FutureBuilder` doesn't resubscribe and flash a placeholder. Preserve that contract (`test/icon_renderer_cache_test.dart` asserts it).

## Adding a widget

Per `AGENTS.md`, mirror an existing widget rather than inventing a shape:

1. `lib/components/<name>.dart` — one file, one class, fallbacks included.
2. Export from `lib/cupertino_native_better.dart` (and `lib/cupertino_native.dart`, the legacy barrel, if it belongs to the older surface).
3. Swift `Factories/` + `Views/` for **both** iOS and macOS, registered in each `CupertinoNativePlugin.swift`.
4. A demo page in `example/lib/demos/`, wired into the list in `example/lib/main.dart`.
5. `flutter analyze`.

## Repo conventions

- `example/lib/demos/` doubles as a **regression gallery**: pages are named `issueNN_*.dart` / `prNN_*.dart` after the GitHub issue or PR they reproduce, and stay in the app after the fix ships. New bug fixes get a matching page.
- `example/lib/pr_probe_entry.dart` and `sweep_entry.dart` are `--dart-define`-driven entrypoints for screenshot-diff verification on the simulator (no tap automation available); `sweep_entry.dart` deliberately uses only long-standing API so it compiles against both pre-change and post-change trees.
- `CHANGELOG.md` entries are unusually detailed — they explain the root cause, the fix, what was measured to verify it, and what was deliberately left unfixed. Match that depth. Version bumps follow the source-compatibility impact (e.g. adding an enum value → minor, not patch).
