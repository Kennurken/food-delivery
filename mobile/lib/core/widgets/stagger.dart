import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion.dart';

/// Fade + slide-up entrance, staggered by index (jitter "Animated App List").
extension StaggerX on Widget {
  Widget stagger(int index, {double slide = 0.08}) =>
      animate(delay: Motion.stagger * index)
          .fadeIn(duration: Motion.normal, curve: Motion.enter)
          .slideY(
            begin: slide,
            end: 0,
            duration: Motion.normal,
            curve: Motion.enter,
          );
}
