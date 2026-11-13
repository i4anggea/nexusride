import 'package:flutter/services.dart';

class HapticService {
  static Future<void> light() =>
      HapticFeedback.lightImpact();

  static Future<void> medium() =>
      HapticFeedback.mediumImpact();

  static Future<void> heavy() =>
      HapticFeedback.heavyImpact();

  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  static Future<void> error() =>
      HapticFeedback.heavyImpact();
}
