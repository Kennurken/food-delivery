import '../../loyalty/data/loyalty_repository.dart';
import '../../../core/utils/money.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../map/domain/place.dart';
import '../data/account_repository.dart';
import '../data/profile_repository.dart';
import '../domain/address.dart';
import 'legal_links.dart';

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
        _toast(context.l10n.saved);
      }
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  Future<void> _changePassword() async {
    // Profile is a tab: on the shell's navigator a sheet opens underneath the
    // bottom bar, which covers its buttons. Same for the address sheet below.
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (ok == true && mounted) {
      Haptics.success();
      _toast(context.l10n.passwordChanged);
    }
  }

  Future<void> _deleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !mounted) return;
    // Taken before logging out: that rebuilds the router and this screen goes
    // away with its context.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final done = context.l10n.accountDeleted;
    Haptics.warn();
    await ref.read(authControllerProvider.notifier).logout();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    // Straight to /login: the redirect alone would add ?next=/profile, and the
    // next person to sign in on this phone has no business landing there.
    router.go('/login');
  }

  /// Drop a point onto an address that was saved as text only.
  Future<void> _pinAddress(Address a) async {
    final q = <String, String>{if (a.line.isNotEmpty) 'line': a.line};
    final uri = Uri(path: '/map/pick', queryParameters: q.isEmpty ? null : q);
    final place = await context.push<MapPlace>(uri.toString());
    if (place == null || !mounted) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .setPoint(a.id, lat: place.lat, lng: place.lng, line: place.line);
      Haptics.success();
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (mounted) _toast(errorMessage(e));
    }
  }

  Future<void> _addAddress() async {
    final result = await showModalBottomSheet<AddressDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _AddressSheet(),
    );
    if (result == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .addAddress(
            result.label,
            result.line,
            apt: result.apt,
            entrance: result.entrance,
            floor: result.floor,
            intercom: result.intercom,
            lat: result.lat,
            lng: result.lng,
          );
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
    // A table guest has no password to change and nothing worth deleting —
    // the session is thrown away with the visit.
    final isGuest = user?.isGuest ?? false;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = context.l10n;
    final initials = (user?.name ?? '?')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.logOut,
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
            decoration: InputDecoration(
              labelText: t.name,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ).stagger(1),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: t.phone,
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
                        child: Text(t.saveChanges),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(t.reservations),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/reservations'),
            ),
          ).stagger(3),
          const _BonusesCard(),
          const SizedBox(height: 28),
          Text(
            t.language,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ).stagger(3),
          const SizedBox(height: 8),
          const _LanguagePicker(),
          if (!isGuest) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(t.changePassword),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePassword,
              ),
            ).stagger(3),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.addresses,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add),
                label: Text(t.add),
              ),
            ],
          ).stagger(4),
          addresses.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => list.isEmpty
                ? SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: Icons.place_outlined,
                      title: t.noSavedAddresses,
                      hint: t.noSavedAddressesHint,
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.display(t)),
                                    // Without a point the courier gets text and
                                    // delivery is priced off a guess, so say so
                                    // and offer the one tap that fixes it.
                                    if (!a.hasPin)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: InkWell(
                                          onTap: () => _pinAddress(a),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.wrong_location_outlined,
                                                size: 14,
                                                color: scheme.error,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                t.addressNeedsPin,
                                                style: text.labelSmall
                                                    ?.copyWith(
                                                      color: scheme.error,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: !a.hasPin,
                                trailing: a.isDefault
                                    ? Text(
                                        t.default_,
                                        style: text.labelSmall?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(profileRepositoryProvider)
                                                .setDefault(a.id);
                                            ref.invalidate(addressesProvider);
                                          } catch (e) {
                                            if (context.mounted) {
                                              _toast(errorMessage(e));
                                            }
                                          }
                                        },
                                        child: Text(t.setAsDefault),
                                      ),
                              ),
                            ),
                          ),
                        ).stagger(4 + i),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t.swipeToDelete,
                          style: text.labelSmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          if (!isGuest && !(user?.isAdmin ?? false)) const _MyVenuesCard(),
          const _LegalCard(),
          if (!isGuest) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(t.deleteAccount),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The venues this person runs or works at, each opening its panel. Hidden
/// for everyone else: most people using the app are only ordering food.
class _MyVenuesCard extends ConsumerWidget {
  const _MyVenuesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(myVenuesProvider).value ?? const [];
    if (venues.isEmpty) return const SizedBox.shrink();
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                t.myVenues,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final v in venues)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(v.name),
                subtitle: Text(staffRoleLabel(t, v.role)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/admin/restaurants/${v.restaurantId}'),
              ),
          ],
        ),
      ),
    );
  }
}

