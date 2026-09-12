import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const small = 14.0;
  static const medium = 22.0;
  static const large = 30.0;
  static const pill = 999.0;
}

abstract final class AppIcons {
  static const small = 20.0;
  static const standard = 24.0;
  static const feature = 48.0;
  static const illustration = 96.0;
}

/// Blue owns navigation and actions; other colors describe learning moments.
abstract final class AppPalette {
  static const sky = Color(0xFF4EA8FF);
  static const ocean = Color(0xFF2563EB);
  static const ink = Color(0xFF25283A);
  // Slightly deeper than the reference gray for readable body text on cream.
  static const muted = Color(0xFF62697A);
  static const paper = Color(0xFFFFF9F2);
  static const surface = Colors.white;
  static const blueWash = Color(0xFFEAF3FF);
  static const outline = Color(0xFFE3E7EF);
  static const sunshine = Color(0xFFFFD95A);
  static const coral = Color(0xFFFF8EAA);
  static const lilac = Color(0xFFA99CFF);
  static const mint = Color(0xFF8EDFC6);
  static const peach = Color(0xFFFFDDD0);
  static const success = Color(0xFF17694F);
  static const successSurface = Color(0xFFE2F6ED);
  static const review = Color(0xFF934157);
  static const reviewSurface = Color(0xFFFFEDF2);
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF285DE0), Color(0xFF2868D5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const artworkAccents = [sky, sunshine, lilac, coral, mint];
  static const artworkSurfaces = [
    Color(0xFFDDEEFF),
    Color(0xFFFFEFB2),
    Color(0xFFE7E1FF),
    Color(0xFFFFDFE8),
    Color(0xFFDDF4EA),
  ];

  static int variant(String identity) =>
      identity.codeUnits.fold(0, (a, b) => a + b) % artworkAccents.length;
  static Color accent(String identity) => artworkAccents[variant(identity)];
  static Color artworkSurface(String identity) =>
      artworkSurfaces[variant(identity)];
  static Color softSurface(BuildContext context, Color accent) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.alphaBlend(
          accent.withValues(alpha: 0.16),
          Theme.of(context).colorScheme.surface,
        )
      : Color.lerp(Colors.white, accent, 0.20)!;
}

abstract final class AppShadows {
  static const surface = [
    BoxShadow(color: Color(0x0925283A), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const hero = [
    BoxShadow(color: Color(0x292563EB), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x1325283A), blurRadius: 16, offset: Offset(0, 5)),
  ];
}
