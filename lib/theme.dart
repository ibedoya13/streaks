import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual identity for the Streaks app.
///
/// The palette is built from warm cream neutrals for the surfaces, with
/// orange, red and yellow reserved for the accents that carry meaning:
/// fire (streaks), danger (destructive actions) and highlights.
class StreaksTheme {
  // Warm neutrals: the canvas stays quiet so the fire colours stand out.
  static const cream = Color(0xFFFDF6EC);
  static const creamDeep = Color(0xFFF6EADA);
  static const creamSurface = Color(0xFFFFFBF4);
  static const ink = Color(0xFF3A2E22);
  static const inkMuted = Color(0xFF8A7862);

  // Fire accents.
  static const flameYellow = Color(0xFFFFC53D);
  static const flameOrange = Color(0xFFF79009);
  static const flameRed = Color(0xFFD92D20);
  static const ember = Color(0xFF9A4A12);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// How the status bar and the navigation bar have to be painted.
  ///
  /// The surfaces of the app are cream in light mode and very dark in dark
  /// mode, so the icons of the system bars have to be dark in the first
  /// case and light in the second. Without this they end up white on a
  /// cream background, where they cannot be read.
  static SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isLight
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = isLight
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: flameOrange,
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFFFE3BC),
            onPrimaryContainer: ember,
            secondary: flameRed,
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFFBD9D5),
            onSecondaryContainer: Color(0xFF7A1B12),
            tertiary: flameYellow,
            onTertiary: Color(0xFF4A3200),
            tertiaryContainer: Color(0xFFFFF0C7),
            onTertiaryContainer: Color(0xFF6B4A00),
            error: Color(0xFFB3261E),
            onError: Color(0xFFFFFFFF),
            surface: creamSurface,
            onSurface: ink,
            surfaceContainerHighest: creamDeep,
            onSurfaceVariant: inkMuted,
            outline: Color(0xFFC9B79B),
            outlineVariant: Color(0xFFE7DAC6),
          )
        : const ColorScheme(
            brightness: Brightness.dark,
            primary: flameOrange,
            onPrimary: Color(0xFF2A1500),
            primaryContainer: Color(0xFF7A3D00),
            onPrimaryContainer: Color(0xFFFFDDB3),
            secondary: flameRed,
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFF6B1F14),
            onSecondaryContainer: Color(0xFFFFDAD4),
            tertiary: flameYellow,
            onTertiary: Color(0xFF3B2800),
            tertiaryContainer: Color(0xFF5A3F00),
            onTertiaryContainer: Color(0xFFFFE08A),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            surface: Color(0xFF241B12),
            onSurface: Color(0xFFF3E5D6),
            surfaceContainerHighest: Color(0xFF32271C),
            onSurfaceVariant: Color(0xFFD3C2AE),
            outline: Color(0xFF9C8B77),
            outlineVariant: Color(0xFF4A3E31),
          );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isLight ? cream : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        // The app bar is transparent, so Flutter would pick the system bar
        // icons from the foreground colour and leave them white on the
        // cream surface. They have to follow the brightness instead.
        systemOverlayStyle: systemOverlayStyleFor(brightness),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? creamSurface : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? creamSurface
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
