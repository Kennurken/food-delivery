import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/applications_repository.dart';
import '../domain/application.dart';

/// Restaurants that applied through the site, oldest first. Approving opens the
/// venue to guests; rejecting keeps it hidden and can say why.
class PlatformApplicationsTab extends ConsumerWidget {
  const PlatformApplicationsTab({super.key});

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    Application a, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _ReasonDialog(),
      );
      // Cancelled: nothing is decided.
      if (reason == null) return;
    }
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .decide(a.restaurantId, approve: approve, reason: reason);
      Haptics.success();
      ref.invalidate(pendingApplicationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final rows = ref.watch(pendingApplicationsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(pendingApplicationsProvider.future),
      child: rows.when(
        loading: () => const ListSkeleton(rowHeight: 120),
        error: (e, _) => EmptyState(
          icon: Icons.wifi_off,
          title: t.couldNotLoad,
          hint: errorMessage(e),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.inbox_outlined, title: t.noApplications)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _ApplicationCard(
                  a: list[i],
                  onApprove: () =>
                      _decide(context, ref, list[i], approve: true),
                  onReject: () =>
                      _decide(context, ref, list[i], approve: false),
                ),
              ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.a,
    required this.onApprove,
    required this.onReject,
  });

  final Application a;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final contact = [
      if (a.ownerName != null) a.ownerName!,
      if (a.ownerPhone != null) a.ownerPhone!,
      if (a.ownerEmail != null) a.ownerEmail!,
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.name,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              [a.cuisine, if (a.city != null) a.city!].join(' · '),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (a.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(a.description, style: text.bodyMedium),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  a.hasCouriers ? Icons.two_wheeler : Icons.directions_walk,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.hasCouriers ? t.ownCouriers : t.noCouriersPickupOnly,
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(contact, style: text.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: onApprove, child: Text(t.approve)),
                OutlinedButton(onPressed: onReject, child: Text(t.reject)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.reject),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 300,
        decoration: InputDecoration(hintText: t.rejectReason),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(t.reject),
        ),
      ],
    );
  }
}
