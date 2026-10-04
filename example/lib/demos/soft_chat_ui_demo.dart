import 'dart:ui' show lerpDouble;

import 'package:cupertino_native_better/cupertino_native_better.dart'
    show
        CNBottomSheet,
        CNButton,
        CNButtonConfig,
        CNButtonData,
        CNButtonDataConfig,
        CNButtonStyle,
        CNGlassButtonGroup,
        CNGlassEffect,
        CNGlassEffectShape,
        CNTabBarRouteObserver,
        CNSymbol,
        LiquidGlassConfig,
        LiquidGlassContainer;
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageRoute, CupertinoTheme;
import 'package:flutter/material.dart';

/// A real-world screen, ported verbatim from the `soft_chat_ui` sample: an
/// AI-chat page built entirely out of one soft control style — off-white
/// fills, hairline borders, barely-there shadows.
///
/// ### Why it is here
///
/// Every demo page in this gallery is a probe: a synthetic arrangement built
/// to make one artifact obvious. This one is the opposite — an ordinary
/// product screen, with the spacing, type scale and control density of a real
/// app. It is the host page to drop CN widgets into when a probe says a fix
/// works and the question becomes whether it still works in a screen somebody
/// would ship.
///
/// **It contains no platform views.** Nothing here exercises the plugin yet:
/// all nine controls are Flutter `SoftSurface`s. Ported as-is on purpose, so
/// the baseline is the design rather than something already adapted to the
/// plugin.
///
/// Two things make it a useful surface for the modal / transition work:
///
///  * The `TextField` in the input bar is the exact widget Issue #31 made
///    invisible inside a sheet — here it sits in a real input bar rather than
///    alone on a probe page.
///  * The message list is dense Flutter content running edge to edge, which
///    is what the Issue #29 follow-up occlusion needs in order to show.
///
/// ### Deviations from the zip
///
/// Three, all noted at their call sites:
///
///  1. The 12 source files are one file here, matching the rest of
///     `example/lib/demos/`. Class names and structure are unchanged.
///  2. The top bar's menu button pops the route. The design's `onMenu` is a
///     no-op callback, and with no `CupertinoNavigationBar` on this page that
///     would leave swipe-back as the only way out.
///  3. `SoftControlTheme.dark()` is **not** from the zip — the source defines
///     only `.light()`. It is derived from the light set by mirroring each
///     relationship rather than inverting the hexes: surfaces step *away*
///     from the background in the same direction pressed states do (light
///     goes `FFF -> F5 -> ED` darker, dark goes `0D -> 1C -> 26` lighter),
///     the border keeps its hairline contrast against the surface (1.37:1
///     light, 1.51:1 dark), the disabled border sits closer to the surface
///     than the enabled one, and neither foreground is a pure black or
///     white. The page follows the gallery's brightness, so a new dark
///     token can be judged against the light original by flipping the
///     sun/moon button and pushing this page again.
///  4. The plus button opens an attachment sheet. `onAttach` is a no-op in
///     the zip, so [AttachmentSheet] is new UI built from the existing soft
///     components. It is opened with `CNBottomSheet.show` rather than
///     `showModalBottomSheet` — identical appearance and gestures (every
///     parameter is forwarded), but it injects the geometry probe that
///     publishes the sheet's live rect to
///     `CNTabBarRouteObserver.topModalRect`. Nothing consumes that yet,
///     because this page has no platform views; it means that when CN
///     widgets do land here, a half-height sheet will hide only the widgets
///     actually behind it instead of everything on the route. A half sheet
///     over a page whose controls are at the top is the exact case where
///     position-aware hide earns its keep.
///  5. The attachment card opens the style guide it names, as a Cupertino
///     stacked-card sheet ([StyleGuideSheet]). Also new UI — `onTap` is a
///     no-op in the zip — and also opened through the package
///     (`CNBottomSheet.showCupertino`) for the probe. Its nine sections are
///     the nine the assistant turn claims the file covers, written from the
///     token values in this file, so the page documents its own style
///     instead of showing placeholder prose.
///  6. The three top-bar controls — menu, new chat, more — render as iOS 26
///     Liquid Glass instead of soft surfaces: [CNButton.icon] for the menu,
///     and one [CNGlassButtonGroup] for the pair, sharing a
///     `glassEffectUnionId` so the two capsules merge the way the stadium
///     [SoftIconPill] reads as one shape. The soft versions are kept, not
///     replaced: [ChatTopBar.liquid] is `false` away from them, and
///     [SoftCircularButton] / [SoftIconPill] are untouched.
///
///     This is also the change that gives the page its first platform
///     views, which makes the two sheets interesting: the top bar is at the
///     top, the attachment sheet covers the bottom half, so a correct
///     position-aware hide leaves these three controls alone while a blunt
///     one destroys them. `autoHideOnModal` is left at its default on both.
///  7. The style-guide card is glass too — [AttachmentCard.liquid], same
///     keep-the-old-widget pattern, with the soft row content unchanged
///     inside a [LiquidGlassContainer]. Its 56 pt height and 28 pt radius
///     are a capsule, so it asks for `CNGlassEffectShape.capsule` rather
///     than a `rect` that happens to be rounded by half its height.
///
///     This one is the harder case of the two, and the reason to have it:
///     the card lives inside the `ListView`, so it is a platform view that
///     **scrolls**, and it scrolls under the top bar's gradient fade —
///     Flutter content painted above a platform view, which is what forces
///     hybrid composition to cut an overlay. Watch the card's top edge as it
///     passes under the fade.
///  8. [ChatTopBar.modalBehavior] decides what the glass controls do when a
///     sheet covers them, and defaults to [TopBarModalBehavior.swapToSoft]:
///     the bar watches the same two notifiers `ModalHideMixin` watches,
///     drops the CN widgets from the tree when the sheet's rect overlaps its
///     own, and renders [SoftCircularButton] / [SoftIconPill] in their
///     place. The platform views are destroyed either way, so the Issue #53
///     bleed stays fixed; the difference is that the slot keeps a drawn
///     control instead of the mixin's empty same-size `SizedBox`. Because
///     the decision is made a level up, the soft widgets are the fallback
///     *content*, which the package has no way to supply from inside a CN
///     widget.
///
///     [TopBarModalBehavior.hideToGap] hands the job back to the package
///     (`autoHideOnModal: true`) for comparison, and
///     [TopBarModalBehavior.keepGlass] keeps the views alive — glass over
///     the sheet, and tappable through it, since
///     `wrapWithModalInteractionGuard` and the native `setInteractive` call
///     are both disabled in the mixin right now (`TAPPING-FIX REVERT`,
///     modal_hide_mixin.dart:127 and :181).
///
///     The two sheets exercise both sides of the geometry: the half-height
///     attachment sheet never reaches the top bar, so it should stay glass,
///     while the full-screen style guide covers it and should swap.
///
///     `swapToSoft` also swaps while the host route's `secondaryAnimation`
///     runs, not only once the sheet's rect overlaps the bar. Overlap alone
///     is too late: for most of a `CupertinoSheetRoute` push the sheet is
///     still below the bar, the glass is still mounted, and the frames in
///     between show the hybrid-composition overlay quad — a grey band across
///     the union of the platform views, much wider than the controls
///     themselves. Observed on Flutter 3.47.1 / iOS 26.2, which is also
///     evidence that the Issue #29 follow-up occlusion is still live on
///     current Flutter. [TopBarModalBehavior.hideToGap] does **not** cover
///     this: `autoHideOnModal` keys off modal depth and geometry, and
///     [CNButton] has no page-transition hide of its own the way `CNTabBar`
///     does with `autoHideOnPageTransition`.
///
///  9. The voice button opens the same [AttachmentSheet] at
///     `heightFactor: 1`, which exists to test the other route family. The
///     style guide is a `CupertinoSheetRoute` (a `PageRoute`: it scales the
///     page behind it, and a transform over a subtree holding platform views
///     is the likely cause of the grey band). A full-height
///     `showModalBottomSheet` is a `PopupRoute`: it leaves the page static,
///     and `CupertinoPageRoute.canTransitionTo` rejects it, so this route's
///     `secondaryAnimation` never runs and deviation 8's swap never fires
///     during its slide. It still covers the top bar once settled, so the
///     geometry path catches it a frame late. Band on the guide but not here
///     points at the transform; band on both points at mere presence of a
///     mounted platform view under an animating overlay, and the fix becomes
///     a depth-only trigger.
class SoftChatUiDemoPage extends StatelessWidget {
  const SoftChatUiDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The gallery's sun/moon button drives CupertinoApp's theme, so that is
    // where this page's brightness comes from. `brightness` is null when the
    // app follows the OS, hence the platform fallback.
    final brightness =
        CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final tokens = isDark
        ? const SoftControlTheme.dark()
        : const SoftControlTheme.light();

