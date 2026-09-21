import 'package:flutter/services.dart';

/// Tactile confirmation for the moments that matter. Silent no-op on devices without a motor.
class Haptics {
  Haptics._();

  static void tap() => HapticFeedback.selectionClick();
  static void add() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();
  static void warn() => HapticFeedback.heavyImpact();
}
