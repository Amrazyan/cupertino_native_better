// Headless-ish probe entrypoint for PR verification.
//
// The simulator has no tap automation available here, so instead of driving
// the demo list by hand this entrypoint boots straight into one PR test page
// in one configuration, chosen by --dart-define. Screenshot with
// `xcrun simctl io booted screenshot`.
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr66 --dart-define=BACKDROP=split --dart-define=BRIGHTNESS=light
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr67 --dart-define=ICON=chevron --dart-define=SIZE=20
//
//   flutter run -t lib/pr_probe_entry.dart \
//     --dart-define=PROBE=pr72 --dart-define=SCENARIO=collapse --dart-define=LABEL=before
//   (SCENARIO: resize | collapse | zero | offscreen | detach; the page auto-toggles.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=softbar
//   (soft chat top bar: Liquid Glass row above its soft fallback row, to
//   compare icon glyphs and footprints.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=softpush \
//     --dart-define=SCENARIO=page
//   (soft chat page; after 3 s pushes a route over it with animations slowed
//   10x, pops it 8 s later. SCENARIO: page = CupertinoPageRoute to the
//   details page, sheet = the style guide as a CupertinoSheetRoute.)
//
//   flutter run -t lib/pr_probe_entry.dart --dart-define=PROBE=tabtrunc
//   (CNTabBar labels after a sheet opens and closes on a page pushed over
//   the tab bar's route: push at 2 s, sheet at 4 s, sheet closed at 6 s,
//   page popped at 8 s.)
//
// PROBE=pr67report additionally dumps the MAE/cost table to the run log.

import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart'
    show CNBottomSheet, CNSymbol, CNTabBar, CNTabBarItem, CNTabBarRouteObserver;
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

import 'demos/pr66_glass_image_asset_tint_test.dart';
import 'demos/pr67_icon_supersample_test.dart';
import 'demos/pr69_glass_effect_test.dart';
import 'demos/pr72_glass_resize_test.dart';
import 'demos/soft_chat_ui_demo.dart';

const String _probe = String.fromEnvironment('PROBE', defaultValue: 'pr67');
const String _backdrop = String.fromEnvironment(
  'BACKDROP',
  defaultValue: 'split',
);
const String _brightness = String.fromEnvironment(
  'BRIGHTNESS',
  defaultValue: 'light',
);
const String _icon = String.fromEnvironment('ICON', defaultValue: 'chevron');
const String _size = String.fromEnvironment('SIZE', defaultValue: '20');
const String _accent = String.fromEnvironment('ACCENT', defaultValue: 'blue');
const String _scenario = String.fromEnvironment(
  'SCENARIO',
  defaultValue: 'resize',
);

/// Stamped into the nav bar so a before/after screenshot pair can't be mixed up.
const String _label = String.fromEnvironment('LABEL', defaultValue: '');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_probe == 'pr67report') {
    WidgetsBinding.instance.addPostFrameCallback((_) => pr67PrintReport());
  }
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorObservers: [CNTabBarRouteObserver()],
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: CupertinoThemeData(
        brightness: _brightness == 'dark' ? Brightness.dark : Brightness.light,
        primaryColor: _accent == 'pink'
            ? CupertinoColors.systemPink
            : CupertinoColors.systemBlue,
      ),
      home: _home(),
    );
  }

  Widget _home() {
    if (_probe == 'tabtrunc') {
      return const _TabTruncProbe();
    }
    if (_probe == 'softpush') {
      return const _SoftPushProbe(scenario: _scenario);
    }
    if (_probe == 'softbar') {
      return SoftTopBarCompareProbe(dark: _brightness == 'dark', label: _label);
    }
    if (_probe.startsWith('pr66')) {
      return Pr66GlassImageAssetTintTestPage(
        initialBackdrop: _backdrop,
        initialBrightness: _brightness,
      );
    }
    if (_probe == 'pr67native') {
      return Pr67NativeStripPage(label: _label);
    }
    if (_probe.startsWith('pr69')) {
      return Pr69GlassEffectTestPage(
        initialBackdrop: _backdrop == 'photo' ? 'photo' : 'stripes',
        initialTinted: _accent == 'pink',
      );
    }
    if (_probe.startsWith('pr72')) {
      return Pr72GlassResizeTestPage(
        initialScenario: _scenario,
        label: _label,
        autoCycle: true,
      );
    }
    return Pr67IconSupersampleTestPage(
      initialIcon: _icon,
      initialSize: double.tryParse(_size),
    );
  }
}

/// Drives a push and pop over the soft chat page with no taps: the
/// simulator has no tap automation here, so screenshots are taken while the
/// slowed transition runs.
class _SoftPushProbe extends StatefulWidget {
  const _SoftPushProbe({required this.scenario});

  final String scenario;

  @override
  State<_SoftPushProbe> createState() => _SoftPushProbeState();
}

class _SoftPushProbeState extends State<_SoftPushProbe> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      timeDilation = 10;
      if (widget.scenario == 'sheet') {
        CNBottomSheet.showCupertino(
          context: context,
          pageBuilder: (_) => const StyleGuideSheet(),
        );
      } else {
        Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const ChatDetailsPage()),
        );
      }
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SoftChatUiDemoPage();
}

/// Reproduces tab-bar labels truncating to "…" after a sheet opened and closed
/// on a page pushed over the bar's route — the bar is destroyed and rebuilt
/// while its route is covered.
class _TabTruncProbe extends StatefulWidget {
  const _TabTruncProbe();

  @override
  State<_TabTruncProbe> createState() => _TabTruncProbeState();
}

class _TabTruncProbeState extends State<_TabTruncProbe> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final nav = Navigator.of(context);
      unawaited(
        nav.push(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Pushed')),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!nav.mounted) return;
      // The navigator's own context: the sheet goes on top of the pushed page.
      unawaited(
        CNBottomSheet.show<void>(
          context: nav.context,
          builder: (_) => const SizedBox(height: 300),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      nav.pop();
      await Future<void>.delayed(const Duration(seconds: 2));
      nav.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const Expanded(child: Center(child: Text('Dashboard'))),
          CNTabBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            autoHideOnPageTransition: false,
            items: const [
              CNTabBarItem(label: 'Chats', icon: CNSymbol('message', size: 0)),
              CNTabBarItem(label: 'Calls', icon: CNSymbol('phone', size: 0)),
              CNTabBarItem(
                label: 'Contacts',
                icon: CNSymbol('person.2', size: 0),
              ),
              CNTabBarItem(label: 'Settings', icon: CNSymbol('gear', size: 0)),
            ],
          ),
        ],
      ),
    );
  }
}
