import 'package:flutter/material.dart';

/// Theme buttons stretch full width (CTAs at the bottom of a screen).
/// Use [inline] for buttons that live inside a Row / Wrap / card corner.
class AppButtons {
  AppButtons._();

  static final inline = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
