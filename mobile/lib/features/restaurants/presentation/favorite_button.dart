import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../data/favorite_repository.dart';
import '../domain/restaurant.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.restaurant,
    this.onPhoto = false,
  });

  final Restaurant restaurant;
  final bool onPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final saved = (ref.watch(favoritesProvider).value ?? const []).any(
      (r) => r.id == restaurant.id,
    );
    final icon = Icon(
      saved ? Icons.favorite : Icons.favorite_border,
      size: onPhoto ? 20 : 24,
      color: saved
          ? const Color(0xFFE8562A)
          : onPhoto
          ? Colors.white
          : null,
    );
    Future<void> tap() async {
      if (saved) {
        Haptics.tap();
      } else {
        Haptics.add();
      }
      try {
        await ref.read(favoritesProvider.notifier).toggle(restaurant);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMessage(e))));
        }
      }
    }

    if (!onPhoto) {
      return IconButton(
        tooltip: saved ? t.removeFavorite : t.addFavorite,
        onPressed: tap,
        icon: icon,
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: tap,
        child: Tooltip(
          message: saved ? t.removeFavorite : t.addFavorite,
          child: AnimatedScale(
            scale: saved ? 1.08 : 1,
            duration: Motion.fast,
            curve: Motion.pop,
            child: Padding(padding: const EdgeInsets.all(8), child: icon),
          ),
        ),
      ),
    );
  }
}
