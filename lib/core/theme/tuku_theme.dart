import 'package:flutter/material.dart';

/// Colores de la marca Tuku (sistema de diseño, tokens de color).
///
/// No hay azul ni rojo como color de marca: la marca es verde con sol de acento.
abstract final class TukuColors {
  static const verde = Color(0xFF167A3A);
  static const verdeOscuro = Color(0xFF5FD07F);
  static const sol = Color(0xFFFFC83A);
  static const onSol = Color(0xFF14231A);
}

/// Tipografías: Baloo 2 para títulos y Nunito Sans para el resto.
abstract final class TukuFonts {
  static const display = 'Baloo 2';
  static const sans = 'Nunito Sans';
}

ThemeData tukuLightTheme() => _theme(
  const ColorScheme(
    brightness: Brightness.light,
    primary: TukuColors.verde,
    onPrimary: Color(0xFFFFFFFF),
    // brote con texto verde: botón tonal, chips seleccionados, Presente.
    primaryContainer: Color(0xFFE4F5D9),
    onPrimaryContainer: TukuColors.verde,
    secondary: TukuColors.verde,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE4F5D9),
    onSecondaryContainer: TukuColors.verde,
    // aviso: Justificado, A pagar ahora, pendientes.
    tertiary: Color(0xFF9A5200),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFF0D6),
    onTertiaryContainer: Color(0xFF9A5200),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE7E4),
    onErrorContainer: Color(0xFFB3261E),
    surface: Color(0xFFF6F9F3),
    onSurface: Color(0xFF14231A),
    onSurfaceVariant: Color(0xFF4D5E53),
    // surface-raised: tarjetas, hojas, menús y diálogos.
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFFDCE6D5),
    outline: Color(0xFF7C8F81),
    outlineVariant: Color(0xFFDCE6D5),
    inverseSurface: Color(0xFF14231A),
    onInverseSurface: Color(0xFFF6F9F3),
    inversePrimary: TukuColors.verdeOscuro,
    surfaceTint: Color(0x00000000),
  ),
);

/// El tema oscuro no invierte la marca: el verde se aclara y el texto sobre él
/// pasa a oscuro.
ThemeData tukuDarkTheme() => _theme(
  const ColorScheme(
    brightness: Brightness.dark,
    primary: TukuColors.verdeOscuro,
    onPrimary: Color(0xFF0E1611),
    primaryContainer: Color(0xFF173622),
    onPrimaryContainer: TukuColors.verdeOscuro,
    secondary: TukuColors.verdeOscuro,
    onSecondary: Color(0xFF0E1611),
    secondaryContainer: Color(0xFF173622),
    onSecondaryContainer: TukuColors.verdeOscuro,
    tertiary: Color(0xFFFFC46B),
    onTertiary: Color(0xFF0E1611),
    tertiaryContainer: Color(0xFF3A2A10),
    onTertiaryContainer: Color(0xFFFFC46B),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF0E1611),
    errorContainer: Color(0xFF3B1513),
    onErrorContainer: Color(0xFFFF8A80),
    surface: Color(0xFF0E1611),
    onSurface: Color(0xFFE9F2EB),
    onSurfaceVariant: Color(0xFFA7B9AC),
    surfaceContainerLowest: Color(0xFF16211A),
    surfaceContainerLow: Color(0xFF16211A),
    surfaceContainer: Color(0xFF16211A),
    surfaceContainerHigh: Color(0xFF16211A),
    surfaceContainerHighest: Color(0xFF2A3B30),
    outline: Color(0xFF6B8273),
    outlineVariant: Color(0xFF2A3B30),
    inverseSurface: Color(0xFFE9F2EB),
    onInverseSurface: Color(0xFF14231A),
    inversePrimary: TukuColors.verde,
    surfaceTint: Color(0x00000000),
  ),
);

// Radios de la marca: chips, botones y campos, tarjetas y hojas.
const _radiusSm = BorderRadius.all(Radius.circular(8));
const _radiusMd = BorderRadius.all(Radius.circular(14));
const _radiusLg = BorderRadius.all(Radius.circular(20));
const _radiusXl = Radius.circular(28);

ThemeData _theme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, fontFamily: TukuFonts.sans);
  final text = base.textTheme;
  final dark = scheme.brightness == Brightness.dark;

  // Tamaño y alto de línea en px, como en los tokens.
  TextStyle sans(TextStyle? style, double size, double height, FontWeight w) =>
      style!.copyWith(fontSize: size, height: height / size, fontWeight: w);
  TextStyle display(TextStyle? s, double size, double height, FontWeight w) =>
      sans(s, size, height, w).copyWith(fontFamily: TukuFonts.display);

  final textTheme = text.copyWith(
    displayLarge: display(text.displayLarge, 57, 64, FontWeight.w800),
    displayMedium: display(text.displayMedium, 45, 52, FontWeight.w800),
    // display-xl, display-lg y titulo.
    displaySmall: display(text.displaySmall, 40, 44, FontWeight.w800),
    headlineLarge: display(text.headlineLarge, 32, 36, FontWeight.w800),
    headlineMedium: display(text.headlineMedium, 28, 34, FontWeight.w700),
    headlineSmall: display(text.headlineSmall, 24, 30, FontWeight.w700),
    // subtitulo, cuerpo, cuerpo-fuerte, detalle y etiqueta.
    titleLarge: sans(text.titleLarge, 20, 28, FontWeight.w700),
    titleMedium: sans(text.titleMedium, 16, 24, FontWeight.w700),
    titleSmall: sans(text.titleSmall, 14, 20, FontWeight.w700),
    bodyLarge: sans(text.bodyLarge, 16, 24, FontWeight.w400),
    bodyMedium: sans(text.bodyMedium, 14, 20, FontWeight.w400),
    bodySmall: sans(text.bodySmall, 12, 16, FontWeight.w400),
    labelLarge: sans(text.labelLarge, 14, 20, FontWeight.w700),
    labelMedium: sans(text.labelMedium, 12, 16, FontWeight.w700),
    labelSmall: sans(text.labelSmall, 11, 16, FontWeight.w700),
  );

  const buttonShape = WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: _radiusMd),
  );
  final buttonText = WidgetStatePropertyAll(
    textTheme.labelLarge!.copyWith(fontSize: 16),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: display(
        text.titleLarge,
        22,
        28,
        FontWeight.w700,
      ).copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x2914231A),
      shape: const RoundedRectangleBorder(borderRadius: _radiusLg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(shape: buttonShape, textStyle: buttonText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(shape: buttonShape, textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.12)
                : scheme.outline,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: const OutlineInputBorder(borderRadius: _radiusMd),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radiusMd,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radiusMd,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _radiusMd,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _radiusMd,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: _radiusSm),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: _radiusXl),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(_radiusXl),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
