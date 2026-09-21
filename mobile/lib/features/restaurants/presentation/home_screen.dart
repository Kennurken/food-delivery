import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/restaurant_repository.dart';
import '../domain/restaurant.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _searching = false;
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(restaurantSearchProvider.notifier).set(v);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final t = context.l10n;
    if (h < 5) return t.greetingNight;
    if (h < 12) return t.greetingMorning;
    if (h < 17) return t.greetingAfternoon;
    return t.greetingEvening;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _focus.requestFocus();
    } else {
      _search.clear();
      ref.read(restaurantSearchProvider.notifier).set('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsProvider);
    final user = ref.watch(authControllerProvider).value;
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(
        // jitter "Search Bar Reveal": title morphs into a search field.
        title: AnimatedSwitcher(
          duration: Motion.normal,
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(
              sizeFactor: anim,
              axis: Axis.horizontal,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
          child: _searching
              ? TextField(
                  key: const ValueKey('search'),
                  controller: _search,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    hintText: t.searchRestaurants,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: _onQuery,
                )
              : Column(
                  key: const ValueKey('title'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text('${user?.name.split(' ').first ?? ''} 👋'),
                  ],
                ),
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, a) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Icon(
                _searching ? Icons.close : Icons.search,
                key: ValueKey(_searching),
              ),
            ),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: t.orders,
            onPressed: () => context.push('/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: t.profile,
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: const _CartFab(),
      body: Column(
        children: [
          const _CuisineChips(),
          Expanded(
            child: restaurants.when(
              loading: () => const _Skeleton(),
              error: (e, _) => _ErrorView(
                message: errorMessage(e),
                onRetry: () => ref.invalidate(restaurantsProvider),
              ),
              data: (list) => list.isEmpty
                  ? Center(child: Text(t.nothingFound))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(restaurantsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) =>
                            _RestaurantCard(list[i]).stagger(i),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// jitter "View Cart Button": hidden → pops in, count rolls as items are added.
class _CartFab extends ConsumerWidget {
  const _CartFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: cart.isEmpty ? 0 : 1,
      duration: Motion.normal,
      curve: cart.isEmpty ? Motion.exit : Motion.pop,
      child: Pressable(
        onTap: () => context.push('/cart'),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, color: scheme.onPrimary),
              const SizedBox(width: 10),
              DefaultTextStyle(
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                child: Row(
                  children: [
                    SlidingNumber('${cart.count}'),
                    const Text(' · '),
                    SlidingNumber(formatMoney(cart.subtotal)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuisineChips extends ConsumerWidget {
  const _CuisineChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuisines = ref.watch(cuisinesProvider).value ?? const [];
    final selected = ref.watch(cuisineFilterProvider);
    if (cuisines.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: cuisines.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = i == 0 ? context.l10n.all : cuisines[i - 1];
          final isSel = i == 0 ? selected == null : cuisines[i - 1] == selected;
          return FilterChip(
            label: Text(label),
            selected: isSel,
            showCheckmark: false,
            onSelected: (_) => i == 0
                ? ref.read(cuisineFilterProvider.notifier).clear()
                : ref
                      .read(cuisineFilterProvider.notifier)
                      .toggle(cuisines[i - 1]),
          ).stagger(i, slide: 0);
        },
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard(this.r);

  final Restaurant r;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => context.push('/restaurants/${r.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'restaurant-${r.id}',
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: r.imageUrl == null
                        ? Container(
                            color: scheme.surfaceContainerHighest,
                            child: const Icon(Icons.restaurant, size: 48),
                          )
                        : CachedNetworkImage(
                            imageUrl: r.imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: Motion.normal,
                            placeholder: (_, _) => Shimmer(
                              child: Container(
                                color: scheme.surfaceContainerHighest,
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Pill(
                    icon: Icons.schedule,
                    label: context.l10n.minutes(r.deliveryTimeMin),
                  ),
                ),
                if (!r.isOpen)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Pill(
                      icon: Icons.storefront,
                      label: context.l10n.closed,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFF5A623),
                      ),
                      const SizedBox(width: 2),
                      Text(r.rating.toStringAsFixed(1), style: text.labelLarge),
                      Text(
                        ' (${r.ratingCount})',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.cuisine} · ${context.l10n.deliveryFee(formatMoney(r.deliveryFee))}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => const Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: Bone(radius: 0)),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 160, height: 16),
                  SizedBox(height: 8),
                  Bone(width: 220, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}
