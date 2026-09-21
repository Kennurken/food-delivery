import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    final u = ref.read(authControllerProvider).value;
    _name = TextEditingController(text: u?.name);
    _phone = TextEditingController(text: u?.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(name: _name.text.trim(), phone: _phone.text.trim());
      await ref.read(authControllerProvider.notifier).refresh();
      if (mounted) _toast('Saved');
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  Future<void> _addAddress() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
    if (result == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .addAddress(result.$1, result.$2);
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Addresses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          addresses.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No saved addresses'),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              a.isDefault ? Icons.home : Icons.place_outlined,
                            ),
                            title: Text(a.label),
                            subtitle: Text(a.line),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(profileRepositoryProvider)
                                      .deleteAddress(a.id);
                                  ref.invalidate(addressesProvider);
                                } catch (e) {
                                  if (context.mounted) _toast(errorMessage(e));
                                }
                              },
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

class _AddressDialog extends StatefulWidget {
  const _AddressDialog();

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _label = TextEditingController(text: 'Home');
  final _line = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _line,
            decoration: const InputDecoration(
              labelText: 'Street, building, apt',
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_line.text.trim().length < 3) return;
            Navigator.pop(context, (_label.text.trim(), _line.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