String staffRoleLabel(L10n t, String role) => switch (role) {
  'owner' => t.roleOwner,
  'admin' || 'manager' || 'delivery_manager' => t.roleManager,
  'delivery_courier' => t.roleCourier,
  _ => t.roleStaff,
};

/// Privacy policy, terms and support. Everyone sees these, table guests
/// included: reading the rules takes no account.
class _LegalCard extends ConsumerWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final meta = ref.watch(metaProvider).value;
    final contacts = [meta?.supportEmail, meta?.supportPhone].nonNulls;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.privacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 18),
            // Greyed out until the URL is known rather than a dead tap.
            enabled: meta != null,
            onTap: meta == null ? null : () => openExternal(meta.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(t.termsOfUse),
            trailing: const Icon(Icons.open_in_new, size: 18),
            enabled: meta != null,
            onTap: meta == null ? null : () => openExternal(meta.termsUrl),
          ),
          if (meta != null && meta.hasSupport)
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: Text(t.support),
              subtitle: Text(contacts.join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => contactSupport(meta),
            ),
        ],
      ),
    );
  }
}

/// Asks for the password, not only a tap: deletion is final, and a phone
/// left unlocked on a table should not be enough to do it.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // A 409 says in words why not (a venue they own, an order on its way),
      // which is exactly what they need to read, so it is shown as sent.
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t.deleteAccount),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.deleteAccountBody),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _delete(),
            decoration: InputDecoration(
              labelText: t.passwordToConfirm,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(t.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _busy || _password.text.isEmpty ? null : _delete,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.delete),
        ),
      ],
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(localeControllerProvider).value;
    final t = context.l10n;
    final options = <(Locale?, String)>[
      (null, t.languageSystem),
      (const Locale('en'), t.languageEnglish),
      (const Locale('ru'), t.languageRussian),
      (const Locale('kk'), t.languageKazakh),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (locale, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected?.languageCode == locale?.languageCode,
            onSelected: (_) =>
                ref.read(localeControllerProvider.notifier).setLocale(locale),
          ),
      ],
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

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = context.l10n;
    // Same floor as the server, so the rule is learnt here, not from a 422.
    if (_next.text.length < 8) {
      setState(() => _error = t.minChars(8));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = t.passwordsDoNotMatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(current: _current.text, next: _next.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
            t.changePassword,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t.currentPassword,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t.newPassword,
              prefixIcon: const Icon(Icons.lock_reset),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_busy) _save();
            },
            decoration: InputDecoration(
              labelText: t.confirmPassword,
              prefixIcon: const Icon(Icons.lock_reset),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
          ),
        ],
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet();

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _label = TextEditingController(text: context.l10n.labelHome);
  final _line = TextEditingController();
  final _apt = TextEditingController();
  final _entrance = TextEditingController();
  final _floor = TextEditingController();
  final _intercom = TextEditingController();
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    for (final c in [_label, _line, _apt, _entrance, _floor, _intercom]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _blank(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _save() {
    if (_line.text.trim().length < 3) return;
    Navigator.pop(
      context,
      AddressDraft(
        label: _label.text.trim(),
        line: _line.text.trim(),
        apt: _blank(_apt.text),
        entrance: _blank(_entrance.text),
        floor: _blank(_floor.text),
        intercom: _blank(_intercom.text),
        lat: _lat,
        lng: _lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.newAddress,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final l in [t.labelHome, t.labelWork, t.labelOther])
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.addressLine,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final q = <String, String>{
                  if (_lat != null) 'lat': '$_lat',
                  if (_lng != null) 'lng': '$_lng',
                  if (_line.text.trim().isNotEmpty) 'line': _line.text.trim(),
                };
                final uri = Uri(
                  path: '/map/pick',
                  queryParameters: q.isEmpty ? null : q,
                );
                final place = await context.push<MapPlace>(uri.toString());
                if (place == null || !mounted) return;
                setState(() {
                  _line.text = place.line;
                  _lat = place.lat;
                  _lng = place.lng;
                });
              },
              icon: const Icon(Icons.map_outlined),
              label: Text(t.pickAddress),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apt,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.apt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _entrance,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.entrance),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _floor,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.floor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _intercom,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(labelText: t.intercom),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(t.saveAddress)),
          ],
        ),
      ),
    );
  }
}

/// Bonuses held at each venue. Nothing at all when there are none, or when
/// they can't be loaded: it is a nicety, not something to show an error for.
class _BonusesCard extends ConsumerWidget {
  const _BonusesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(myBonusesProvider).value;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: Text(t.myBonuses),
            ),
            for (final row in rows)
              ListTile(
                dense: true,
                title: Text(
                  row.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${formatMoney(row.balance)} ₸',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
