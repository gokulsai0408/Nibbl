// Renders the friends feed (post cards, reactions, recipe attachment, streak
// strip) at normal and large text sizes and fails on any layout overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/core/config/app_config.dart';
import 'package:forkcast/core/theme/app_theme.dart';
import 'package:forkcast/data/local/hive_store.dart';
import 'package:forkcast/data/social/demo_social_backend.dart';
import 'package:forkcast/presentation/providers/core_providers.dart';
import 'package:forkcast/presentation/providers/social_providers.dart';
import 'package:forkcast/domain/entities/social.dart';
import 'package:forkcast/presentation/screens/social/social_screen.dart';
import 'package:forkcast/presentation/screens/social/story_viewer_screen.dart';
import 'package:hive/hive.dart';

const _config = AppConfig(
  aiBaseUrl: '',
  aiApiKey: '',
  aiModel: 'demo',
  aiVisionModel: 'demo',
  useMockAi: true,
  provider: AiProvider.openai,
);

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('nibbl_social_test');
    Hive.init(dir.path);
    for (final name in HiveStore.allBoxes) {
      await Hive.openBox<String>(name);
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('Social feed · ${mode.name} · text ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final backend = DemoSocialBackend();
        await tester.runAsync(() => backend.saveProfile(username: 'tester', displayName: 'Tester', emoji: '😎'));

        final problems = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          final where = d.toString().split('\n').where((l) => l.contains('lib/') || l.contains(r'lib\')).take(1).join();
          problems.add('${d.exceptionAsString().split('\n').first} -> $where');
        };

        var foundDish = false;
        var foundSave = false;
        var foundChallenge = false;
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appConfigProvider.overrideWithValue(_config),
                socialBackendProvider.overrideWithValue(backend),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: mode,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const SocialScreen(),
              ),
            ),
          );
          // The demo backend uses short delays; advance the test clock past them.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          foundDish = find.textContaining('Egg fried rice').evaluate().isNotEmpty;
          foundSave = find.text('Save').evaluate().isNotEmpty;

          // Regression: opening a story from the feed used to throw
          // "Tried to modify a provider while the widget tree was building".
          await tester.tap(find.text('Priya').first);
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 400));
          }
          await tester.tap(find.byTooltip('Close'));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }

          // Challenges tab.
          tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          foundChallenge = find.text('Start a challenge').evaluate().isNotEmpty;

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        } finally {
          FlutterError.onError = previous;
        }
        expect(foundDish, isTrue, reason: 'feed post not rendered');
        expect(foundSave, isTrue, reason: 'recipe attachment not rendered');
        expect(foundChallenge, isTrue, reason: 'challenge not rendered');
        expect(problems, isEmpty, reason: problems.toSet().join('\n'));
      });

      testWidgets('Story viewer · ${mode.name} · text ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final backend = DemoSocialBackend();
        final groups = await tester.runAsync(() async {
          await backend.saveProfile(username: 'tester', displayName: 'Tester', emoji: '😎');
          return groupStories(await backend.stories(), 'me');
        });

        final problems = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          final where = d.toString().split('\n').where((l) => l.contains('lib/') || l.contains(r'lib\')).take(1).join();
          problems.add('${d.exceptionAsString().split('\n').first} -> $where');
        };
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appConfigProvider.overrideWithValue(_config),
                socialBackendProvider.overrideWithValue(backend),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: mode,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: StoryViewerScreen(groups: groups!, initialGroup: 0),
              ),
            ),
          );
          // Play through a story into the next one.
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        } finally {
          FlutterError.onError = previous;
        }
        expect(problems, isEmpty, reason: problems.toSet().join('\n'));
      });
    }
  }
}
