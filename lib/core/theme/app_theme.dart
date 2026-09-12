import 'package:flutter/material.dart';
import 'package:learning_platform/core/motion/app_motion.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light({
    bool highContrast = false,
    bool largeTargets = false,
  }) => _theme(Brightness.light, highContrast, largeTargets);
  static ThemeData dark({
    bool highContrast = false,
    bool largeTargets = false,
  }) => _theme(Brightness.dark, highContrast, largeTargets);

  static ThemeData _theme(
    Brightness brightness,
    bool highContrast,
    bool largeTargets,
  ) {
    final generated = ColorScheme.fromSeed(
      seedColor: AppPalette.ocean,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
    );
    final colors = brightness == Brightness.light && !highContrast
        ? generated.copyWith(
            primary: AppPalette.ocean,
            onPrimary: Colors.white,
            primaryContainer: AppPalette.blueWash,
            onPrimaryContainer: AppPalette.ink,
            secondary: AppPalette.sky,
            onSecondary: AppPalette.ink,
            secondaryContainer: AppPalette.blueWash,
            onSecondaryContainer: AppPalette.ink,
            tertiary: AppPalette.lilac,
            onTertiary: AppPalette.ink,
            tertiaryContainer: AppPalette.artworkSurfaces[2],
            onTertiaryContainer: AppPalette.ink,
            surface: AppPalette.surface,
            onSurface: AppPalette.ink,
            surfaceContainerLowest: AppPalette.surface,
            surfaceContainerLow: AppPalette.paper,
            surfaceContainerHighest: AppPalette.blueWash,
            onSurfaceVariant: AppPalette.muted,
            outline: AppPalette.muted,
            outlineVariant: AppPalette.outline,
          )
        : generated;
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
    );
    final button =
        FilledButton.styleFrom(
          minimumSize: Size(
            AppSpacing.touchTarget,
            largeTargets ? 56 : AppSpacing.touchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.small,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          animationDuration: AppMotion.micro,
          foregroundBuilder: (context, states, child) => AnimatedScale(
            scale: states.contains(WidgetState.pressed) ? 0.97 : 1,
            duration: AppMotion.duration(context, AppMotion.micro),
            curve: AppMotion.curve,
            child: child,
          ),
        );
    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppPalette.paper
          : colors.surface,
      visualDensity: VisualDensity.standard,
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? AppPalette.paper
            : colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: AppPalette.ink.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        color: colors.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(AppSpacing.medium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.copyWith(
          elevation: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ||
                    states.contains(WidgetState.pressed)
                ? 0
                : states.contains(WidgetState.hovered)
                ? 4
                : 2,
          ),
          shadowColor: WidgetStatePropertyAll(
            colors.primary.withValues(alpha: 0.25),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : colors.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : colors.onPrimary,
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.touchTarget),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerLowest,
        height: 76,
        indicatorColor: colors.primary,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        useIndicator: true,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.primary),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: colors.surfaceContainerLowest,
        selectedColor: colors.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        labelStyle: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.small,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLowest),
        side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: shape,
        backgroundColor: colors.surfaceContainerLowest,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colors.surfaceContainerLowest,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.xSmall,
        ),
        shape: shape,
        minVerticalPadding: AppSpacing.small,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _LearningPageTransitions(),
        },
      ),
    );
  }
}

class _LearningPageTransitions extends PageTransitionsBuilder {
  const _LearningPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppMotion.transition(context, animation, child);
}
