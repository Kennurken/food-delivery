import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/motion.dart';
import 'pressable.dart';

/// Sliding-pill tab bar for the customer shell.
/// animate-ui Tabs (spring 300/32) + jitter "Navigation Bar".
class SlidingBottomNav extends StatelessWidget {
  const SlidingBottomNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.reduced(context);
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, t.navHome),
      (Icons.receipt_long_outlined, Icons.receipt_long, t.orders),
      (Icons.person_outline, Icons.person, t.profile),
    ];

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: SizedBox(
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final slot = c.maxWidth / items.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: reduced ? Duration.zero : Motion.normal,
                        curve: Motion.emphasized,
                        left: index * slot + 4,
                        top: 4,
                        width: slot - 8,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: Pressable(
                                onTap: () => onTap(i),
                                child: SizedBox(
                                  height: 58,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        i == index ? items[i].$2 : items[i].$1,
                                        color: i == index
                                            ? scheme.onPrimary
                                            : scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        items[i].$3,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: i == index
                                                  ? scheme.onPrimary
                                                  : scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
