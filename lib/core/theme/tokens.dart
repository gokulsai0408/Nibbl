import 'package:flutter/material.dart';

/// Spacing scale (4pt base grid).
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Space reserved at the bottom of tab screens for the floating nav bar.
  static const double navClearance = 32;
}

/// Corner radii.
abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Motion tokens. UI motion stays under 300ms; only data reveals run longer.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration ring = Duration(milliseconds: 800);
}

/// Custom curves: the built-in ones are too weak to feel intentional.
abstract final class AppCurves {
  /// Strong ease-out for entering elements and UI responses.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong ease-in-out for elements moving on screen.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// iOS-like drawer curve for bottom sheets.
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);
}

/// Bottom sheets: drawer curve in, faster exit out.
const kSheetAnimation = AnimationStyle(
  curve: AppCurves.drawer,
  duration: Duration(milliseconds: 320),
  reverseCurve: Curves.easeInCubic,
  reverseDuration: Duration(milliseconds: 200),
);

/// Raw brand colors. Prefer `Theme.of(context).colorScheme` or
/// `context.palette` in widgets so light/dark variants resolve correctly.
abstract final class BrandColors {
  // Brand
  static const emerald = Color(0xFF0E9F6E);
  static const emeraldLight = Color(0xFF34D399);
  static const teal = Color(0xFF0FB5A6);
  static const coral = Color(0xFFFF6B4A);
  static const amber = Color(0xFFF5A524);
  static const violet = Color(0xFF7C5CFF);

  // Macros & tracking
  static const protein = Color(0xFFF2557A);
  static const carbs = Color(0xFFF5A524);
  static const fat = Color(0xFF4D7CFE);
  static const water = Color(0xFF2EB5F0);

  // Light - "Sunrise": warm peach-cream canvas, coral accent, warm ink.
  static const sunrise = Color(0xFFDA4A22);
  static const lightBg = Color(0xFFFFF7F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFFCEFE5);
  static const lightOnSurface = Color(0xFF2B1F1A);
  static const lightMuted = Color(0xFF7A6961);
  static const lightOutline = Color(0xFFF2E2D6);
  static const lightStrongOutline = Color(0xFFE5CFBF);

  // Dark - "Midnight Aurora": indigo night, mint accent, violet glow.
  static const aurora = Color(0xFF4FE3B5);
  static const darkBg = Color(0xFF0C0E1F);
  static const darkSurface = Color(0xFF151935);
  static const darkSurfaceHigh = Color(0xFF1E2344);
  static const darkOnSurface = Color(0xFFEEF0FF);
  static const darkMuted = Color(0xFFA0A5CC);
  static const darkOutline = Color(0xFF262C52);
  static const darkStrongOutline = Color(0xFF353C69);
}

/// Signature brand surfaces: the soft glow behind screens and the tinted hero.
abstract final class BrandSurfaces {
  /// Aurora glow colors (top-left, top-right, mid) for the screen backdrop.
  static List<Color> aurora(bool dark) => dark
      ? const [Color(0x667C5CFF), Color(0x4D2EC4B6), Color(0x2EFF7AB6)]
      : const [Color(0xB3FFD2BD), Color(0x99FFE6A6), Color(0x66FFC8D8)];

  /// Gentle brand tint for the hero card.
  static LinearGradient hero(bool dark) => dark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242A5A), Color(0xFF161A36)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEDE2)],
        );
}

/// Semantic colors that Material's ColorScheme doesn't cover.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
    required this.success,
    required this.warning,
    required this.muted,
    required this.onHero,
    required this.heroGradient,
    required this.sunriseGradient,
    required this.duskGradient,
    required this.cardShadow,
  });

  final Color protein;
  final Color carbs;
  final Color fat;
  final Color water;
  final Color success;
  final Color warning;
  final Color muted;

  /// Text/icon color on top of [heroGradient].
  final Color onHero;
  final LinearGradient heroGradient;
  final LinearGradient sunriseGradient;
  final LinearGradient duskGradient;
  final List<BoxShadow> cardShadow;

  /// Shadow for floating elements only (search pill, sheets, nav).
  List<BoxShadow> get floatShadow => const [
        BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
        BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
      ];

  static const light = AppPalette(
    protein: BrandColors.protein,
    carbs: BrandColors.carbs,
    fat: BrandColors.fat,
    water: BrandColors.water,
    success: BrandColors.emerald,
    warning: Color(0xFFD6336C),
    muted: BrandColors.lightMuted,
    onHero: Colors.white,
    heroGradient: LinearGradient(
      colors: [Color(0xFFE8492A), Color(0xFFF06A35)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    sunriseGradient: LinearGradient(
      colors: [Color(0xFFFF6B4A), Color(0xFFF5A524)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    duskGradient: LinearGradient(
      colors: [Color(0xFF7C5CFF), Color(0xFF4D7CFE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardShadow: [],
  );

  static const dark = AppPalette(
    protein: Color(0xFFFF7896),
    carbs: Color(0xFFFFBE4D),
    fat: Color(0xFF7A9DFF),
    water: Color(0xFF5CC8F5),
    success: BrandColors.aurora,
    warning: Color(0xFFFF7AA2),
    muted: BrandColors.darkMuted,
    onHero: Colors.white,
    heroGradient: LinearGradient(
      colors: [Color(0xFF14A889), Color(0xFF2C86D6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    sunriseGradient: LinearGradient(
      colors: [Color(0xFFE85A3B), Color(0xFFDB8F17)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    duskGradient: LinearGradient(
      colors: [Color(0xFF6A4BEB), Color(0xFF3F69E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cardShadow: [],
  );

  @override
  AppPalette copyWith({
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? water,
    Color? success,
    Color? warning,
    Color? muted,
    Color? onHero,
    LinearGradient? heroGradient,
    LinearGradient? sunriseGradient,
    LinearGradient? duskGradient,
    List<BoxShadow>? cardShadow,
  }) {
    return AppPalette(
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      water: water ?? this.water,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      muted: muted ?? this.muted,
      onHero: onHero ?? this.onHero,
      heroGradient: heroGradient ?? this.heroGradient,
      sunriseGradient: sunriseGradient ?? this.sunriseGradient,
      duskGradient: duskGradient ?? this.duskGradient,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      water: Color.lerp(water, other.water, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      sunriseGradient: LinearGradient.lerp(sunriseGradient, other.sunriseGradient, t)!,
      duskGradient: LinearGradient.lerp(duskGradient, other.duskGradient, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// True when the OS or the in-app setting asks for reduced motion.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
