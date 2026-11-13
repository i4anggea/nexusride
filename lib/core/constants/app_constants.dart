import 'package:flutter/foundation.dart';

class AppConstants {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const googleMapsKeyAndroid = String.fromEnvironment(
    'GOOGLE_MAPS_KEY_ANDROID',
  );
  static const googleMapsKeyIos = String.fromEnvironment('GOOGLE_MAPS_KEY_IOS');

  static void validate({required bool isAndroid}) {
    validateValues(
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
      googleMapsKey: isAndroid ? googleMapsKeyAndroid : googleMapsKeyIos,
      googleMapsKeyName: isAndroid
          ? 'GOOGLE_MAPS_KEY_ANDROID'
          : 'GOOGLE_MAPS_KEY_IOS',
    );
  }

  @visibleForTesting
  static void validateValues({
    required String supabaseUrl,
    required String supabasePublishableKey,
    required String googleMapsKey,
    required String googleMapsKeyName,
  }) {
    if (supabaseUrl.trim().isEmpty) {
      throw StateError(
        'Falta SUPABASE_URL. Ejecuta la app con --dart-define-from-file=.env.dev.json.',
      );
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !const {'http', 'https'}.contains(uri.scheme)) {
      throw StateError('SUPABASE_URL no es una URL HTTP/HTTPS válida.');
    }

    if (supabasePublishableKey.trim().isEmpty) {
      throw StateError(
        'Falta SUPABASE_PUBLISHABLE_KEY. Ejecuta la app con --dart-define-from-file=.env.dev.json.',
      );
    }

    if (googleMapsKey.trim().isEmpty) {
      throw StateError(
        'Falta $googleMapsKeyName. Ejecuta la app con --dart-define-from-file=.env.dev.json.',
      );
    }
  }

  static const gpsUpdateIntervalSeconds = 5;
  static const bleReconnectDelaySeconds = 3;
  static const emergencyCountdownSeconds = 30;
  // ESP32 sends impact readings after its acceleration-magnitude gate (>3.17 G).
  static const accidentGForceThreshold = 3.0;
}
