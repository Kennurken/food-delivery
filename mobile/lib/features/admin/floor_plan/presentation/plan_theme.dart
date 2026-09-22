import 'package:flutter/material.dart';

/// Compact editor chrome. Paper floor, ink objects, brand orange only on selection.
class PlanTheme {
  PlanTheme._();

  static const paper = Color(0xFFD8D1C3);
  static const paperDark = Color(0xFF1F1C19);
  static const floor = Color(0xFFE8E2D6);
  static const floorDark = Color(0xFF161412);
  static const ink = Color(0xFF241F1B);
  static const mute = Color(0xFF6F675C);
  static const select = Color(0xFFE8562A);
  static const tableFill = Color(0xFFF6F1E8);
  static const tableEdge = Color(0xFF3A342E);
  static const wall = Color(0xFF3A342E);
  static const bar = Color(0xFF5C4636);
  static const warn = Color(0xFFB45309);
  static const handle = Color(0xFFFFFFFF);

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? paperDark : paper;

  static Color panel(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color hairline(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color floorFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? floorDark : floor;
}
