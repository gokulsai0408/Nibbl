import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Forkcast theme: Plus Jakarta Sans for display/headlines (friendly,
/// geometric), Inter for body/labels (highly legible at small sizes).
abstract final class AppTheme {
  /// Tests turn this off (no network for font downloads).
  static bool useGoogleFonts = true;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? BrandColors.aurora : BrandColors.sunrise,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? BrandColors.aurora : BrandColors.sunrise,
      onPrimary: isDark ? const Color(0xFF04261C) : Colors.white,
      secondary: isDark ? const Color(0xFFB79CFF) : const Color(0xFFF2994A),
      onSecondary: Colors.white,
      tertiary: isDark ? const Color(0xFFFF9EC7) : BrandColors.violet,
      surface: isDark ? BrandColors.darkSurface : BrandColors.lightSurface,
      onSurface: isDark ? BrandColors.darkOnSurface : BrandColors.lightOnSurface,
      onSurfaceVariant: isDark ? BrandColors.darkMuted : BrandColors.lightMuted,
      surfaceContainerLowest: isDark ? BrandColors.darkBg : BrandColors.lightSurface,
      surfaceContainerLow: isDark ? const Color(0xFF181C3B) : const Color(0xFFFFF9F4),
      surfaceContainer: isDark ? BrandColors.darkSurfaceHigh : BrandColors.lightSurfaceHigh,
      surfaceContainerHigh: isDark ? const Color(0xFF242A4E) : const Color(0xFFF8E6D9),
      surfaceContainerHighest: isDark ? const Color(0xFF2C3358) : const Color(0xFFF2DCCC),
      outline: isDark ? const Color(0xFF454C7A) : const Color(0xFFD8C2B2),
      outlineVariant: isDark ? BrandColors.darkOutline : BrandColors.lightOutline,
      error: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD93F3F),
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

    // Selection controls (chips, segments, tabs) share one look: a solid
    // "ink" pill when selected, a soft tinted pill with a hairline otherwise.
    final ink = scheme.onSurface;
    final onInk = isDark ? BrandColors.darkBg : Colors.white;
    final track = isDark ? const Color(0xFF1B2042) : const Color(0xFFF7EBE1);
    final hairline = isDark ? BrandColors.darkOutline : const Color(0xFFEBD9CB);
    // One friendly geometric family for everything, Airbnb-style.
    final body = useGoogleFonts ? GoogleFonts.dmSansTextTheme(base.textTheme) : base.textTheme;
    TextStyle display(TextStyle? s, double size, FontWeight w, [double ls = -0.5]) => useGoogleFonts
        ? GoogleFonts.dmSans(textStyle: s, fontSize: size, fontWeight: w, letterSpacing: ls)
        : (s ?? const TextStyle()).copyWith(fontSize: size, fontWeight: w, letterSpacing: ls);

    final textTheme = body
        .copyWith(
          displayLarge: display(body.displayLarge, 52, FontWeight.w800, -1.6),
          displayMedium: display(body.displayMedium, 42, FontWeight.w800, -1.2),
          displaySmall: display(body.displaySmall, 34, FontWeight.w800, -1),
          headlineLarge: display(body.headlineLarge, 30, FontWeight.w800, -0.8),
          headlineMedium: display(body.headlineMedium, 26, FontWeight.w800, -0.6),
          headlineSmall: display(body.headlineSmall, 22, FontWeight.w700, -0.4),
          titleLarge: display(body.titleLarge, 18, FontWeight.w700, -0.2),
          titleMedium: body.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: body.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
          bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          labelLarge: body.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: body.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          labelSmall: body.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? BrandColors.darkBg : BrandColors.lightBg,
      textTheme: textTheme,
      extensions: [isDark ? AppPalette.dark : AppPalette.light],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 1 : 0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder(), textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? BrandColors.darkSurfaceHigh : BrandColors.lightSurfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
        border: const OutlineInputBorder(borderRadius: Radii.smAll, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderRadius: Radii.smAll, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: ink, width: 1)
              : BorderSide(color: hairline),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ink
              : states.contains(WidgetState.disabled)
                  ? track.withValues(alpha: 0.5)
                  : scheme.surface,
        ),
        // Chips resolve a WidgetStateColor inside a plain TextStyle (a
        // WidgetStateTextStyle is not resolved and left labels uncoloured).
        labelStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onInk
                : states.contains(WidgetState.disabled)
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(size: 18, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        backgroundColor: isDark ? BrandColors.darkSurfaceHigh : BrandColors.lightOnSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? BrandColors.darkOnSurface : Colors.white,
        ),
        actionTextColor: isDark ? BrandColors.aurora : const Color(0xFFFFB38F),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // A rounded track with the selected segment as a solid ink pill.
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? ink : track,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? onInk : scheme.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? onInk : scheme.onSurfaceVariant,
          ),
          overlayColor: WidgetStateProperty.all(ink.withValues(alpha: 0.06)),
          side: WidgetStateProperty.all(BorderSide(color: track, width: 3)),
          shape: WidgetStateProperty.all(const StadiumBorder()),
          minimumSize: WidgetStateProperty.all(const Size(0, 44)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: Space.sm)),
          textStyle: WidgetStateProperty.resolveWith(
            (states) => textTheme.labelLarge?.copyWith(
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          visualDensity: VisualDensity.standard,
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      tabBarTheme: TabBarThemeData(
        // Pill indicator; wrap tab bars in [PillTabBar] for the track behind it.
        indicator: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
        labelColor: onInk,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.circular(Radii.pill),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelPadding: const EdgeInsets.symmetric(horizontal: Space.md),
        tabAlignment: TabAlignment.start,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: onInk,
        elevation: 6,
        focusElevation: 6,
        hoverElevation: 8,
        highlightElevation: 2,
        shape: const CircleBorder(),
        iconSize: 26,
        sizeConstraints: const BoxConstraints.tightFor(width: 58, height: 58),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
