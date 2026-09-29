import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../data/city_choice.dart';
import '../data/restaurant_repository.dart';

/// Asks which city to browse. The choice is remembered (see [CityChoice]).
Future<void> pickCity(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Home lives inside the tab shell; on the shell's own navigator the sheet
    // opens underneath the bottom bar, which hides every city but the first.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CityPickerSheet(),
  );
}

/// Every live city, plus "all cities" — the app's behaviour before cities.
class CityPickerSheet extends ConsumerWidget {
  const CityPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesProvider);
    final choice = ref.watch(cityChoiceProvider);
    final t = context.l10n;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.chooseCity,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Flexible(
            child: citiesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(errorMessage(e)),
              ),
              data: (cities) => ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: cities.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final slug = i == 0 ? null : cities[i - 1].slug;
                  final name = i == 0 ? t.allCities : cities[i - 1].name;
                  final isSelected = choice == slug;
                  return ListTile(
                    dense: true,
                    title: Text(name),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      ref.read(cityChoiceProvider.notifier).set(slug);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current city, small enough to sit beside the diner's name in the
/// home app bar; tapping it opens the picker.
class CityButton extends ConsumerWidget {
  const CityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(cityChoiceProvider);
    // A choice the list doesn't know (not loaded yet, or switched off) reads
    // as every city — which is also what the restaurant list falls back to.
    final label =
        ref
            .watch(citiesProvider)
            .value
            ?.where((c) => c.slug == choice)
            .firstOrNull
            ?.name ??
        context.l10n.allCities;

    return TextButton.icon(
      onPressed: () => pickCity(context),
      // A chevron after the name, the way a dropdown reads.
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.expand_more, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
