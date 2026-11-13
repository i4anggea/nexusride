import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colores de marca ──────────────────────────────────
  static const _primaryColor = Color(0xFF1B4FD8); // azul seguridad
  static const _secondaryColor = Color(0xFF0F9E6A); // verde "estás bien"
  static const _errorColor = Color(0xFFD63B3B); // rojo emergencia
  static const _warningColor = Color(0xFFD97706); // ámbar advertencia

  // ── Tema claro ────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
          secondary: _secondaryColor,
          error: _errorColor,
        ),
        // Tipografía Inter en toda la app
        textTheme: GoogleFonts.interTextTheme(
          _textTheme,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: Colors.black.withValues(alpha: 0.08), width: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.12), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.12), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _errorColor, width: 0.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
                color: Colors.black.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        extensions: const [_appColors],
      );

  // ── Tema oscuro ───────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.dark,
          secondary: _secondaryColor,
          error: _errorColor,
        ),
        textTheme: GoogleFonts.interTextTheme(
          _textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6B8FF8), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        extensions: const [_appColors],
      );

  // ── Tipografía unificada ──────────────────────────────
  static const _textTheme = TextTheme(
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w300, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyLarge:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
    bodyMedium:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall:
        TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
  );

  // ── Colores semánticos personalizados ─────────────────
  static const _appColors = AppColors(
    emergency: _errorColor,
    emergencyLight: Color(0xFFFEF2F2),
    safe: _secondaryColor,
    safeLight: Color(0xFFECFDF5),
    warning: _warningColor,
    warningLight: Color(0xFFFFFBEB),
    bleConnected: Color(0xFF0F9E6A),
    bleDisconnected: Color(0xFF9CA3AF),
  );
}

// ── Extensión de colores semánticos del dominio ───────────
// Úsalos así: Theme.of(context).extension<AppColors>()!.emergency
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color emergency;
  final Color emergencyLight;
  final Color safe;
  final Color safeLight;
  final Color warning;
  final Color warningLight;
  final Color bleConnected;
  final Color bleDisconnected;

  const AppColors({
    required this.emergency,
    required this.emergencyLight,
    required this.safe,
    required this.safeLight,
    required this.warning,
    required this.warningLight,
    required this.bleConnected,
    required this.bleDisconnected,
  });

  @override
  AppColors copyWith({
    Color? emergency,
    Color? emergencyLight,
    Color? safe,
    Color? safeLight,
    Color? warning,
    Color? warningLight,
    Color? bleConnected,
    Color? bleDisconnected,
  }) =>
      AppColors(
        emergency: emergency ?? this.emergency,
        emergencyLight: emergencyLight ?? this.emergencyLight,
        safe: safe ?? this.safe,
        safeLight: safeLight ?? this.safeLight,
        warning: warning ?? this.warning,
        warningLight: warningLight ?? this.warningLight,
        bleConnected: bleConnected ?? this.bleConnected,
        bleDisconnected: bleDisconnected ?? this.bleDisconnected,
      );

  @override
  AppColors lerp(AppColors other, double t) => AppColors(
        emergency: Color.lerp(emergency, other.emergency, t)!,
        emergencyLight: Color.lerp(emergencyLight, other.emergencyLight, t)!,
        safe: Color.lerp(safe, other.safe, t)!,
        safeLight: Color.lerp(safeLight, other.safeLight, t)!,
        warning: Color.lerp(warning, other.warning, t)!,
        warningLight: Color.lerp(warningLight, other.warningLight, t)!,
        bleConnected: Color.lerp(bleConnected, other.bleConnected, t)!,
        bleDisconnected: Color.lerp(bleDisconnected, other.bleDisconnected, t)!,
      );
}
