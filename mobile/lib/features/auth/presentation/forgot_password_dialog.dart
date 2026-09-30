import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../profile/presentation/legal_links.dart';

/// There is no reset e-mail yet. Say so plainly and point to who can help,
/// rather than a form that would accept an address and send nothing.
class ForgotPasswordDialog extends StatelessWidget {
  const ForgotPasswordDialog({super.key});

  /// Opens the dialog; if the reader picks "Create account", goes there
  /// from the screen underneath once the dialog is gone.
  static Future<void> show(BuildContext context) async {
    final register = await showDialog<bool>(
      context: context,
      builder: (_) => const ForgotPasswordDialog(),
    );
    if (register == true && context.mounted) context.push('/register');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.forgotPassword),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.forgotPasswordBody),
          const SizedBox(height: 12),
          Text(t.forgotPasswordStaff),
          const SizedBox(height: 4),
          const SupportContacts(),
          const SizedBox(height: 8),
          Text(t.forgotPasswordGuests),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t.createAccount),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.close),
        ),
      ],
    );
  }
}