    // Mirrors the sample's own main.dart: the tokens are registered as a
    // ThemeData extension rather than read from a const, so `context.soft`
    // resolves the same way it does in the source app. (`context.soft` falls
    // back to `.light()` when unregistered, so this is belt and braces — but
    // it keeps the real code path live.)
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: tokens.background,
        extensions: <ThemeExtension<dynamic>>[tokens],
      ),
      child: const ChatScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// core/ui/soft — the style, in one place
// ---------------------------------------------------------------------------

/// Tokens for the soft control style. Register via ThemeData.extensions;
/// falls back to [SoftControlTheme.light] when missing.
@immutable
class SoftControlTheme extends ThemeExtension<SoftControlTheme> {
  const SoftControlTheme({
    required this.background,
    required this.surface,
    required this.surfacePressed,
    required this.border,
    required this.borderDisabled,
    required this.shadow,
    required this.foreground,
    required this.mutedForeground,
    this.shadowBlur = 4,
    this.shadowDy = 2,
  });

  const SoftControlTheme.light()
    : background = const Color(0xFFFFFFFF),
      surface = const Color(0xFFF5F5F5),
      surfacePressed = const Color(0xFFEDEDED),
      border = const Color(0xFFD2D2D2),
      borderDisabled = const Color(0xFFE6E6E6),
      shadow = const Color(0x10000000),
      foreground = const Color(0xFF111111),
      mutedForeground = const Color(0xFF8C8C8C),
      shadowBlur = 4,
      shadowDy = 2;

  /// Derived counterpart to [SoftControlTheme.light] — see the deviation note
  /// on [SoftChatUiDemoPage]. Surfaces are raised off the background instead
  /// of recessed into it, which is the one relationship that has to flip: a
  /// shadow does almost no work on a near-black ground, so the step from
  /// `background` to `surface` is what carries the depth.
  const SoftControlTheme.dark()
    : background = const Color(0xFF0D0D0D),
      surface = const Color(0xFF1C1C1C),
      surfacePressed = const Color(0xFF262626),
      border = const Color(0xFF3A3A3A),
      borderDisabled = const Color(0xFF262626),
      shadow = const Color(0x33000000),
      foreground = const Color(0xFFF2F2F2),
      mutedForeground = const Color(0xFF9A9A9A),
      shadowBlur = 4,
      shadowDy = 2;

  final Color background;
  final Color surface;
  final Color surfacePressed;
  final Color border;
  final Color borderDisabled;
  final Color shadow;
  final Color foreground;
  final Color mutedForeground;

  /// Resting shadow geometry. Pressed halves both (4/2 → 2/1, the guide's
  /// values), which is why they are tokens rather than literals: the glass
  /// stand-ins in [ChatTopBar] need a much wider, lower shadow.
  final double shadowBlur;
  final double shadowDy;

  @override
  SoftControlTheme copyWith({
    Color? background,
    Color? surface,
    Color? surfacePressed,
    Color? border,
    Color? borderDisabled,
    Color? shadow,
    Color? foreground,
    Color? mutedForeground,
    double? shadowBlur,
    double? shadowDy,
  }) {
    return SoftControlTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      border: border ?? this.border,
      borderDisabled: borderDisabled ?? this.borderDisabled,
      shadow: shadow ?? this.shadow,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowDy: shadowDy ?? this.shadowDy,
    );
  }

  @override
  SoftControlTheme lerp(ThemeExtension<SoftControlTheme>? other, double t) {
    if (other is! SoftControlTheme) return this;
    return SoftControlTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderDisabled: Color.lerp(borderDisabled, other.borderDisabled, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      shadowBlur: lerpDouble(shadowBlur, other.shadowBlur, t)!,
      shadowDy: lerpDouble(shadowDy, other.shadowDy, t)!,
    );
  }
}

/// Resolves the soft tokens for a context, falling back to the light set.
extension SoftControlThemeContext on BuildContext {
  SoftControlTheme get soft =>
      Theme.of(this).extension<SoftControlTheme>() ??
      const SoftControlTheme.light();
}

/// The shared look: light fill, hairline border, barely-there shadow.
/// Every soft control is built on this so the style lives in one place.
class SoftSurface extends StatelessWidget {
  const SoftSurface({
    super.key,
    required this.child,
    this.circle = false,
    this.radius = 24,
    this.width,
    this.height,
    this.padding,
    this.pressed = false,
    this.enabled = true,
  });

