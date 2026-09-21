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
    return LayoutBuilder(
      builder: (_, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: c.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 40,
                        color: scheme.onPrimaryContainer,
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      curve: Motion.pop,
                      duration: Motion.slow,
                    )
                    .fadeIn(),
                const SizedBox(height: 16),
                Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    .animate(delay: 120.ms)
                    .fadeIn(duration: Motion.normal)
                    .slideY(begin: 0.3, end: 0, curve: Motion.enter),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                        hint!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: Motion.normal)
                      .slideY(begin: 0.3, end: 0, curve: Motion.enter),
                ],
                if (action != null) ...[
                  const SizedBox(height: 16),
                  FilledButtonTheme(
                    data: FilledButtonThemeData(style: AppButtons.inline),
                    child: action!,
                  ).animate(delay: 280.ms).fadeIn(duration: Motion.normal),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
