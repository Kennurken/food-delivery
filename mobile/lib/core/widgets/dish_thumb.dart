import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Square dish photo with a warm fallback — the food is the hero, not an icon.
class DishThumb extends StatelessWidget {
  const DishThumb({
    super.key,
    required this.url,
    this.size = 72,
    this.radius = 16,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? ColoredBox(
                color: scheme.primaryContainer,
                child: Icon(
                  Icons.ramen_dining_outlined,
                  color: scheme.onPrimaryContainer,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
                errorWidget: (_, _, _) => ColoredBox(
                  color: scheme.primaryContainer,
                  child: Icon(
                    Icons.ramen_dining_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }
}
