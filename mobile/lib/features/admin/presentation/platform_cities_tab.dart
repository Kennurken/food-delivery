import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/cities_admin_repository.dart';
import '../domain/admin_city.dart';

/// Every city the service runs in, switched-off ones included — the admin has
/// to find a city to switch it back on.
class PlatformCitiesTab extends ConsumerWidget {
  const PlatformCitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final cities = ref.watch(adminCitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-city',
        onPressed: () => _editCity(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(t.addCity),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminCitiesProvider.future),
        child: cities.when(
          loading: () => const ListSkeleton(rowHeight: 72),
          error: (e, _) => EmptyState(
            icon: Icons.wifi_off,
            title: t.couldNotLoad,
            hint: errorMessage(e),
          ),
          data: (list) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            itemBuilder: (_, i) => _CityTile(list[i]),
          ),
        ),
      ),
    );
  }
}

class _CityTile extends ConsumerWidget {
  const _CityTile(this.city);

  final AdminCity city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = [
      '/${city.slug}/',
      '${city.venues}',
      if (city.nameIn != null && city.nameIn!.isNotEmpty) 'в ${city.nameIn}',
    ].join(' · ');
    return Card(
      child: ListTile(
        title: Text(city.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _editCity(context, ref, city: city),
        trailing: Switch(
          value: city.isActive,
          onChanged: (on) => _run(
            context,
            ref,
            () => ref.read(citiesAdminRepositoryProvider).update(city.id, {
              'is_active': on,
            }),
          ),
        ),
      ),
    );
  }
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
    ref.invalidate(adminCitiesProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }
}

Future<void> _editCity(BuildContext context, WidgetRef ref, {AdminCity? city}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CityForm(city: city),
  );
}

class _CityForm extends ConsumerStatefulWidget {
  const _CityForm({this.city});

  /// Null when adding a city.
  final AdminCity? city;

  @override
  ConsumerState<_CityForm> createState() => _CityFormState();
}

class _CityFormState extends ConsumerState<_CityForm> {
  late final _name = TextEditingController(text: widget.city?.name ?? '');
  late final _nameIn = TextEditingController(text: widget.city?.nameIn ?? '');
  final _slug = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nameIn.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(citiesAdminRepositoryProvider);
    final name = _name.text.trim();
    final nameIn = _nameIn.text.trim();
    setState(() => _busy = true);
    try {
      final city = widget.city;
      if (city == null) {
        await repo.create(
          slug: _slug.text.trim().toLowerCase(),
          name: name,
          nameIn: nameIn.isEmpty ? null : nameIn,
        );
      } else {
        await repo.update(city.id, {
          'name': name,
          'name_in': nameIn.isEmpty ? null : nameIn,
        });
      }
      ref.invalidate(adminCitiesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // The sheet stays open: a taken or reserved address is fixed right here.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final adding = widget.city == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: t.cityName),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameIn,
              decoration: InputDecoration(labelText: t.cityNameIn),
            ),
            if (adding) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _slug,
                decoration: InputDecoration(
                  labelText: t.citySlug,
                  prefixText: '/',
                  suffixText: '/',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
          ],
        ),
      ),
    );
  }
}
