import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/restaurant_repository.dart';
import '../domain/menu_item.dart';

class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(id));
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: restaurant.when(
        loading: () => const _RestaurantSkeleton(),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (r) {
          final byCategory = <String, List<MenuItem>>{};
          for (final m in r.menu) {
            byCategory.putIfAbsent(m.category, () => []).add(m);
          }
          var idx = 0;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: scheme.surface,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 14,
                    end: 16,
                  ),
                  title: Text(
                    r.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 16, color: Colors.black87)],
                    ),
                  ),
                  background: Hero(
                    tag: 'restaurant-$id',
                    child: r.imageUrl == null
                        ? Container(color: scheme.surfaceContainerHighest)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: r.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87,
                                    ],
                                    stops: [0.3, 1],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    Text(r.description, style: text.bodyMedium).stagger(idx++),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _InfoChip(
                          Icons.star_rounded,
                          '${r.rating} (${r.ratingCount})',
                          const Color(0xFFF5A623),
                        ),
                        _InfoChip(
                          Icons.schedule,
                          '${r.deliveryTimeMin} min',
                          scheme.primary,
                        ),
                        _InfoChip(
                          Icons.delivery_dining,
                          formatMoney(r.deliveryFee),
                          scheme.tertiary,
                        ),
                      ],
                    ).stagger(idx++),
                    const SizedBox(height: 20),
                    for (final entry in byCategory.entries) ...[
                      Text(
                        entry.key,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ).stagger(idx++),
                      const SizedBox(height: 10),
                      for (final m in entry.value) _MenuTile(m).stagger(idx++),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: cart.isEmpty || cart.restaurantId != id
            ? const Offset(0, 1.2)
            : Offset.zero,
        duration: Motion.normal,
        curve: Motion.emphasized,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Pressable(
              onTap: () => context.push('/cart'),
              child: FilledButton(
                onPressed: () => context.push('/cart'),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SlidingNumber(
                              '${cart.count}',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('View cart'),
                        ],
                      ),
                      SlidingNumber(
                        formatMoney(cart.subtotal),
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

class _MenuTile extends ConsumerWidget {
  const _MenuTile(this.item);

  final MenuItem item;

  static Future<void> add(
    BuildContext context,
    WidgetRef ref,
    MenuItem item,
  ) async {
    final cart = ref.read(cartProvider.notifier);
    if (cart.add(item)) return;

    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start a new cart?'),
        content: const Text('Your cart has items from another restaurant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace == true) {
      cart.clear();
      cart.add(item);
    }
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Motion.slow,
        curve: Motion.emphasized,
      ),
      builder: (_) => _ItemSheet(item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(
      cartProvider.select((c) => c.items[item.id]?.quantity ?? 0),
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: item.isAvailable ? () => _openSheet(context) : null,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.isAvailable ? null : scheme.outline,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        item.isAvailable
                            ? formatMoney(item.price)
                            : 'Unavailable',
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                QuantityStepper(
                  qty: qty,
                  enabled: item.isAvailable,
                  onAdd: () => add(context, ref, item),
                  onRemove: () => ref.read(cartProvider.notifier).remove(item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "+" morphs into "− n +" (jitter "View Cart Button: Split").
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = qty > 0;
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      height: 40,
      decoration: BoxDecoration(
        color: expanded ? scheme.primary : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.emphasized,
            child: expanded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepBtn(Icons.remove, onRemove, scheme.onPrimary),
                      SizedBox(
                        width: 24,
                        child: Center(
                          child: SlidingNumber(
                            '$qty',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          _StepBtn(
            Icons.add,
            enabled ? onAdd : null,
            expanded ? scheme.onPrimary : scheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(this.icon, this.onTap, this.color);

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Pressable(
    scale: 0.85,
    onTap: onTap,
    child: SizedBox(
      width: 40,
      height: 40,
      child: Icon(
        icon,
        size: 20,
        color: onTap == null ? color.withValues(alpha: 0.4) : color,
      ),
    ),
  );
}

/// animate-ui Sheet: item detail with big price and stepper.
class _ItemSheet extends ConsumerWidget {
  const _ItemSheet(this.item);

  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(
      cartProvider.select((c) => c.items[item.id]?.quantity ?? 0),
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.category.toUpperCase(),
            style: text.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SlidingNumber(
                formatMoney(item.price * (qty == 0 ? 1 : qty)),
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              QuantityStepper(
                qty: qty,
                onAdd: () => _MenuTile.add(context, ref, item),
                onRemove: () => ref.read(cartProvider.notifier).remove(item),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (qty == 0) _MenuTile.add(context, ref, item);
              Navigator.pop(context);
            },
            child: Text(qty == 0 ? 'Add to cart' : 'Done'),
          ),
        ],
      ),
    );
  }
}

class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Column(
      children: [
        const AspectRatio(aspectRatio: 16 / 9, child: Bone(radius: 0)),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone(width: 220, height: 22),
              SizedBox(height: 10),
              Bone(width: 160, height: 14),
            ],
          ),
        ),
        const Expanded(child: ListSkeleton(count: 3)),
      ],
    ),
  );
}
