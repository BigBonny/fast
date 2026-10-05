// lib/theme.dart
// FAST design system: brand tokens, light/dark themes, semantic shades.
//
// Use `context.fast.<color>` for surface/text colors so widgets follow
// the active ThemeMode. Brand colors are theme-independent constants.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic color set that flips with the active brightness.
class FASTShades {
  const FASTShades({
    required this.bg,
    required this.card,
    required this.cardHigh,
    required this.line,
    required this.faint,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.shadow,
    required this.amberSoftBg,
    required this.amberSoftBorder,
  });

  /// Page / scaffold background.
  final Color bg;

  /// Primary cards and sheets.
  final Color card;

  /// Slightly elevated surface (chips, inputs, nested cards).
  final Color cardHigh;

  /// Hairline borders and dividers on cards.
  final Color line;

  /// Disabled icons, strong dividers, subtle fills.
  final Color faint;

  /// Primary text.
  final Color t1;

  /// Secondary text.
  final Color t2;

  /// Muted text / placeholders.
  final Color t3;

  /// Shadow color for elevated cards.
  final Color shadow;

  /// Soft amber tinted background for highlighted pills/badges.
  final Color amberSoftBg;

  /// Border color that pairs with [amberSoftBg].
  final Color amberSoftBorder;

  static const FASTShades dark = FASTShades(
    bg: Color(0xFF0A0A0C),
    card: Color(0xFF18181B),
    cardHigh: Color(0xFF1F1F23),
    line: Color(0xFF27272A),
    faint: Color(0xFF3F3F46),
    t1: Color(0xFFF4F4F5),
    t2: Color(0xFFA1A1AA),
    t3: Color(0xFF71717A),
    shadow: Color(0x66000000),
    amberSoftBg: Color(0x33F59E0B),
    amberSoftBorder: Color(0x66F59E0B),
  );

  static const FASTShades light = FASTShades(
    bg: Color(0xFFF7F5F2),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFF3F1ED),
    line: Color(0xFFE8E4DE),
    faint: Color(0xFFD8D4CC),
    t1: Color(0xFF17171B),
    t2: Color(0xFF52525B),
    t3: Color(0xFF9C9CA4),
    shadow: Color(0x14000000),
    amberSoftBg: Color(0xFFFEF3E2),
    amberSoftBorder: Color(0xFFF6D9A8),
  );
}

extension FASTShadesX on BuildContext {
  FASTShades get fast => Theme.of(this).brightness == Brightness.dark
      ? FASTShades.dark
      : FASTShades.light;
}

/// FAST brand tokens (used by both themes).
class FASTBrand {
  FASTBrand._();

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDeep = Color(0xFFD97706);
  static const Color ember = Color(0xFFEA580C);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// On-amber content color — dark text reads best on the brand color.
  static const Color onAmber = Color(0xFF17171B);

  static const LinearGradient heroGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF7EA), Color(0xFFFFEAD0)],
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF171410), Color(0xFF20190F)],
  );

  static const LinearGradient proGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C8B3), Color(0xFFFF0066)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber, ember],
  );
}

class FASTTheme {
  FASTTheme._();

  static const _radiusCard = 20.0;

  static ThemeData light() => _base(FASTShades.light, Brightness.light);
  static ThemeData dark() => _base(FASTShades.dark, Brightness.dark);

  static ThemeData _base(FASTShades sh, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 22,
        letterSpacing: -0.5,
        color: sh.t1,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: -0.3,
        color: sh.t1,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: sh.t1,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: sh.t1,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: sh.t2,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 11,
        color: sh.t3,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 1.0,
        color: sh.t3,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: sh.bg,
      cardColor: sh.card,
      dividerColor: sh.line,
      shadowColor: sh.shadow,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: FASTBrand.amber,
        onPrimary: FASTBrand.onAmber,
        secondary: FASTBrand.amberDeep,
        onSecondary: Colors.white,
        surface: sh.card,
        onSurface: sh.t1,
        surfaceContainerHighest: sh.cardHigh,
        error: FASTBrand.error,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        backgroundColor: sh.bg,
        foregroundColor: sh.t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: sh.t1),
      ),
      cardTheme: CardThemeData(
        color: sh.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusCard),
          side: BorderSide(color: sh.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sh.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sh.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? sh.cardHigh : const Color(0xFF17171B),
        contentTextStyle: TextStyle(
          color: isDark ? sh.t1 : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sh.cardHigh,
        hintStyle: TextStyle(color: sh.t3, fontSize: 13),
        labelStyle: TextStyle(color: sh.t2, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: sh.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: sh.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FASTBrand.amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FASTBrand.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FASTBrand.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sh.card,
        selectedColor: FASTBrand.amber,
        disabledColor: sh.cardHigh,
        labelStyle: TextStyle(
          color: sh.t1,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(
          color: FASTBrand.onAmber,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        side: BorderSide(color: sh.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FASTBrand.amber,
          foregroundColor: FASTBrand.onAmber,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sh.t1,
          side: BorderSide(color: sh.line),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FASTBrand.amberDeep,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      dividerTheme: DividerThemeData(color: sh.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: sh.t2,
        textColor: sh.t1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? FASTBrand.amber : sh.t3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FASTBrand.amber.withValues(alpha: 0.4)
              : sh.faint,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FASTBrand.amber,
      ),
      iconTheme: IconThemeData(color: sh.t1, size: 22),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Base44 Fast Pro palette — teal primary + magenta accent (espace restaurateur).
class FASTPro {
  FASTPro._();
  static const Color teal = Color(0xFF00C8B3);
  static const Color tealDark = Color(0xFF00A090);
  static const Color magenta = Color(0xFFFF0066);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color header = Color(0xFF020617);
  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFF00C8B3), Color(0xFFFF0066)],
  );
}
