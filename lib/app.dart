import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/profile_settings_providers.dart';
import 'presentation/widgets/theme_fade.dart';

class ForkcastApp extends ConsumerWidget {
  const ForkcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final reduceMotion = ref.watch(settingsProvider.select((s) => s.reduceMotion));

    return MaterialApp.router(
      title: 'Nibbl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Switch instantly; ThemeFade cross-fades the whole frame instead, since
      // lerping ThemeData snaps brightness-dependent widgets halfway through.
      themeAnimationDuration: Duration.zero,
      scrollBehavior: const _SmoothScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: MediaQuery(
            data: mq.copyWith(
              // In-app "reduce motion" piggybacks on the OS flag so every widget
              // can simply check MediaQuery.disableAnimationsOf(context).
              disableAnimations: mq.disableAnimations || reduceMotion,
              // Support large text while keeping layouts intact.
              textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6),
            ),
            child: ThemeFade(child: child!),
          ),
        );
      },
    );
  }
}

/// Buttery scrolling everywhere: iOS-style momentum with a soft rubber-band
/// edge (no Android stretch/glow), and lists always respond to a drag.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
