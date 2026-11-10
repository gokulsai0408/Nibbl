import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/mochi.dart';

/// Drawing for Mochi's accessories and growth stages. Coordinates are in
/// Mochi's unit space: `s` is the widget size, the body spans roughly
/// x 0.12–0.88 and y 0.28–0.90, eyes sit at ([cx] ± 0.13s, [eyeY]).
abstract final class MochiWardrobePaint {
  // ------------------------------------------------------------ Sprout

  /// The sprout on Mochi's head; grows with [stage]. Canvas is already
  /// translated to the sprout base and rotated by the sway.
  static void sprout(Canvas canvas, double s, MochiStage stage) {
    const leafColor = Color(0xFF2BB673);
    const stemColor = Color(0xFF1E9A5E);
    final grown = stage.index >= MochiStage.sapling.index;
    final stemLen = grown ? s * 0.13 : s * 0.09;
    final leafScale = grown ? 1.2 : 1.0;
    final stem = Paint()
      ..color = stemColor
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(0, -stemLen), stem);

    void leaf(double dir, double anchorY, double k) {
      final p = Path()
        ..moveTo(0, anchorY)
        ..quadraticBezierTo(dir * s * 0.07 * k, anchorY - s * 0.085 * k, dir * s * 0.14 * k, anchorY - s * 0.025 * k)
        ..quadraticBezierTo(dir * s * 0.07 * k, anchorY + s * 0.015 * k, 0, anchorY);
      canvas.drawPath(p, Paint()..color = leafColor);
    }

    final leafY = grown ? -s * 0.07 : -s * 0.085;
    leaf(-1, leafY, leafScale);
    leaf(1, leafY, leafScale);
    if (stage == MochiStage.sprout) return;

