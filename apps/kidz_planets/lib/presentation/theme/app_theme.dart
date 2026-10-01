import 'dart:ui';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const space950 = Color(0xFF010206);
  static const space900 = Color(0xFF040712);
  static const space800 = Color(0xFF0C132C);
  static const space700 = Color(0xFF17234D);
  static const accentAmber = Color(0xFFFBBF24);
  static const accentSky = Color(0xFF38BDF8);
  static const accentViolet = Color(0xFF8B7CFF);
  static const accentIndigo = Color(0xFF4F46E5);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: space950,
      colorScheme: base.colorScheme.copyWith(primary: accentAmber, secondary: accentSky, surface: space900),
    );
  }

  static BoxDecoration get glassPanel => BoxDecoration(
    color: space800.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))],
  );

  static BoxDecoration get glassPill => BoxDecoration(
    color: space700.withValues(alpha: 0.90),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
  );

  static Widget glass({required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero, BorderRadius radius = const BorderRadius.all(Radius.circular(28)), bool pill = false}) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: pill ? 14 : 20, sigmaY: pill ? 14 : 20),
        child: Container(padding: padding, decoration: pill ? glassPill : glassPanel, child: child),
      ),
    );
  }

  static TextStyle get labelGlow => const TextStyle(
    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
    shadows: [Shadow(color: Colors.black87, blurRadius: 6), Shadow(color: Colors.black54, blurRadius: 12)],
  );
}
