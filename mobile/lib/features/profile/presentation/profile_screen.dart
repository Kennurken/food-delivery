import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authControllerProvider).value;
    _name = TextEditingController(text: u?.name)..addListener(_markDirty);
    _phone = TextEditingController(text: u?.phone)..addListener(_markDirty);
  }

  void _markDirty() {
    final u = ref.read(authControllerProvider).value;
    final d = _name.text != (u?.name ?? '') || _phone.text != (u?.phone ?? '');
    if (d != _dirty) setState(() => _dirty = d);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(name: _name.text.trim(), phone: _phone.text.trim());
      await ref.read(authControllerProvider.notifier).refresh();
      Haptics.success();
      if (mounted) {
        setState(() => _dirty = false);
        _toast('Saved');
      }
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  Future<void> _addAddress() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddressSheet(),
    );
    if (result == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .addAddress(result.$1, result.$2);
      Haptics.add();
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final user = ref.watch(authControllerProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initials = (user?.name ?? '?')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  initials,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).stagger(0),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ).stagger(1),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ).stagger(2),
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: _dirty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Pressable(
                      onTap: _save,
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save changes'),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Addresses',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ).stagger(3),
          addresses.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => list.isEmpty
                ? SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: Icons.place_outlined,
                      title: 'No saved addresses',
                      hint: 'Add one to check out in a tap',
                    ),
                  )
                : Column(
                    children: [
                      for (final (i, a) in list.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey(a.id),
                            direction: DismissDirection.endToStart,
                            background: _DeleteBg(),
                            onDismissed: (_) async {
                              Haptics.warn();
                              try {
                                await ref
                                    .read(profileRepositoryProvider)
                                    .deleteAddress(a.id);
                              } catch (e) {
                                if (context.mounted) _toast(errorMessage(e));
                              }
                              ref.invalidate(addressesProvider);
                            },
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: a.isDefault
                                      ? scheme.primary
                                      : scheme.surfaceContainerHighest,
                                  child: Icon(
                                    a.isDefault
                                        ? Icons.home
                                        : Icons.place_outlined,
                                    color: a.isDefault
                                        ? scheme.onPrimary
                                        : scheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  a.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(a.line),
                                trailing: a.isDefault
                                    ? Text(
                                        'Default',
                                        style: text.labelSmall?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ).stagger(4 + i),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Swipe left to delete',
                          style: text.labelSmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.error,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Icon(
      Icons.delete_outline,
      color: Theme.of(context).colorScheme.onError,
    ),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet();

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _label = TextEditingController(text: 'Home');
  final _line = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    super.dispose();
  }

  void _save() {
    if (_line.text.trim().length < 3) return;
    Navigator.pop(context, (_label.text.trim(), _line.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New address',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final l in const ['Home', 'Work', 'Other'])
                ChoiceChip(
                  label: Text(l),
                  selected: _label.text == l,
                  onSelected: (_) => setState(() => _label.text = l),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _line,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Street, building, apt',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save address')),
        ],
      ),
    );
  }
}