    final top = Offset(0, -stemLen);
    if (stage == MochiStage.sapling) {
      // A little new leaf at the tip.
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(-0.5);
      leaf(1, 0, 0.55);
      canvas.restore();
      return;
    }
    if (stage == MochiStage.bud) {
      final bud = Rect.fromCenter(center: top.translate(0, -s * 0.025), width: s * 0.07, height: s * 0.09);
      canvas.drawOval(bud, Paint()..color = const Color(0xFFFF8FAB));
      // Green cup at the base of the bud.
      final cup = Path()
        ..moveTo(top.dx - s * 0.04, top.dy - s * 0.01)
        ..quadraticBezierTo(top.dx, top.dy + s * 0.03, top.dx + s * 0.04, top.dy - s * 0.01)
        ..quadraticBezierTo(top.dx, top.dy + s * 0.005, top.dx - s * 0.04, top.dy - s * 0.01);
      canvas.drawPath(cup, Paint()..color = leafColor);
      return;
    }
    // Bloom: five petals around a sunny centre.
    final c = top.translate(0, -s * 0.04);
    final petal = Paint()..color = const Color(0xFFFF9EB5);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * s * 0.04, s * 0.033, petal);
    }
    canvas.drawCircle(c, s * 0.026, Paint()..color = const Color(0xFFFFC94D));
  }

  // ------------------------------------------------------- Accessories

  /// Head/neck items, drawn in body space (they squash with Mochi).
  static void bodyItems(Canvas canvas, double s, Set<MochiItem> outfit, Path bodyPath, {required double sway}) {
    for (final item in outfit) {
      switch (item) {
        case MochiItem.scarf:
          _scarf(canvas, s, bodyPath);
        case MochiItem.bowtie:
          _bowtie(canvas, s);
        case MochiItem.chefHat:
          _chefHat(canvas, s);
        case MochiItem.bow:
          _bow(canvas, s, sway);
        case MochiItem.headphones:
          _headphones(canvas, s);
        case MochiItem.partyHat:
          _partyHat(canvas, s);
        case MochiItem.crown:
          _crown(canvas, s);
        case MochiItem.glasses || MochiItem.sunglasses:
          break; // face items are drawn by [faceItems]
      }
    }
  }

  /// Glasses follow the eyes.
  static void faceItems(Canvas canvas, double s, Set<MochiItem> outfit, {required double cx, required double eyeY}) {
    if (outfit.contains(MochiItem.glasses)) _glasses(canvas, s, cx, eyeY);
    if (outfit.contains(MochiItem.sunglasses)) _sunglasses(canvas, s, cx, eyeY);
  }

  static void _scarf(Canvas canvas, double s, Path body) {
    const red = Color(0xFFE5484D);
    const darkRed = Color(0xFFC23238);
    final band = Rect.fromLTWH(0, s * 0.7, s, s * 0.075);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRRect(RRect.fromRectAndRadius(band, Radius.circular(s * 0.03)), Paint()..color = red);
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var x = 0.16; x < 0.86; x += 0.1) {
      canvas.drawRect(Rect.fromLTWH(s * x, band.top, s * 0.025, band.height), stripe);
    }
    canvas.restore();
    // Hanging tail.
    final tail = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.62, s * 0.74, s * 0.075, s * 0.15),
      Radius.circular(s * 0.025),
    );
    canvas.save();
    canvas.translate(s * 0.655, s * 0.74);
    canvas.rotate(-0.18);
    canvas.translate(-s * 0.655, -s * 0.74);
    canvas.drawRRect(tail, Paint()..color = darkRed);
    canvas.restore();
  }

  static void _bowtie(Canvas canvas, double s) {
    const navy = Color(0xFF2D3A8C);
    final c = Offset(s * 0.5, s * 0.745);
    final w = s * 0.085;
    final h = s * 0.05;
    final left = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx - w, c.dy - h)
      ..quadraticBezierTo(c.dx - w * 1.15, c.dy, c.dx - w, c.dy + h)
      ..close();
    final right = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + w, c.dy - h)
      ..quadraticBezierTo(c.dx + w * 1.15, c.dy, c.dx + w, c.dy + h)
      ..close();
    final p = Paint()..color = navy;
    canvas.drawPath(left, p);
    canvas.drawPath(right, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.04, height: s * 0.05), Radius.circular(s * 0.01)),
      Paint()..color = const Color(0xFF4656C2),
    );
  }

  static void _chefHat(Canvas canvas, double s) {
    final white = Paint()..color = Colors.white;
    final rim = Paint()
      ..color = const Color(0xFFD9DEE3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.01;
    // Puffy top.
    for (final (dx, dy, r) in [(-0.075, 0.2, 0.075), (0.075, 0.2, 0.075), (0.0, 0.155, 0.085)]) {
      final c = Offset(s * (0.5 + dx), s * dy);
      canvas.drawCircle(c, s * r, white);
      canvas.drawCircle(c, s * r, rim);
    }
    canvas.drawRect(Rect.fromLTWH(s * 0.38, s * 0.17, s * 0.24, s * 0.1), white);
    // Band.
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.36, s * 0.24, s * 0.28, s * 0.075),
      Radius.circular(s * 0.02),
    );
    canvas.drawRRect(band, white);
    canvas.drawRRect(band, rim);
  }

  static void _bow(Canvas canvas, double s, double sway) {
    const pink = Color(0xFFFF6B9A);
    final c = Offset(s * 0.7, s * 0.31);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.35 + sway * 0.3);
    final p = Paint()..color = pink;
    for (final dir in [-1.0, 1.0]) {
      final loop = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(dir * s * 0.07, -s * 0.075, dir * s * 0.09, -s * 0.01)
        ..quadraticBezierTo(dir * s * 0.08, s * 0.05, 0, 0);
      canvas.drawPath(loop, p);
    }
    canvas.drawCircle(Offset.zero, s * 0.022, Paint()..color = const Color(0xFFE04F82));
    canvas.restore();
  }

  static void _headphones(Canvas canvas, double s) {
    const dark = Color(0xFF3A3F4B);
    const accent = Color(0xFF6C7BFF);
    final band = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    final arc = Path()
      ..moveTo(s * 0.13, s * 0.52)
      ..cubicTo(s * 0.12, s * 0.2, s * 0.88, s * 0.2, s * 0.87, s * 0.52);
    canvas.drawPath(arc, band);
    for (final x in [0.1, 0.9]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * x, s * 0.55), width: s * 0.1, height: s * 0.17),
        Radius.circular(s * 0.045),
      );
      canvas.drawRRect(cup, Paint()..color = accent);
      canvas.drawRRect(
        cup,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012,
      );
    }
  }

  static void _partyHat(Canvas canvas, double s) {
    final apex = Offset(s * 0.5, s * 0.05);
    final cone = Path()
      ..moveTo(s * 0.37, s * 0.3)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(s * 0.63, s * 0.3)
      ..quadraticBezierTo(s * 0.5, s * 0.33, s * 0.37, s * 0.3)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFF7C5CFF));
    canvas.save();
    canvas.clipPath(cone);
    final stripe = Paint()
      ..color = const Color(0xFFFFC94D)
      ..strokeWidth = s * 0.03;
    for (var y = 0.1; y < 0.34; y += 0.075) {
      canvas.drawLine(Offset(s * 0.3, s * (y + 0.05)), Offset(s * 0.7, s * (y - 0.02)), stripe);
    }
    canvas.restore();
    canvas.drawCircle(apex, s * 0.035, Paint()..color = const Color(0xFFFF6B9A));
  }

  static void _crown(Canvas canvas, double s) {
    const gold = Color(0xFFFFC23D);
    const goldDark = Color(0xFFE09B12);
    final base = s * 0.3;
    final top = s * 0.15;
    final l = s * 0.33;
    final r = s * 0.67;
    final crown = Path()
      ..moveTo(l, base)
      ..lineTo(l - s * 0.01, top + s * 0.03)
      ..lineTo(s * 0.415, s * 0.22)
      ..lineTo(s * 0.5, top - s * 0.01)
      ..lineTo(s * 0.585, s * 0.22)
      ..lineTo(r + s * 0.01, top + s * 0.03)
      ..lineTo(r, base)
      ..close();
    canvas.drawPath(crown, Paint()..color = gold);
    canvas.drawPath(
      crown,
      Paint()
        ..color = goldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(s * 0.5, s * 0.255), s * 0.022, Paint()..color = const Color(0xFFE5484D));
    for (final x in [0.41, 0.59]) {
      canvas.drawCircle(Offset(s * x, s * 0.265), s * 0.014, Paint()..color = const Color(0xFF4FA3FF));
    }
    for (final p in [
      Offset(l - s * 0.01, top + s * 0.03),
      Offset(s * 0.5, top - s * 0.01),
      Offset(r + s * 0.01, top + s * 0.03),
    ]) {
      canvas.drawCircle(p, s * 0.016, Paint()..color = gold);
    }
  }

  static void _glasses(Canvas canvas, double s, double cx, double eyeY) {
    const frame = Color(0xFF6B4A2B);
    final stroke = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016;
    final r = s * 0.068;
    for (final dir in [-1, 1]) {
      final c = Offset(cx + dir * s * 0.13, eyeY);
      canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.18));
      canvas.drawCircle(c, r, stroke);
    }
    final bridge = Path()
      ..moveTo(cx - s * 0.062, eyeY - s * 0.01)
      ..quadraticBezierTo(cx, eyeY - s * 0.035, cx + s * 0.062, eyeY - s * 0.01);
    canvas.drawPath(bridge, stroke);
  }

  static void _sunglasses(Canvas canvas, double s, double cx, double eyeY) {
    const lens = Color(0xFF23262E);
    final p = Paint()..color = lens;
    for (final dir in [-1, 1]) {
      final rect = Rect.fromCenter(center: Offset(cx + dir * s * 0.13, eyeY), width: s * 0.15, height: s * 0.1);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(s * 0.02),
          topRight: Radius.circular(s * 0.02),
          bottomLeft: Radius.circular(s * 0.05),
          bottomRight: Radius.circular(s * 0.05),
        ),
        p,
      );
      // Shine.
      canvas.drawLine(
        rect.topLeft + Offset(s * 0.03, s * 0.025),
        rect.topLeft + Offset(s * 0.06, s * 0.025),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = s * 0.012
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      Offset(cx - s * 0.055, eyeY - s * 0.02),
      Offset(cx + s * 0.055, eyeY - s * 0.02),
      Paint()
        ..color = lens
        ..strokeWidth = s * 0.016,
    );
  }
}
