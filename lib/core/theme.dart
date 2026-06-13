/// App-wide theme for Pine-Sight (PINE) — PineSight palette + mockup typography.
library;

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // --- PineSight palette (design reference) ---
  static const Color olive = Color(0xFF76944C);
  static const Color paleLime = Color(0xFFC8D886);
  static const Color cream = Color(0xFFFBF5DB);
  static const Color accentYellow = Color(0xFFFFD21F);
  static const Color taupe = Color(0xFFC0B6AC);
  static const Color navy = Color(0xFF2E3141);

  // --- Typography (mockup) ---
  static const Color textHeading = Color(0xFF2D2D2D);
  static const Color textBody = Color(0xFF555555);
  static const Color textSubtle = Color(0xFF9E9E9E);

  // --- Legacy / semantic aliases (existing screens use these names) ---
  static const Color primaryGreen = olive;
  static const Color secondaryGreen = paleLime;
  /// Warm attention (maps); not in swatch — kept distinct from [accentYellow].
  static const Color accentOrange = Color(0xFFD97941);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = navy;
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = textHeading;
  static const Color textMedium = textBody;
  static const Color errorRed = Color(0xFFD32F2F);

  /// Brighter primary on dark backgrounds (nav, headers).
  static const Color darkModePrimaryGreen = paleLime;

  static const Color _darkSurface = navy;
  static const Color _darkSurfaceContainer = Color(0xFF3A3E52);
  static const Color _darkOnSurface = Color(0xFFEAE6DE);
  static const Color _darkOnSurfaceVariant = Color(0xFFC8C2BC);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: backgroundLight,
        colorScheme: ColorScheme.light(
          primary: olive,
          onPrimary: Colors.white,
          primaryContainer: paleLime,
          onPrimaryContainer: textHeading,
          secondary: accentYellow,
          onSecondary: textHeading,
          secondaryContainer: const Color(0xFFF9E79F),
          onSecondaryContainer: textHeading,
          tertiary: taupe,
          onTertiary: Colors.white,
          surface: surfaceWhite,
          onSurface: textHeading,
          onSurfaceVariant: textBody,
          surfaceContainerHighest: cream,
          surfaceContainerHigh: const Color(0xFFF0EBD8),
          outline: taupe,
          outlineVariant: Color.lerp(taupe, cream, 0.45)!,
          error: errorRed,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: olive,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: surfaceWhite,
          shadowColor: taupe.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        dividerTheme: DividerThemeData(
          color: taupe.withValues(alpha: 0.45),
          thickness: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: olive,
            foregroundColor: Colors.white,
            disabledBackgroundColor: taupe.withValues(alpha: 0.45),
            disabledForegroundColor: textSubtle,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: olive,
            foregroundColor: Colors.white,
            disabledBackgroundColor: taupe.withValues(alpha: 0.45),
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: olive,
            disabledForegroundColor: textSubtle,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            side: const BorderSide(color: olive, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: olive,
            disabledForegroundColor: textSubtle,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: olive,
          foregroundColor: Colors.white,
          elevation: 3,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: cream,
          disabledColor: taupe.withValues(alpha: 0.35),
          selectedColor: paleLime,
          secondarySelectedColor: accentYellow,
          labelStyle: const TextStyle(color: textHeading, fontSize: 13),
          secondaryLabelStyle: const TextStyle(color: textHeading, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: taupe.withValues(alpha: 0.5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: taupe.withValues(alpha: 0.85)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: taupe.withValues(alpha: 0.85)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: olive, width: 2),
          ),
          filled: true,
          fillColor: cream,
          hintStyle: const TextStyle(color: textSubtle),
          labelStyle: const TextStyle(color: textBody),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: olive,
          linearTrackColor: Color(0x33C0B6AC),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) return olive;
            return taupe;
          }),
          trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) {
              return paleLime.withValues(alpha: 0.85);
            }
            return taupe.withValues(alpha: 0.35);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) return olive;
            return null;
          }),
          side: const BorderSide(color: taupe, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
            if (s.contains(WidgetState.selected)) return olive;
            return taupe;
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: olive,
          inactiveTrackColor: Color(0x55C0B6AC),
          thumbColor: olive,
          overlayColor: Color(0x3376944C),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: olive,
          textColor: textHeading,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkSurface,
        colorScheme: ColorScheme.dark(
          primary: darkModePrimaryGreen,
          onPrimary: navy,
          primaryContainer: olive.withValues(alpha: 0.45),
          onPrimaryContainer: _darkOnSurface,
          secondary: accentYellow,
          onSecondary: navy,
          secondaryContainer: const Color(0xFF5C5538),
          onSecondaryContainer: _darkOnSurface,
          tertiary: taupe,
          onTertiary: navy,
          surface: _darkSurface,
          onSurface: _darkOnSurface,
          onSurfaceVariant: _darkOnSurfaceVariant,
          surfaceContainerHighest: _darkSurfaceContainer,
          outline: taupe.withValues(alpha: 0.55),
          outlineVariant: _darkSurfaceContainer,
          error: const Color(0xFFEF5350),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkSurfaceContainer,
          foregroundColor: _darkOnSurface,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _darkSurfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkModePrimaryGreen,
            foregroundColor: navy,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: darkModePrimaryGreen,
            foregroundColor: navy,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkModePrimaryGreen,
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: darkModePrimaryGreen, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkModePrimaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: _darkSurfaceContainer,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: darkModePrimaryGreen,
          foregroundColor: navy,
          elevation: 3,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: darkModePrimaryGreen,
        ),
      );

  /// Main dashboard tab area.
  static LinearGradient mainContentGradient(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF353A4D),
          _darkSurface,
          Color(0xFF2A2D3D),
        ],
        stops: <double>[0.0, 0.42, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color.lerp(cream, surfaceWhite, 0.35)!,
        backgroundLight,
        paleLime.withValues(alpha: 0.28),
      ],
      stops: const <double>[0.0, 0.48, 1.0],
    );
  }
}

