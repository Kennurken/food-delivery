import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../data/account_repository.dart';
import '../domain/meta.dart';

/// Legal texts are web pages: the browser lets people keep, share or
/// translate them, which an in-app view would not.
Future<void> openExternal(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// E-mail first when there is one: it leaves a written request the platform
/// can act on later; a call is the fallback.
Future<void> contactSupport(Meta meta) async {
  final email = meta.supportEmail;
  final phone = meta.supportPhone;
  if (email != null) {
    await launchUrl(Uri(scheme: 'mailto', path: email));
  } else if (phone != null) {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }
}

/// The platform's e-mail and phone, each one tap from writing or calling.
/// Nothing while they load, or when none are configured.
class SupportContacts extends ConsumerWidget {
  const SupportContacts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaProvider).value;
    final email = meta?.supportEmail;
    final phone = meta?.supportPhone;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (email != null)
          TextButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email)),
            icon: const Icon(Icons.mail_outline),
            label: Text(email),
          ),
        if (phone != null)
          TextButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
            icon: const Icon(Icons.phone_outlined),
            label: Text(phone),
          ),
      ],
    );
  }
}

/// "By creating an account you agree to the Terms of use and the Privacy
/// policy", with both phrases opening the documents once their URLs are known.
class LegalConsent extends ConsumerWidget {
  const LegalConsent({super.key});

  // Stand-ins passed into the translated sentence so it can be cut where the
  // links go. Languages put them in different places (Kazakh ends on the
  // verb, after both), so translators get one whole sentence, not fragments.
  static const _terms = '\u0001';
  static const _privacy = '\u0002';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final meta = ref.watch(metaProvider).value;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final strong = style?.copyWith(fontWeight: FontWeight.w700);

    InlineSpan link(String label, String? url) {
      // Until the URL arrives the phrase is plain text: a link that does
      // nothing when tapped reads as broken.
      if (url == null || url.isEmpty) {
        return TextSpan(text: label, style: strong);
      }
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InkWell(
          onTap: () => openExternal(url),
          borderRadius: BorderRadius.circular(4),
          child: Text(
            label,
            style: strong?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      );
    }

    final sentence = t.agreeToLegal(_terms, _privacy);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp('[$_terms$_privacy]').allMatches(sentence)) {
      if (m.start > last) {
        spans.add(TextSpan(text: sentence.substring(last, m.start)));
      }
      spans.add(
        m[0] == _terms
            ? link(t.agreeTermsLink, meta?.termsUrl)
            : link(t.agreePrivacyLink, meta?.privacyUrl),
      );
      last = m.end;
    }
    if (last < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(last)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.center,
    );
  }
}
