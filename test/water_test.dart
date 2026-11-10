import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/core/config/app_config.dart';
import 'package:forkcast/core/theme/app_theme.dart';
import 'package:forkcast/data/ai/drink_prompt.dart';
import 'package:forkcast/data/local/hive_store.dart';
import 'package:forkcast/presentation/providers/core_providers.dart';
import 'package:forkcast/presentation/providers/log_providers.dart';
import 'package:forkcast/presentation/screens/home/water_sheet.dart';
import 'package:forkcast/presentation/widgets/calorie_ring.dart';
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
    AppTheme.useGoogleFonts = false;
    final dir = await Directory.systemTemp.createTemp('nibbl_water_test');
    Hive.init(dir.path);
    for (final name in HiveStore.allBoxes) {
      await Hive.openBox<String>(name);
    }
  });

  test('drink estimate parsing', () {
    final chai = DrinkPrompts.parse(
      '{"name":"Masala chai","emoji":"☕","ml":150,"hydration_ml":150,"calories":90,"protein":3,"carbs":13,'
      '"fat":3,"confidence":0.8,"note":"Cup with milk"}',
    );
    expect(chai.ml, 150);
    expect(chai.hasCalories, isTrue);
    final beer = DrinkPrompts.parse(
      '{"name":"Beer","emoji":"🍺","ml":330,"hydration_ml":0,"calories":150,"protein":1,"carbs":13,'
      '"fat":0,"confidence":0.9,"note":"Can"}',
    );
    expect(beer.hydrationMl, 0);
    // Hydration can never exceed the volume.
    final odd = DrinkPrompts.parse(
      '{"name":"Water","emoji":"💧","ml":250,"hydration_ml":900,"calories":0,"protein":0,"carbs":0,'
      '"fat":0,"confidence":0.9,"note":""}',
    );
    expect(odd.hydrationMl, 250);
    expect(odd.hasCalories, isFalse);
  });

  testWidgets('calorie ring shows a starting dot at 0 kcal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Center(
          child: RepaintBoundary(
            key: ValueKey('ring'),
            child: CalorieRing(consumed: 0, goal: 2000, size: 120, strokeWidth: 12, onDark: false, center: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('ring')));
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    // Top-centre of the ring (12 o'clock) where the dot sits vs. the track at 6 o'clock.
    int alphaAt(int x, int y) => data!.getUint8((y * image!.width + x) * 4 + 3);
    int lumAt(int x, int y) {
      final i = (y * image!.width + x) * 4;
      return data!.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    }

    expect(alphaAt(60, 6), greaterThan(0));
    expect(lumAt(60, 6), isNot(equals(lumAt(60, 114))), reason: 'dot at the top should differ from the empty track');
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets('add drink sheet layout · text ${scale}x', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final problems = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final where = d.toString().split('\n').where((l) => l.contains('lib/') || l.contains(r'lib\')).take(1).join();
        problems.add('${d.exceptionAsString().split('\n').first} -> $where');
      };
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appConfigProvider.overrideWithValue(_config)],
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showAddDrinkSheet(context, dayKey: '2026-11-10'),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Snap your drink'), findsOneWidget);
        // Quick add closes the sheet; Undo takes it back off.
        final container = ProviderScope.containerOf(tester.element(find.text('open')));
        await tester.tap(find.text('Glass'));
        await tester.pumpAndSettle();
        expect(container.read(dayMetaProvider)['2026-11-10']?.waterMl, 250);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(container.read(dayMetaProvider)['2026-11-10']?.waterMl, 0);
        await tester.pump(const Duration(seconds: 6));
      } finally {
        FlutterError.onError = previous;
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
