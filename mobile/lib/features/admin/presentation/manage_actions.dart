import 'package:flutter/material.dart';

import '../../../core/widgets/anim_icon.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';

/// The venue's tools, as a row of cards instead of six icons crammed into an
/// app bar.
///
/// Six unlabelled actions in a phone app bar overflow, and the ones that
/// survive are guessed at from a glyph. Cards carry the word as well as the
/// icon, scroll instead of overflowing, and give the icons room enough to be
/// read at a glance.
class ManageAction {
  const ManageAction({
    required this.shape,
    required this.label,
    required this.onTap,
  });

  final AnimShape shape;
  final String label;
  final VoidCallback onTap;
}

class ManageActions extends StatelessWidget {
  const ManageActions({super.key, required this.actions});

  final List<ManageAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final action = actions[i];
          return Pressable(
            onTap: action.onTap,
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimIcon(action.shape, size: 30, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
                  ),
                ],
              ),
            ),
          ).stagger(i);
        },
      ),
    );
  }
}
