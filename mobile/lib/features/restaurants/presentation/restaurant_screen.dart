import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/dish_thumb.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../map/presentation/restaurant_map_preview.dart';
import '../data/restaurant_repository.dart';
import '../domain/menu_item.dart';
import 'favorite_button.dart';

class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({
    super.key,
    required this.id,
    this.tableToken,
    this.tableLabel,
  });

  final int id;
  final String? tableToken;
  final String? tableLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(id));
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final t = context.l10n;

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
                actions: [FavoriteButton(restaurant: r)],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 14,
                    end: 56,
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
                                placeholder: (_, _) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                ),
                                errorWidget: (_, _, _) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 64,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
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
                    if (!r.isOpen) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.restaurantClosed,
                                  style: text.bodyMedium?.copyWith(
                                    color: scheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).stagger(idx++),
                    ],
                    const SizedBox(height: 8),
                    if (tableLabel != null) ...[
                      Material(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.table_bar_outlined,
                                color: scheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.atTable(tableLabel!),
                                  style: text.bodyMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).stagger(idx++),
                      const SizedBox(height: 12),
                    ],
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
                          t.minutes(r.deliveryTimeMin),
                          scheme.primary,
                        ),
                        _InfoChip(
                          Icons.delivery_dining,
                          formatMoney(r.deliveryFee),
                          scheme.tertiary,
                        ),
                      ],
                    ).stagger(idx++),
                    if (r.allowsReservations) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/restaurants/${r.id}/book'),
                        icon: const Icon(Icons.event_seat_outlined),
                        label: Text(t.bookTable),
                      ).stagger(idx++),
                    ],
                    if (r.hasPin) ...[
                      const SizedBox(height: 16),
                      RestaurantMapPreview(
                        lat: r.lat!,
                        lng: r.lng!,
                      ).stagger(idx++),
                    ],
                    const SizedBox(height: 20),
                    for (final entry in byCategory.entries) ...[
                      Text(
                        entry.key,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ).stagger(idx++),
                      const SizedBox(height: 10),
                      for (final m in entry.value)
                        _MenuTile(
                          m,
                          restaurantOpen: r.isOpen,
                          tableToken: tableToken,
                        ).stagger(idx++),
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
                          Text(t.viewCart),
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
  const _MenuTile(this.item, {this.restaurantOpen = true, this.tableToken});

  final MenuItem item;
  final bool restaurantOpen;
  final String? tableToken;

  static Future<void> add(
    BuildContext context,
    WidgetRef ref,
    MenuItem item, {
    String? tableToken,
    List<int>? optionIds,
  }) async {
    final cart = ref.read(cartProvider.notifier);
    if (cart.add(item, optionIds: optionIds)) {
      if (tableToken != null) cart.setQrToken(tableToken);
      return;
    }

    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.newCartTitle),
        content: Text(context.l10n.newCartBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.replace),
          ),
        ],
      ),
    );
    if (replace == true) {
      cart.clear();
      cart.add(item, optionIds: optionIds);
      if (tableToken != null) cart.setQrToken(tableToken);
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
      builder: (_) => _ItemSheet(item, tableToken: tableToken),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdd = item.isAvailable && restaurantOpen;
    final qty = ref.watch(cartProvider.select((c) => c.quantityOf(item.id)));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: canAdd ? () => _openSheet(context) : null,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                DishThumb(url: item.imageUrl, size: 76, radius: 16),
                const SizedBox(width: 12),
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
                        item.isAvailable && restaurantOpen
                            ? (item.hasPricedOptions
                                  ? context.l10n.fromPrice(
                                      formatMoney(item.price),
                                    )
                                  : formatMoney(item.price))
                            : context.l10n.unavailable,
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
                  enabled: canAdd,
                  onAdd: () {
                    if (item.needsPicker) {
                      _openSheet(context);
                      return;
                    }
                    add(context, ref, item, tableToken: tableToken);
                  },
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

/// animate-ui Sheet: item detail, modifiers, price, stepper.
class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet(this.item, {this.tableToken});

  final MenuItem item;
  final String? tableToken;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late Set<int> _picked;

  MenuItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _picked = item.defaultOptionIds.toSet();
  }

  bool get _valid => item.accepts(_picked);

  double get _unit => item.priceWith(_picked);

  void _toggle(ModifierGroup group, ModifierOption option) {
    if (!option.isAvailable) return;
    setState(() {
      final selected = [
        for (final o in group.options)
          if (_picked.contains(o.id)) o.id,
      ];
      if (_picked.contains(option.id)) {
        if (group.required && selected.length <= group.need) return;
        _picked.remove(option.id);
        return;
      }
      if (group.maxSelect == 1) {
        for (final o in group.options) {
          _picked.remove(o.id);
        }
        _picked.add(option.id);
        return;
      }
      if (selected.length >= group.maxSelect) return;
      _picked.add(option.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = _picked.toList();
    final qty = ref.watch(
      cartProvider.select(
        (c) => c.items[CartItem.lineKey(item.id, ids)]?.quantity ?? 0,
      ),
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
              Center(
                child: DishThumb(url: item.imageUrl, size: 168, radius: 24),
              ),
              const SizedBox(height: 16),
            ],
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
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final group in item.groups) ...[
              const SizedBox(height: 18),
              Text(
                group.required ? '${group.name} · ${t.required}' : group.name,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in group.options)
                    FilterChip(
                      label: Text(
                        o.priceDelta == 0
                            ? o.name
                            : '${o.name} · +${formatMoney(o.priceDelta)}',
                      ),
                      selected: _picked.contains(o.id),
                      onSelected: o.isAvailable
                          ? (_) => _toggle(group, o)
                          : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SlidingNumber(
                  formatMoney(_unit * (qty == 0 ? 1 : qty)),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                QuantityStepper(
                  qty: qty,
                  enabled: _valid,
                  onAdd: () => _MenuTile.add(
                    context,
                    ref,
                    item,
                    tableToken: widget.tableToken,
                    optionIds: ids,
                  ),
                  onRemove: () => ref
                      .read(cartProvider.notifier)
                      .remove(item, optionIds: ids),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !_valid
                  ? null
                  : () {
                      if (qty == 0) {
                        _MenuTile.add(
                          context,
                          ref,
                          item,
                          tableToken: widget.tableToken,
                          optionIds: ids,
                        );
                      }
                      Navigator.pop(context);
                    },
              child: Text(qty == 0 ? t.addToCart : t.done),
            ),
          ],
        ),
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
