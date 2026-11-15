part of '../main.dart';

// Brand palette

class _BrandPalette {
  // Warm gold for Beacon, with contrast adapted to each theme
  static const Color gold = Color(0xFFBD8610);
  static const Color goldBright = Color(0xFFF0C653);
  static const Color goldSoft = Color(0xFFF8E7AF);
  static const Color goldDeep = Color(0xFF806016);
  static const Color navy = Color(0xFF252820);

  // Light mode: warm limestone
  static const Color limestone = Color(0xFFF7F7F2);
  static const Color warmPaper = Color(0xFFF4F4ED);
  static const Color warmWhite = Color(0xFFFFFFFF);
  static const Color sand = Color(0xFFDDDFD4);
  static const Color stone = Color(0xFFEAECE2);
  static const Color clay = Color(0xFF777B6E);
  static const Color navySoft = Color(0xFFF2F0E5);

  // Dark mode: graphite stone
  static const Color obsidian = Color(0xFF161915);
  static const Color slatePanel = Color(0xFF1A1E19);
  static const Color slateCard = Color(0xFF20251F);
  static const Color slateRaised = Color(0xFF262D25);
  static const Color slateHigh = Color(0xFF30382E);
  static const Color slateBorder = Color(0xFF424B3E);
  static const Color slateMuted = Color(0xFFB9C2B3);
  static const Color slateText = Color(0xFFEFF2E9);
}

class CornerstoneApp extends StatelessWidget {
  const CornerstoneApp({required this.themeController, super.key});

  final CornerstoneThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cornerstone',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeController.themeMode,
          themeAnimationCurve: Curves.easeOutCubic,
          themeAnimationDuration: const Duration(milliseconds: 320),
          builder: (context, child) =>
              _AppBackdrop(child: child ?? const SizedBox.shrink()),
          home: CornerstoneHomePage(themeController: themeController),
        );
      },
    );
  }

  TextTheme _buildTextTheme(ColorScheme scheme) {
    final base = GoogleFonts.manropeTextTheme();
    final headingFamily = GoogleFonts.manrope().fontFamily;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: scheme.onSurface,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: scheme.onSurface,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
      ),
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.2,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: headingFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: _BrandPalette.gold,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? _BrandPalette.goldBright : _BrandPalette.goldDeep,
          onPrimary: isDark ? _BrandPalette.navy : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF3E351D)
              : const Color(0xFFF8EDC3),
          onPrimaryContainer: isDark
              ? _BrandPalette.goldSoft
              : _BrandPalette.navy,
          secondary: isDark ? _BrandPalette.slateText : _BrandPalette.navy,
          onSecondary: isDark
              ? _BrandPalette.obsidian
              : _BrandPalette.warmWhite,
          secondaryContainer: isDark
              ? _BrandPalette.slateHigh
              : _BrandPalette.navySoft,
          onSecondaryContainer: isDark
              ? _BrandPalette.slateText
              : _BrandPalette.navy,
          tertiary: isDark ? const Color(0xFFC7AC7F) : _BrandPalette.clay,
          onTertiary: isDark ? _BrandPalette.obsidian : _BrandPalette.warmWhite,
          surface: isDark ? _BrandPalette.slateCard : _BrandPalette.warmWhite,
          surfaceContainerLow: isDark
              ? _BrandPalette.slatePanel
              : _BrandPalette.warmPaper,
          surfaceContainerHigh: isDark
              ? _BrandPalette.slateHigh
              : _BrandPalette.stone,
          outlineVariant: isDark
              ? _BrandPalette.slateBorder
              : _BrandPalette.sand,
          surfaceTint: isDark ? _BrandPalette.goldDeep : _BrandPalette.gold,
          onSurface: isDark ? _BrandPalette.slateText : _BrandPalette.navy,
          onSurfaceVariant: isDark
              ? _BrandPalette.slateMuted
              : const Color(0xFF666C5F),
          error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
          onError: isDark ? _BrandPalette.obsidian : _BrandPalette.warmWhite,
          errorContainer: isDark
              ? const Color(0xFF8C1D18)
              : const Color(0xFFF9DEDC),
          onErrorContainer: isDark
              ? const Color(0xFFFFDAD6)
              : const Color(0xFF410E0B),
        );

    final textTheme = _buildTextTheme(scheme);
    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: GoogleFonts.manrope().fontFamily,
      scaffoldBackgroundColor: isDark
          ? _BrandPalette.obsidian
          : _BrandPalette.limestone,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Color.alphaBlend(
          scheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
          scheme.surfaceContainerLow,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.54),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color.alphaBlend(
          scheme.surface.withValues(alpha: 0.95),
          scheme.surfaceContainerLow,
        ),
        selectedColor: isDark
            ? _BrandPalette.goldBright.withValues(alpha: 0.22)
            : _BrandPalette.gold.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: scheme.onSurface,
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.64)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? _BrandPalette.goldBright : _BrandPalette.gold,
        linearTrackColor: isDark
            ? _BrandPalette.slateBorder
            : _BrandPalette.stone,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(6),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        useIndicator: true,
        indicatorColor: isDark
            ? Color.alphaBlend(
                _BrandPalette.goldBright.withValues(alpha: 0.16),
                _BrandPalette.slateHigh,
              )
            : Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.12),
                scheme.surfaceContainerLow,
              ),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 21),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
        selectedLabelTextStyle: GoogleFonts.manrope(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        unselectedLabelTextStyle: GoogleFonts.manrope(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: isDark ? scheme.primary : scheme.secondary,
        selectedTileColor: isDark
            ? Color.alphaBlend(
                _BrandPalette.goldBright.withValues(alpha: 0.12),
                scheme.surfaceContainerLow,
              )
            : Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.10),
                scheme.surface,
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? scheme.primary : scheme.secondary,
          backgroundColor: Color.alphaBlend(
            scheme.surface.withValues(alpha: 0.92),
            scheme.surfaceContainerLow,
          ),
          elevation: 0,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          backgroundColor: Color.alphaBlend(
            scheme.surface.withValues(alpha: 0.88),
            scheme.surfaceContainerLow,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.onPrimary;
            return scheme.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return scheme.surface;
          }),
          side: WidgetStateProperty.resolveWith(
            (_) => BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.68),
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.alphaBlend(
          scheme.surface.withValues(alpha: isDark ? 0.72 : 0.94),
          scheme.surfaceContainerLow,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.manrope(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.manrope(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.84),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Color.alphaBlend(
              scheme.surface.withValues(alpha: 0.96),
              scheme.surfaceContainerLow,
            ),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(panelShape),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.68)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _BrandPalette.slateHigh : _BrandPalette.navy,
        contentTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}
