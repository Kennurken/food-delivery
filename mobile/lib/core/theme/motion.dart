import 'package:flutter/widgets.dart';

/// Motion tokens. Values borrowed from animate-ui / jitter presets so the app
/// reads like one system instead of per-widget guesses.
class Motion {
  Motion._();

  // Durations
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const stagger = Duration(milliseconds: 55);

  // Curves
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const pop = Curves.easeOutBack;
  static const emphasized = Cubic(0.2, 0, 0, 1);

  // animate-ui Button: hoverScale 1.05, tapScale 0.95
  static const tapScale = 0.95;
  static const hoverScale = 1.05;

  // animate-ui Tabs: { type: "spring", stiffness: 300, damping: 32 }
  static final tabsSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 32,
  );

  // animate-ui Sheet: { type: "spring", stiffness: 150, damping: 22 }
  static final sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 150,
    damping: 22,
  );

  /// Slightly bouncy spring for badges / counters (jitter "Interactive Badges").
  static final bounce = SpringDescription(mass: 1, stiffness: 400, damping: 18);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
