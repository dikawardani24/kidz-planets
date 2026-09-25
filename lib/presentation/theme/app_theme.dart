import 'package:flutter/material.dart';

/// App theme: deep-space background, rounded headings, glass panels.
///
/// NOTE: uses system fonts (no google_fonts) so `flutter test` never
/// touches the network. Rounded feel comes from weight + spacing.
abstract final class AppTheme {
  static const space950 = Color(0xFF010206);
  static const space900 = Color(0xFF040712);
  static const space800 = Color(0xFF0C132C);
  static const space700 = Color(0xFF17234D);
  static const accentAmber = Color(0xFFFBBF24);
  static const accentSky = Color(0xFF38BDF8);
  static const accentViolet = Color(0xFF8B7CFF);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: space950,
      colorScheme: base.colorScheme.copyWith(
        primary: accentAmber,
        secondary: accentSky,
        surface: space900,
      ),
    );
  }

  static BoxDecoration get glassPanel => BoxDecoration(
        color: space800.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
        ],
      );

  static BoxDecoration get glassPill => BoxDecoration(
        color: space700.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      );

  static TextStyle get labelGlow => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 6),
          Shadow(color: Colors.black54, blurRadius: 12),
        ],
      );
}
