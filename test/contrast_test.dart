// Text on chips, segmented buttons and tabs must stay readable against the
// background actually painted behind it (light and dark themes).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/core/theme/app_theme.dart';

double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
  });

  for (final dark in [false, true]) {
    testWidgets('selection controls are readable · ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tabs = TabController(length: 2, vsync: const TestVSync());

      Widget probe(String key, Widget child) => RepaintBoundary(
            key: ValueKey(key),
            child: Padding(padding: const EdgeInsets.all(4), child: child),
          );

      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: ListView(
              children: [
                probe('choiceOn', ChoiceChip(label: const Text('choiceOn'), selected: true, onSelected: (_) {})),
                probe('choiceOff', ChoiceChip(label: const Text('choiceOff'), selected: false, onSelected: (_) {})),
                probe('filterOn', FilterChip(label: const Text('filterOn'), selected: true, onSelected: (_) {})),
                probe('filterOff', FilterChip(label: const Text('filterOff'), selected: false, onSelected: (_) {})),
                probe('action', ActionChip(label: const Text('action'), onPressed: () {})),
                probe('input', InputChip(label: const Text('input'), onPressed: () {}, onDeleted: () {})),
                probe(
                  'seg',
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('segOn')),
                      ButtonSegment(value: 2, label: Text('segOff')),
                    ],
                    selected: const {1},
                    onSelectionChanged: (_) {},
                  ),
                ),
                probe(
                  'tabs',
                  TabBar(
                    controller: tabs,
                    tabAlignment: TabAlignment.fill,
                    tabs: const [Tab(text: 'tabOn'), Tab(text: 'tabOff')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final problems = <String>[];
      for (final label in ['choiceOn', 'choiceOff', 'filterOn', 'filterOff', 'action', 'input', 'segOn', 'segOff', 'tabOn', 'tabOff']) {
        final text = find.text(label, findRichText: true).first;
        final paragraph = tester.renderObject<RenderParagraph>(text);
        Color? color;
        paragraph.text.visitChildren((span) {
          color ??= span.style?.color;
          return true;
        });
        if (color == null) {
          problems.add('$label: label has no colour');
          continue;
        }
        // Sample the background just left of the label, inside the control.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.ancestor(of: text, matching: find.byType(RepaintBoundary)).first,
        );
        final rect = tester.getRect(text);
        final origin = boundary.localToGlobal(Offset.zero);
        final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
        final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        final x = (rect.left - origin.dx - 3).round().clamp(0, image!.width - 1);
        final y = (rect.center.dy - origin.dy).round().clamp(0, image.height - 1);
        final i = (y * image.width + x) * 4;
        final bg = Color.fromARGB(255, data!.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
        final ratio = _contrast(color!, bg);
        if (ratio < 3) problems.add('$label: contrast ${ratio.toStringAsFixed(2)} (text $color on $bg)');
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
