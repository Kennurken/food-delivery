import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/buttons.dart';
import '../theme/motion.dart';

/// Centered icon-in-a-circle + title + optional hint/action. Scrollable so
/// pull-to-refresh keeps working on empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduced = Motion.reduced(context);
    Widget mark = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
    );
    Widget heading = Text(
      title,
      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    Widget? sub = hint == null
        ? null
        : Text(
            hint!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          );
    Widget? cta = action == null
        ? null
        : FilledButtonTheme(
            data: FilledButtonThemeData(style: AppButtons.inline),
            child: action!,
          );
    if (!reduced) {
      mark = mark
          .animate()
          .scale(
            begin: const Offset(0.6, 0.6),
            curve: Motion.pop,
            duration: Motion.slow,
          )
          .fadeIn();
      heading = heading
          .animate(delay: 120.ms)
          .fadeIn(duration: Motion.normal)
          .slideY(begin: 0.3, end: 0, curve: Motion.enter);
      if (sub != null) {
        sub = sub
            .animate(delay: 200.ms)
            .fadeIn(duration: Motion.normal)
            .slideY(begin: 0.3, end: 0, curve: Motion.enter);
      }
      if (cta != null) {
        cta = cta.animate(delay: 280.ms).fadeIn(duration: Motion.normal);
      }
    }
    return LayoutBuilder(
      builder: (_, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: c.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                const SizedBox(height: 16),
                heading,
                if (sub != null) ...[const SizedBox(height: 4), sub],
                if (cta != null) ...[const SizedBox(height: 16), cta],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
