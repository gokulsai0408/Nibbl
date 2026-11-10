import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] that respects the in-app setting.
abstract final class Haptics {
  static bool enabled = true;

  static Future<void> tap() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  static Future<void> success() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static Future<void> warning() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }
}
