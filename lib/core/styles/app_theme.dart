import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// System sans-serif type keeps Chinese labels and numbers consistent.
TextTheme appTextTheme(AppPalette p) {
  final fontFamily = ThemeData().textTheme.bodyMedium?.fontFamily;
  TextStyle s(double size, FontWeight w, {double spacing = 0, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        color: color ?? p.textStrong,
      );
  return TextTheme(
    displayLarge: s(57, FontWeight.w700, spacing: -1),
    displayMedium: s(45, FontWeight.w700, spacing: -0.5),
    displaySmall: s(36, FontWeight.w700),
    headlineLarge: s(32, FontWeight.w700),
    headlineMedium: s(28, FontWeight.w600),
    headlineSmall: s(22, FontWeight.w600),
    titleLarge: s(21, FontWeight.w600),
    titleMedium: s(16, FontWeight.w600),
    titleSmall: s(14, FontWeight.w600),
    bodyLarge: s(16, FontWeight.w400),
    bodyMedium: s(14, FontWeight.w400),
    bodySmall: s(12.5, FontWeight.w400, color: p.textMuted),
    labelLarge: s(15, FontWeight.w500),
    labelMedium: s(13, FontWeight.w500),
    labelSmall: s(11.5, FontWeight.w500, color: p.textMuted),
  );
}

/// Builds the friendly-flat [ThemeData] for a palette. Component themes carry
/// the rounded shapes and flat surfaces so the look propagates app-wide; depth
/// lives in the [AppCard] widget rather than in heavy elevation here.
ThemeData buildAppTheme(AppPalette p) {
  final scheme = p.colorScheme;
  final text = appTextTheme(p);
  const pill = RoundedRectangleBorder(borderRadius: Dimens.borderRadiusControl);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.canvas,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Dimens.borderRadiusCard,
        side: BorderSide(color: p.border, width: Dimens.hairline),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarThemeData(
      systemOverlayStyle: p.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.textStrong,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accent.withValues(alpha: 0.16),
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: pill,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size(64, Dimens.minTouchTarget),
        shape: pill,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: text.labelLarge,
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, Dimens.minTouchTarget),
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, Dimens.minTouchTarget),
        shape: pill,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(shape: Dimens.shapeControl),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: p.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing16,
        vertical: Dimens.spacing12,
      ),
      border: const OutlineInputBorder(
        borderRadius: Dimens.borderRadiusControl,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: Dimens.borderRadiusControl,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Dimens.borderRadiusControl,
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      backgroundColor: p.surfaceMuted,
      side: BorderSide.none,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: Dimens.borderRadiusModal,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: Dimens.borderRadiusControl),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimens.radiusModal),
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