/// For screens that still use explicit [AppTheme] neutrals; follows [Theme] brightness.
extension PineScreenColors on BuildContext {
  Color get pineTextPrimary =>
      Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkOnSurface
          : AppTheme.textHeading;

  Color get pineTextSecondary =>
      Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkOnSurfaceVariant
          : AppTheme.textBody;

  Color get pineTextSubtle =>
      Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkOnSurfaceVariant.withValues(alpha: 0.85)
          : AppTheme.textSubtle;

  Color get pineCardSurface =>
      Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkSurfaceContainer
          : Theme.of(this).colorScheme.surface;

  /// Muted tiles (More cards, chips).
  Color get pineMutedFill =>
      Theme.of(this).brightness == Brightness.dark
          ? const Color(0xFF45495E)
          : Theme.of(this).colorScheme.surfaceContainerHighest;

  /// Profile / highlight strip (mockup cream band).
  Color get pineProfileCream =>
      Theme.of(this).brightness == Brightness.dark
          ? AppTheme._darkSurfaceContainer
          : AppTheme.cream;
}

/// Optional patterned background for settings and other screens.
class AppBackground {
  AppBackground._();

  static Widget withPattern(BuildContext context, {required Widget child}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF353A4D),
                  AppTheme.navy,
                  Color(0xFF2A2D3D),
                ],
                stops: <double>[0.0, 0.55, 1.0],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppTheme.paleLime.withValues(alpha: 0.35),
                  AppTheme.cream,
                  AppTheme.backgroundLight,
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundPatternPainter(dark: dark),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  _BackgroundPatternPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = dark
          ? AppTheme.paleLime.withValues(alpha: 0.07)
          : AppTheme.olive.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double i = -size.height; i < size.height + size.width; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPatternPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