  final Widget child;
  final bool circle;
  final double radius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool pressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      padding: padding,
      alignment: circle ? Alignment.center : null,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        color: pressed ? soft.surfacePressed : soft.surface,
        border: Border.all(color: enabled ? soft.border : soft.borderDisabled),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: soft.shadow,
                  blurRadius: pressed ? soft.shadowBlur / 2 : soft.shadowBlur,
                  offset: Offset(
                    0,
                    pressed ? soft.shadowDy / 2 : soft.shadowDy,
                  ),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Bare icon with a comfortable tap target, for use inside soft surfaces.
class SoftIconTap extends StatefulWidget {
  const SoftIconTap({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 22,
    this.tapTarget = 44,
    this.color,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final double tapTarget;
  final Color? color;

  @override
  State<SoftIconTap> createState() => _SoftIconTapState();
}

class _SoftIconTapState extends State<SoftIconTap> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final opacity = !_enabled ? 0.35 : (_pressed ? 0.5 : 1.0);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        child: SizedBox.square(
          dimension: widget.tapTarget,
          child: Center(
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 100),
              child: Icon(
                widget.icon,
                size: widget.size,
                color: widget.color ?? context.soft.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon control (back, menu, close, …). Disabled when [onPressed] is
/// null.
class SoftCircularButton extends StatefulWidget {
  const SoftCircularButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 56,
    this.iconSize,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;

  @override
  State<SoftCircularButton> createState() => _SoftCircularButtonState();
}

class _SoftCircularButtonState extends State<SoftCircularButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // ~40% of the container keeps the guide's negative space at any size.
    final iconSize = widget.iconSize ?? (widget.size * 0.4).roundToDouble();

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 100),
          child: SoftSurface(
            circle: true,
            width: widget.size,
            height: widget.size,
            pressed: _pressed,
            enabled: _enabled,
            child: Icon(
              widget.icon,
              size: iconSize,
              color: context.soft.foreground.withValues(
                alpha: _enabled ? 1 : 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One action inside a [SoftIconPill].
class SoftIconPillAction {
  const SoftIconPillAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
}

/// Groups related icon actions in one stadium-shaped soft surface.
class SoftIconPill extends StatelessWidget {
  const SoftIconPill({
    super.key,
    required this.actions,
    this.height = 44,
    this.iconSize = 18,
    this.horizontalPadding = 6,
    this.spacing = 0,
  });

  final List<SoftIconPillAction> actions;
  final double height;
  final double iconSize;

  /// Inset between the stadium's ends and the first/last tap target.
  final double horizontalPadding;

  /// Gap between adjacent tap targets.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      height: height,
      radius: height / 2,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) SizedBox(width: spacing),
            SoftIconTap(
              icon: action.icon,
              semanticLabel: action.semanticLabel,
              onPressed: action.onPressed,
              size: iconSize,
              tapTarget: height,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// features/chat — the screen
// ---------------------------------------------------------------------------

/// How the glass top-bar controls react to a sheet covering them.
enum TopBarModalBehavior {
  /// Keep the platform views alive and visible. Re-exposes the Issue #53
  /// bleed: the glass draws over the sheet rather than under it.
  keepGlass,

  /// The package default — `autoHideOnModal: true`. The platform view is
  /// destroyed and `ModalHideMixin` leaves a same-size empty `SizedBox`, so
  /// the control's slot is held but nothing is drawn in it.
  hideToGap,

  /// Destroy the platform view *and* put the soft widget in its place, so
  /// the control is still drawn while the sheet is up.
  swapToSoft,

  /// As [swapToSoft], but on modal *depth* alone — the moment any sheet
  /// opens, covered or not, overlapping or not. There is then no native view
  /// anywhere on the bar while a modal is up, which makes it the control
  /// case: anything still happening up there cannot be coming from a
  /// platform view, because there isn't one.
  swapOnAnyModal,
}

/// Top controls over a fade, so messages scroll under them.
class ChatTopBar extends StatefulWidget {
  const ChatTopBar({
    super.key,
    required this.onMenu,
    required this.onNewChat,
    required this.onMore,
    this.onDetails,
    this.liquid = true,
    this.modalBehavior = TopBarModalBehavior.swapToSoft,
    this.debugForceSoft = false,
  });

  final VoidCallback onMenu;
  final VoidCallback onNewChat;
  final VoidCallback onMore;

  /// Adds an `info.circle` button to the pill, between new chat and more.
  /// The demo pushes [ChatDetailsPage] from it — a page route, which is what
  /// drives this bar's `secondaryAnimation` and so its swap to soft.
  final VoidCallback? onDetails;

  /// Render the three controls as iOS 26 Liquid Glass platform views
  /// ([CNButton.icon] + [CNGlassButtonGroup]) instead of the soft surfaces.
  /// Set `false` for the original, platform-view-free top bar.
  final bool liquid;

  /// What happens to those platform views when a sheet covers them. Ignored
  /// when [liquid] is false — there is no platform view to hide.
  final TopBarModalBehavior modalBehavior;

  /// Pin a [liquid] bar in its swapped-to-soft state, glass-matched tokens
  /// and all, so a screenshot can set it beside the glass it replaces
  /// (`PROBE=softbar`). Not a mode for real use.
  final bool debugForceSoft;

  /// 44 pt to match [SoftCircularButton]'s size in the soft branch, and the
  /// 44 pt the group's own width formula assumes per button.
  static const double _controlSize = 44;

  /// Shared union id, so the two capsules blend into one glass shape rather
  /// than reading as two buttons that happen to sit next to each other.
  static const String _unionId = 'chat-top-bar';

  @override
  State<ChatTopBar> createState() => _ChatTopBarState();
}

class _ChatTopBarState extends State<ChatTopBar> {
  /// Modal depth when this bar mounted. Anything at or below it was already
  /// up and is not covering us — the same gate `ModalHideMixin` uses so a
  /// control *inside* a sheet doesn't decide it is behind one.
  int _mountDepth = 0;

  /// True while a sheet newer than [_mountDepth] overlaps this bar's rect.
  bool _covered = false;

  /// The host route's `secondaryAnimation`, which runs while a page-style
  /// route — a `CupertinoSheetRoute` among them — pushes or pops over us.
  Animation<double>? _secondaryAnim;
  bool _routeOver = false;

  /// `CNTabBarRouteObserver.modalDepth` when this bar mounted — the narrow
  /// counter, routes whose type name contains `Sheet`. Same gate as
  /// [_mountDepth], so a bar inside a sheet ignores the sheet it is in.
  int _mountSheetDepth = 0;

  /// A *sheet* route is what is over us: [_routeOver], and a `Sheet` route
  /// newer than [_mountSheetDepth] was pushed while it was. Latched until
  /// [_secondaryAnim] is dismissed, because the observer decrements
  /// `modalDepth` in `didPop` — when the pop *starts* — and the sheet is
  /// still sliding down over a scaled page for the whole reverse animation.
  bool _sheetOver = false;

  /// Depth only: any modal newer than [_mountDepth] is up, wherever it is.
  bool _anyModalAbove = false;

  /// This route's *own* push/pop animation, as distinct from
  /// [_secondaryAnim], which runs when another route animates over us.
  Animation<double>? _primaryAnim;
  bool _pageAnimating = false;

  /// Whether to draw the soft controls right now: the bar was asked for them
  /// outright, or the glass is covered, or a route is animating over us.
  ///
  /// That last term is not belt and braces. Overlap alone leaves the glass
  /// mounted for the whole push — at the halfway frame the sheet is still
  /// below the bar, so nothing overlaps yet — and a mounted platform view
  /// mid-animation is exactly when Flutter's hybrid composition paints the
  /// overlay quad around it instead of the page's own content: a grey band
  /// spanning the union of the platform views, far wider than the controls.
  /// Swapping on the animation as well means the views are already gone
  /// before the first animated frame.
  bool get _useSoft {
    if (!widget.liquid || widget.debugForceSoft) return true;
    // Ahead of the modalBehavior switch and not configurable, covering both
    // of this route's animations: `_pageAnimating` is the page's own push and
    // pop, `_routeOver` is another route animating over it or open on it. Neither is a
    // modal concern, and neither is a trade-off — a platform view mounted
    // through a route animation is simply broken, in two different ways we
    // hit this session:
    //
    //   * page's own transition  -> a grey rectangle over the composer
    //   * sheet animating over it -> a grey band across the top bar
    //
    //
    // Measured on this page, iOS 26.2 / Flutter 3.47.1, slow interactive
    // swipe: with the two glass controls mounted, a grey rectangle appears
    // over the *composer* — the bottom of the page, nowhere near either
    // native view, and clipping the input bar mid-widget so its left half is
    // covered while the right half draws correctly. `liquid: false`, which
    // leaves the page with zero platform views, removes it entirely.
    //
    // So it is not the controls failing to animate. Flutter slices its scene
    // into overlay layers around platform views, and under the route's
    // transform a slice lands in the wrong place and is filled with
    // background. Anything mounted is enough to trigger it, wherever it sits.
    // Scaffold vs CupertinoPageScaffold was ruled out separately.
    // The page's own transition stays disabled while testing whether the
    // paint-order fix stands on its own. A route *over* us is not covered by
    // paint order — the sheet has to paint above the glass — so that half is
    // back on, and widened from "animating" to "not dismissed":
    // `CupertinoSheetRoute` keeps this page scaled behind it for as long as
    // it is open, and the grey band (the union of both platform views,
    // hamburger to pill) shows settled as well as mid-slide. Popup sheets
    // never drive `secondaryAnimation`, so the attachment sheet keeps glass.
    // if (_pageAnimating) return true;
    //
    // Narrowed again to sheets only. A plain `CupertinoPageRoute` drives the
    // same `secondaryAnimation`, but it only slides this page sideways, and
    // with the glass painted last there is nothing for an overlay to land
    // on wrong — so the bar keeps its glass through an ordinary push. The
    // band needs the sheet's *scale* transform on the page behind it.
    if (_sheetOver) return true;
    switch (widget.modalBehavior) {
      case TopBarModalBehavior.keepGlass:
      case TopBarModalBehavior.hideToGap:
        return false;
      case TopBarModalBehavior.swapToSoft:
        // Animation is handled above, for every behaviour. What is left
        // here is the settled case: a sheet is open and covers the bar.
        return _covered;
      case TopBarModalBehavior.swapOnAnyModal:
        return _anyModalAbove;
    }
  }

  /// Only hand `autoHideOnModal` to the package in [TopBarModalBehavior
  /// .hideToGap]. Under `swapToSoft` this bar removes the CN widget from the
  /// tree itself, which destroys the platform view just as effectively and
  /// leaves us in control of what fills the slot; letting the mixin also fire
  /// would just be a second mechanism racing the first.
  bool get _packageAutoHide =>
      widget.modalBehavior == TopBarModalBehavior.hideToGap;

  @override
  void initState() {
    super.initState();
    _mountDepth = CNTabBarRouteObserver.anyModalDepth.value;
    _mountSheetDepth = CNTabBarRouteObserver.modalDepth.value;
    CNTabBarRouteObserver.modalDepth.addListener(_onSheetDepthChanged);
    CNTabBarRouteObserver.anyModalDepth.addListener(_onModalStateChanged);
    CNTabBarRouteObserver.topModalRect.addListener(_onModalStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);

    final anim = route?.secondaryAnimation;
    if (!identical(anim, _secondaryAnim)) {
      _secondaryAnim?.removeStatusListener(_onSecondaryStatus);
      _secondaryAnim = anim;
      _secondaryAnim?.addStatusListener(_onSecondaryStatus);
      // Assigned rather than setState'd: build runs right after this.
      _routeOver = _isOver(anim);
      _sheetOver = _routeOver && _sheetAbove;
    }

    final primary = route?.animation;
    if (!identical(primary, _primaryAnim)) {
      _primaryAnim?.removeStatusListener(_onPrimaryStatus);
      _primaryAnim = primary;
      _primaryAnim?.addStatusListener(_onPrimaryStatus);
      _pageAnimating = _isAnimating(primary);
    }
  }

  void _onPrimaryStatus(AnimationStatus _) {
    if (!mounted) return;
    final next = _isAnimating(_primaryAnim);
    if (next != _pageAnimating) setState(() => _pageAnimating = next);
  }

  @override
  void dispose() {
    _primaryAnim?.removeStatusListener(_onPrimaryStatus);
    _secondaryAnim?.removeStatusListener(_onSecondaryStatus);
    CNTabBarRouteObserver.modalDepth.removeListener(_onSheetDepthChanged);
    CNTabBarRouteObserver.anyModalDepth.removeListener(_onModalStateChanged);
    CNTabBarRouteObserver.topModalRect.removeListener(_onModalStateChanged);
    super.dispose();
  }

  /// A page-style route is over this one — pushing, open, or popping.
  static bool _isOver(Animation<double>? anim) =>
      anim != null && anim.status != AnimationStatus.dismissed;

  static bool _isAnimating(Animation<double>? anim) =>
      anim != null &&
      (anim.status == AnimationStatus.forward ||
          anim.status == AnimationStatus.reverse);

  bool get _sheetAbove =>
      CNTabBarRouteObserver.modalDepth.value > _mountSheetDepth;

  void _onSecondaryStatus(AnimationStatus _) {
    if (!mounted) return;
    final next = _isOver(_secondaryAnim);
    // Dismissed clears the latch; anything else can only set it. On a push
    // this usually fires *before* the observer's didPush has bumped
    // `modalDepth` (the transition starts first), which is why
    // [_onSheetDepthChanged] can set it too.
    final nextSheet = next && (_sheetOver || _sheetAbove);
    if (next != _routeOver || nextSheet != _sheetOver) {
      setState(() {
        _routeOver = next;
        _sheetOver = nextSheet;
      });
    }
  }

  void _onSheetDepthChanged() {
    if (!mounted || _sheetOver || !_routeOver || !_sheetAbove) return;
    setState(() => _sheetOver = true);
  }

  void _onModalStateChanged() {
    if (!mounted) return;
    // Post-frame, so the rect comparison runs against the latest layout —
    // the sheet's probe publishes after paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _computeCovered();
      final nextAny = CNTabBarRouteObserver.anyModalDepth.value > _mountDepth;
      if (next != _covered || nextAny != _anyModalAbove) {
        setState(() {
          _covered = next;
          _anyModalAbove = nextAny;
        });
      }
    });
  }

  /// Keeps `ModalHideMixin._computeShouldHide`'s two fail-safes — an unknown
  /// sheet rect and an unmeasurable self both count as covered — but differs
  /// on the geometry test: the mixin hides on any intersection, this counts
  /// the bar covered only once the sheet's rect **contains** it whole.
  ///
  /// Intersection flips true the moment the sheet's top edge touches the
  /// bar's bottom edge, which is the start of the overlap, not the end of it.
  /// Containment waits until there is nothing of the bar left uncovered.
  /// Edges count: a sheet flush with the bar's bounds contains it.
  ///
  /// The trade is real. Any intersection is the *safe* test — while a sheet
  /// covers part of a native control, the uncovered part can still draw
  /// through it (Issue #53) — so this leaves a partially-covered bar
  /// bleeding. It is defensible here only because what replaces the glass is
  /// drawn Flutter content rather than a gap, so there is no reason to swap
  /// while most of the bar is still visible.
  bool _computeCovered() {
    if (CNTabBarRouteObserver.anyModalDepth.value <= _mountDepth) return false;
    final sheetRect = CNTabBarRouteObserver.topModalRect.value;
    if (sheetRect == null) return true;
    final ro = context.findRenderObject();

    if (ro is! RenderBox || !ro.hasSize) return true;
    final Rect myRect = ro.localToGlobal(Offset.zero) & ro.size;
    // Rect has no containsRect, and `intersect(..) == myRect` would compare
    // doubles for equality — so compare the four edges directly.
    final bool covered =
        sheetRect.left <= myRect.left &&
        sheetRect.top <= myRect.top &&
        sheetRect.right >= myRect.right &&
        sheetRect.bottom >= myRect.bottom;
    return covered;
  }

  @override
  Widget build(BuildContext context) {
    final background = context.soft.background;
    final useSoft = _useSoft;

    return DecoratedBox(
      // Fade instead of a hard edge so messages scroll under the controls.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background, background.withValues(alpha: 0)],
          stops: const [0.65, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            children: [
              if (useSoft) _glassMatched(_softMenu()) else _liquidMenu(),
              const Spacer(),
              if (useSoft) _glassMatched(_softPill()) else _liquidPill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liquidMenu() {
    return CNButton.icon(
      icon: const CNSymbol('line.3.horizontal', size: 18),
      onPressed: widget.onMenu,
      autoHideOnModal: _packageAutoHide,
      config: const CNButtonConfig(
        style: CNButtonStyle.glass,
        width: ChatTopBar._controlSize,
        minHeight: ChatTopBar._controlSize,
      ),
    );
  }

  Widget _liquidPill() {
    // Left unwrapped on purpose: in a Row a non-flex child is laid out
    // unbounded, so the group takes its own `count * 44 + spacing + 6`
    // estimate. Give it a bounded width and it expands to `maxWidth + 6`
    // instead (glass_button_group.dart:212).
    return CNGlassButtonGroup(
      spacing: 4,
      autoHideOnModal: _packageAutoHide,
      buttons: [
        CNButtonData.icon(
          icon: const CNSymbol('square.and.pencil', size: 18),
          onPressed: widget.onNewChat,
          config: const CNButtonDataConfig(
            style: CNButtonStyle.glass,
            glassEffectUnionId: ChatTopBar._unionId,
            width: ChatTopBar._controlSize,
            minHeight: ChatTopBar._controlSize,
          ),
        ),
        if (widget.onDetails != null)
          CNButtonData.icon(
            icon: const CNSymbol('info.circle', size: 18),
            onPressed: widget.onDetails,
            config: const CNButtonDataConfig(
              style: CNButtonStyle.glass,
              glassEffectUnionId: ChatTopBar._unionId,
              width: ChatTopBar._controlSize,
              minHeight: ChatTopBar._controlSize,
            ),
          ),
        CNButtonData.icon(
          icon: const CNSymbol('ellipsis', size: 18),
          onPressed: widget.onMore,
          config: const CNButtonDataConfig(
            style: CNButtonStyle.glass,
            glassEffectUnionId: ChatTopBar._unionId,
            width: ChatTopBar._controlSize,
            minHeight: ChatTopBar._controlSize,
          ),
        ),
      ],
    );
  }

  // The soft controls stand in for the glass ones mid-sheet, so they copy
  // the glass row's glyphs and footprint rather than the soft style's own
  // defaults: CupertinoIcons are the SF Symbol set the native side draws
  // (`line.3.horizontal`, `square.and.pencil`, `ellipsis`), and the sizes
  // below were matched against a simulator screenshot of both rows
  // (`PROBE=softbar` in pr_probe_entry.dart), not derived — SF Symbols and
  // the icon font scale differently for the same nominal point size.
  static const double _softMenuIconSize = 27;
  static const double _softPillIconSize = 22;

  /// The glass group's slot: `count * 44 + (count - 1) * spacing + 6` wide
  /// (see [_liquidPill]) and `minHeight + 3` tall. The capsule is *not* centred
  /// in it — measured, it hugs the slot's leading edge and bottom, leaving
  /// ~5 pt spare on the trailing side — so the soft pill copies that. Reserving the same
  /// box keeps the pill from shifting on swap.
  Size get _glassPillSlot {
    final count = widget.onDetails == null ? 2 : 3;
    return Size(count * 44 + (count - 1) * 4 + 6, 44 + 3);
  }

  /// Re-skins the soft controls as the glass they stand in for, so the swap
  /// reads as the same control rather than a different style. Scoped to the
  /// liquid bar: with `liquid: false` the soft style is the design, not a
  /// stand-in, and keeps its own tokens.
  ///
  /// Values sampled from simulator screenshots of the glass row (iOS 26.2,
  /// `PROBE=softbar`):
  ///  * light — fill FDFDFD on the white page, a pure-white rim (so no
  ///    visible border), and a wide, low shadow: ~5% black at the bottom
  ///    edge, ~2% at the top, gone ~30 pt below.
  ///  * dark — fill 161616 on 0D0D0D, a ~1 pt rim peaking near 303030 and fading inward (drawn as a flat 2C2C2C), and no shadow
  ///    that reads against the near-black page.
  Widget _glassMatched(Widget child) {
    if (!widget.liquid) return child;
    final theme = Theme.of(context);
    final base = context.soft;
    final tokens = theme.brightness == Brightness.dark
        ? base.copyWith(
            surface: const Color(0xFF161616),
            surfacePressed: const Color(0xFF222222),
            border: const Color(0xFF2C2C2C),
            shadow: const Color(0x00000000),
          )
        : base.copyWith(
            surface: const Color(0xFFFDFDFD),
            surfacePressed: const Color(0xFFF0F0F0),
            border: const Color(0xFFFFFFFF),
            shadow: const Color(0x1A000000),
            shadowBlur: 30,
            shadowDy: 8,
          );
    return Theme(
      data: theme.copyWith(extensions: <ThemeExtension<dynamic>>[tokens]),
      child: child,
    );
  }

  Widget _softMenu() {
    return SoftCircularButton(
      icon: CupertinoIcons.line_horizontal_3,
      semanticLabel: 'Menu',
      onPressed: widget.onMenu,
      size: ChatTopBar._controlSize,
      iconSize: _softMenuIconSize,
    );
  }

  Widget _softPill() {
    return SizedBox.fromSize(
      size: _glassPillSlot,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SoftIconPill(
          // Same 44 + 4 + 44 run as the glass group (`spacing: 4`), so the
          // icons sit 48 pt apart like the glass ones; with the border it
          // lands on the glass capsule's measured ~94 pt (two buttons).
          horizontalPadding: 0,
          spacing: 4,
          iconSize: _softPillIconSize,
          actions: [
            SoftIconPillAction(
              icon: CupertinoIcons.square_pencil,
              semanticLabel: 'New chat',
              onPressed: widget.onNewChat,
            ),
            if (widget.onDetails != null)
              SoftIconPillAction(
                icon: CupertinoIcons.info_circle,
                semanticLabel: 'Chat details',
                onPressed: widget.onDetails,
              ),
            SoftIconPillAction(
              icon: CupertinoIcons.ellipsis,
              semanticLabel: 'More options',
              onPressed: widget.onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-aligned user turn, capped at 75% of the width.
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: SoftSurface(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: context.soft.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Generated-file row at the end of an assistant turn.
class AttachmentCard extends StatelessWidget {
  const AttachmentCard({
    super.key,
    required this.fileName,
    required this.onTap,
    this.liquid = true,
  });

  final String fileName;
  final VoidCallback onTap;

  /// Render the card's surface as iOS 26 Liquid Glass instead of a
  /// [SoftSurface]. The row content is identical either way. Set `false` for
  /// the original, platform-view-free card.
  final bool liquid;

  /// 28 is exactly half of this, which is why the glass shape is a capsule.
  static const double _height = 56;
  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open $fileName',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: liquid ? _liquid(context) : _soft(context),
      ),
    );
  }

  Widget _liquid(BuildContext context) {
    return LiquidGlassContainer(
      config: const LiquidGlassConfig(
        effect: CNGlassEffect.regular,
        shape: CNGlassEffectShape.capsule,
        // The card is tappable, so let the glass react to touch the way the
        // soft surface reacts with its pressed fill.
        interactive: true,
      ),
      // The container is sized by its child, so the child needs a definite
      // height — the native view is laid out into exactly this box.
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _row(context),
        ),
      ),
    );
  }

  Widget _soft(BuildContext context) {
    return SoftSurface(
      height: _height,
      radius: _radius,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _row(context),
    );
  }

  /// Shared by both surfaces: the tokens still drive the content colors, so
  /// the row stays legible on glass in either brightness.
  Widget _row(BuildContext context) {
    final soft = context.soft;

    return Row(
      children: [
        Icon(Icons.description_outlined, size: 20, color: soft.foreground),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: soft.foreground),
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: soft.mutedForeground,
        ),
      ],
    );
  }
}

/// Copy / share / react / dislike / more, under an assistant turn.
class MessageActionsRow extends StatelessWidget {
  const MessageActionsRow({
    super.key,
    required this.onCopy,
    required this.onShare,
    required this.onReact,
    required this.onDislike,
    required this.onMore,
  });

  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onReact;
  final VoidCallback onDislike;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    // Secondary actions stay muted so the message text keeps the contrast.
    final muted = context.soft.mutedForeground;

    Widget action(IconData icon, String label, VoidCallback onPressed) {
      return SoftIconTap(
        icon: icon,
        semanticLabel: label,
        onPressed: onPressed,
        size: 20,
        tapTarget: 40,
        color: muted,
      );
    }

    return Row(
      children: [
        action(Icons.copy_rounded, 'Copy', onCopy),
        action(Icons.ios_share_rounded, 'Share', onShare),
        action(Icons.add_reaction_outlined, 'React', onReact),
        action(Icons.thumb_down_outlined, 'Bad response', onDislike),
        action(Icons.more_horiz_rounded, 'More', onMore),
      ],
    );
  }
}

/// The composer. Its `TextField` is the Issue #31 subject in a real layout.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onAttach,
    required this.onDictate,
    required this.onVoice,
  });

  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onDictate;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return SoftSurface(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(4, 4, 5, 4),
      child: Row(
        // Keep buttons pinned to the bottom when the field grows.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SoftIconTap(
            icon: Icons.add_rounded,
            semanticLabel: 'Attach',
            onPressed: onAttach,
            size: 24,
            tapTarget: 40,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              cursorColor: soft.foreground,
              style: TextStyle(fontSize: 16, color: soft.foreground),
              decoration: InputDecoration(
                hintText: 'Ask anything',
                hintStyle: TextStyle(color: soft.mutedForeground),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          SoftIconTap(
            icon: Icons.mic_none_rounded,
            semanticLabel: 'Dictate',
            onPressed: onDictate,
            size: 22,
            tapTarget: 40,
          ),
          const SizedBox(width: 2),
          SoftCircularButton(
            icon: Icons.graphic_eq_rounded,
            semanticLabel: 'Voice mode',
            onPressed: onVoice,
            size: 40,
          ),
        ],
      ),
    );
  }
}

/// One option row inside [AttachmentSheet]. Stateless, with no pressed
/// state, to match [AttachmentCard] rather than [SoftIconTap].
class _SheetOptionRow extends StatelessWidget {
  const _SheetOptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SoftSurface(
          height: 56,
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(icon, size: 20, color: soft.foreground),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(fontSize: 15, color: soft.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row's icon and label in an [AttachmentSheet].
class SheetOption {
  const SheetOption(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// The composer's sheet, used at two heights. New UI — see deviations 4 and 9
/// on [SoftChatUiDemoPage].
///
/// Height is [FractionallySizedBox], not a `maxHeight` constraint, so a half
/// sheet is half on every device rather than half on one and short on
/// another. Picking an option just closes the sheet: there is no attachment
/// or voice pipeline behind this screen and faking one would make the page
/// lie about what it does.
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({
    super.key,
    this.title = 'Add to chat',
    this.heightFactor = 0.5,
    this.options = attachOptions,
  });

  /// Shown at the top, next to the close button.
  final String title;

  /// Fraction of the screen the sheet occupies. 1.0 covers the top bar,
  /// which is the point of the voice variant.
  final double heightFactor;

  /// Rows, in order.
  final List<SheetOption> options;

  /// The plus button's set.
  static const List<SheetOption> attachOptions = <SheetOption>[
    SheetOption(Icons.photo_camera_outlined, 'Camera'),
    SheetOption(Icons.photo_library_outlined, 'Photo library'),
    SheetOption(Icons.folder_outlined, 'Files'),
    SheetOption(Icons.document_scanner_outlined, 'Scan document'),
  ];

  /// The voice button's set.
  static const List<SheetOption> voiceOptions = <SheetOption>[
    SheetOption(Icons.mic_none_rounded, 'Start voice chat'),
    SheetOption(Icons.graphic_eq_rounded, 'Choose a voice'),
    SheetOption(Icons.translate_rounded, 'Spoken language'),
    SheetOption(Icons.tune_rounded, 'Voice settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: soft.background,
          border: Border.all(color: soft.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          // A full-height sheet reaches the status bar; a partial one starts
          // well below it and would only gain dead space from a top inset.
          top: heightFactor >= 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag affordance. Hand-drawn rather than `showDragHandle`
                // so it takes the border token like every other hairline.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: soft.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: soft.foreground,
                        ),
                      ),
                    ),
                    SoftCircularButton(
                      icon: Icons.close_rounded,
                      semanticLabel: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      size: 36,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final option in options) ...[
                  _SheetOptionRow(
                    icon: option.icon,
                    label: option.label,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (option != options.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One heading-plus-body block in [StyleGuideSheet].
class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: soft.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: soft.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The document the attachment card names, as a Cupertino stacked-card
/// sheet. New UI — see deviation 5 on [SoftChatUiDemoPage].
///
/// The numbers quoted in the body are the ones this file actually uses, so
/// the guide stays true if the tokens change and obviously false if they
/// drift. [SoftControlTheme.light] is the set it quotes.
class StyleGuideSheet extends StatelessWidget {
  const StyleGuideSheet({super.key});

  static const List<_GuideSection> _sections = <_GuideSection>[
    _GuideSection(
      title: 'Geometry',
      body:
          'A circle for a single action, a stadium for grouped actions, a '
          '22-28 pt radius for anything holding text. The shape says how '
          'many things the control does.',
    ),
    _GuideSection(
      title: 'Off-white surfaces',
      body:
          'A surface sits one step off the background — F5F5F5 on FFFFFF — '
          'never pure white on white. The step is what makes it a control '
          'rather than a region of the page.',
    ),
    _GuideSection(
      title: 'Hairline borders',
      body:
          'One logical pixel of D2D2D2, about 1.4:1 against the surface. '
          'Enough to close the shape, not enough to read as an outline. '
          'Disabled moves it closer to the surface, not to the background.',
    ),
    _GuideSection(
      title: 'Soft depth',
      body:
          '4 px blur, 2 px down, 6% black. It is a hint that the surface is '
          'above the page, not a drop shadow. Pressed tightens to 2 px blur '
          'and 1 px down.',
    ),
    _GuideSection(
      title: 'Icon proportions',
      body:
          'The icon takes about 40% of the container. Smaller reads as an '
          'empty button, larger loses the negative space the style depends '
          'on.',
    ),
    _GuideSection(
      title: 'Negative space',
      body:
          'Tap targets stay 40-44 pt whatever the icon measures. The space '
          'around a 20 pt icon is part of the design, not padding left over.',
    ),
    _GuideSection(
      title: 'Interaction states',
      body:
          'Fill darkens one step, the shadow tightens, the whole control '
          'scales to 0.97. 100-120 ms. Every state change is visible and '
          'none of them move the layout.',
    ),
    _GuideSection(
      title: 'Scaling',
      body:
          'Icon size, shadow and border all derive from the container, so '
          'the same control is correct at 36, 44 and 56 pt without a second '
          'set of values.',
    ),
    _GuideSection(
      title: 'A Flutter base',
      body:
          'One widget owns the look and every control composes it. Changing '
          'the style means changing that widget, not auditing the call '
          'sites.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;

    return Scaffold(
      backgroundColor: soft.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soft circular UI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: soft.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'soft_circular_ui_style_guide.md',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: soft.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SoftCircularButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    size: 40,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: _sections,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One assistant turn with its attachment and actions, under a floating top
/// bar, over a composer pinned to the bottom.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Bottom padding for the message list: the composer now floats over it
  /// rather than taking its own row, so the list has to leave room.
  static const double _composerGap = 88;

  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Opens the attachment sheet at half the screen height.
  ///
  /// The sheet is its own route, so it is built outside this page's [Theme]
  /// and `context.soft` there would resolve to the light fallback — the sheet
  /// would come up white over a dark page. Carrying the page's [ThemeData]
  /// across the route boundary is what keeps the tokens (and the brightness
  /// Material derives its own defaults from) intact.
  void _showAttachmentSheet() {
    final theme = Theme.of(context);
    CNBottomSheet.show(
      context: context,
      // The soft style draws its own surface, corners and hairline border.
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Required for the sheet to exceed Flutter's default 9/16 cap and to
      // let [AttachmentSheet] size itself to exactly half the screen.
      isScrollControlled: true,
      builder: (_) => Theme(data: theme, child: const AttachmentSheet()),
    );
  }

  /// Opens the same sheet at full height from the voice button.
  ///
  /// The reason it exists: this is a `ModalBottomSheetRoute`, a `PopupRoute`,
  /// so unlike the style guide's `CupertinoSheetRoute` it never transforms
  /// the page behind it and never drives this route's `secondaryAnimation`.
  /// At 1.0 it does end up covering the top bar, so the geometry path still
  /// fires once it settles — but nothing fires during the slide. If the grey
  /// overlay band shows here too, the cause is not the host-page transform
  /// and the swap needs the depth-only trigger instead of this page's
  /// `_covered || _sheetOver`.
  void _showVoiceSheet() {
    final theme = Theme.of(context);
    CNBottomSheet.show(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: theme,
        child: const AttachmentSheet(
          title: 'Voice mode',
          heightFactor: 1,
          options: AttachmentSheet.voiceOptions,
        ),
      ),
    );
  }

  /// Pushes [ChatDetailsPage] as an ordinary page.
  ///
  /// The counterpart to [_showStyleGuide]: a `CupertinoPageRoute` slides
  /// this page out to the left instead of scaling it, but it drives the same
  /// `secondaryAnimation`, so the top bar swaps to soft for the push, stays
  /// soft while the details page is up, and returns to glass once the pop
  /// settles. Same cross-route [Theme] capture as the sheets.
  void _openDetails() {
    final theme = Theme.of(context);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => Theme(data: theme, child: const ChatDetailsPage()),
      ),
    );
  }

  /// Opens the style guide as a Cupertino stacked-card sheet.
  ///
  /// Same cross-route [Theme] capture as [_showAttachmentSheet]. This one is
  /// a `CupertinoSheetRoute`, so its runtime type contains `Sheet` and it
  /// trips the narrow `CNTabBarRouteObserver.modalDepth` counter as well as
  /// the broad one — the route type at the center of Issue #31.
  void _showStyleGuide() {
    final theme = Theme.of(context);
    CNBottomSheet.showCupertino(
      context: context,
      pageBuilder: (_) => Theme(data: theme, child: const StyleGuideSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;
    final body = TextStyle(fontSize: 17, height: 1.45, color: soft.foreground);
    final topInset = MediaQuery.paddingOf(context).top;

    // One Stack, with the platform views painted LAST.
    //
    // This used to be a Column of [Expanded(Stack(list, topBar)), composer].
    // Column children paint in order, so the composer painted *after* — above
    // — the top bar's platform views. Flutter has to cut an overlay layer for
    // any Flutter content drawn above a platform view, and under the route's
    // transform that overlay landed wrong: a grey rectangle across the
    // composer, clipping it mid-widget. pr66 never shows the artifact because
    // its glass buttons are inside the list, with nothing painting above them.
    //
    // Keeping the top bar last means no Flutter content is above a platform
    // view, so no overlay is needed in the first place.
    return Scaffold(
      backgroundColor: soft.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 72, 16, _composerGap),
              children: [
                const UserMessageBubble(
                  text:
                      "It's not exactly for hamburger right? I want a "
                      'general description on how to reach this kind '
                      'of style',
                ),
                const SizedBox(height: 28),
                Text(
                  'Right — the first version leaned too hard on the menu '
                  'button. This one describes the visual language itself, '
                  'so it applies to any icon control.',
                  style: body,
                ),
                const SizedBox(height: 16),
                Text(
                  'It covers geometry, off-white surfaces, hairline '
                  'borders, soft depth, icon proportions, negative space, '
                  'interaction states, scaling, and a Flutter base.',
                  style: body,
                ),
                const SizedBox(height: 20),
                AttachmentCard(
                  // Back to the soft surface. Flip to `true` (or drop the
                  // argument) for the LiquidGlassContainer version.
                  liquid: false,
                  fileName: 'soft_circular_ui_style_guide.md',
                  onTap: _showStyleGuide,
                ),
                const SizedBox(height: 8),
                MessageActionsRow(
                  onCopy: () {},
                  onShare: () {},
                  onReact: () {},
                  onDislike: () {},
                  onMore: () {},
                ),
              ],
            ),
          ),
          // Painted before the top bar, so it is never above a platform view.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: ChatInputBar(
                  controller: _input,
                  onAttach: _showAttachmentSheet,
                  onDictate: () {},
                  onVoice: _showVoiceSheet,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ChatTopBar(
              // Deviation from the zip (a no-op there): this page has no
              // CupertinoNavigationBar, so without this the only way
              // back to the gallery is the swipe-back gesture.
              // No swapping: the glass stays mounted through every
              // sheet, so the native `suppressInteractiveGlass` path is
              // what has to keep it from reacting to touches.
              modalBehavior: TopBarModalBehavior.keepGlass,
              onMenu: () => Navigator.of(context).maybePop(),
              onNewChat: () {},
              onMore: () {},
              onDetails: _openDetails,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushed from the top bar's info button. Deliberately platform-view-free,
/// so anything odd during the push or pop comes from the chat page's glass.
class ChatDetailsPage extends StatelessWidget {
  const ChatDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;
    final body = TextStyle(fontSize: 17, height: 1.45, color: soft.foreground);
    final muted = TextStyle(fontSize: 15, color: soft.mutedForeground);

    return Scaffold(
      backgroundColor: soft.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftCircularButton(
                icon: CupertinoIcons.chevron_left,
                semanticLabel: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(height: 24),
              Text(
                'Chat details',
                style: body.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'soft_circular_ui_style_guide.md · 3 messages',
                style: muted,
              ),
              const SizedBox(height: 24),
              Text(
                'Pushed with a CupertinoPageRoute. Watch the chat page\'s top '
                'bar on the way in and back out: it should swap to the soft '
                'controls for the whole time this page covers it, with no '
                'grey band, and come back as glass once the pop settles.',
                style: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Probe for `pr_probe_entry.dart` (`PROBE=softbar`): the top bar's Liquid
/// Glass row directly above its soft fallback row, so a screenshot shows
/// whether the swap changes glyphs or footprint.
class SoftTopBarCompareProbe extends StatelessWidget {
  const SoftTopBarCompareProbe({super.key, this.dark = false, this.label = ''});

  final bool dark;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = dark
        ? const SoftControlTheme.dark()
        : const SoftControlTheme.light();
    final caption = TextStyle(fontSize: 12, color: tokens.foreground);
    // The soft row is the *swapped* liquid bar, not `liquid: false`: that is
    // the state a sheet puts it in, and the one that has to match.
    Widget bar({required bool liquid}) => ChatTopBar(
      debugForceSoft: !liquid,
      modalBehavior: TopBarModalBehavior.keepGlass,
      onMenu: () {},
      onNewChat: () {},
      onMore: () {},
      onDetails: () {},
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: tokens.background,
        extensions: <ThemeExtension<dynamic>>[tokens],
      ),
      child: Scaffold(
        backgroundColor: tokens.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(liquid: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('liquid ↑   soft ↓   $label', style: caption),
            ),
            // Soft row last: no Flutter content paints above the glass.
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: bar(liquid: false),
            ),
          ],
        ),
      ),
    );
  }
}
