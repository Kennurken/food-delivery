import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/domain/review.dart';
import '../data/reviews_admin_repository.dart';

/// What diners wrote about this venue, with a way to answer each.
///
/// The answer is public, under the review, so it is one short text and can be
/// replaced by answering again. Removing a review is the platform's job, not
/// the venue's, so there is no delete here.
Future<void> editReviews(
  BuildContext context,
  WidgetRef ref,
  int restaurantId,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReviewsSheet(restaurantId: restaurantId),
  );
}

final _adminReviewsProvider = FutureProvider.autoDispose
    .family<List<Review>, int>(
      (ref, id) =>
          ref.watch(restaurantRepositoryProvider).reviews(id, limit: 30),
    );

class ReviewsSheet extends ConsumerWidget {
  const ReviewsSheet({super.key, required this.restaurantId});

  final int restaurantId;

  Future<void> _answer(BuildContext context, WidgetRef ref, Review r) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(initial: r.reply ?? ''),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref.read(reviewsAdminRepositoryProvider).reply(r.orderId, text);
      Haptics.success();
      ref.invalidate(_adminReviewsProvider(restaurantId));
      ref.invalidate(restaurantReviewsProvider(restaurantId));
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
    final rows = ref.watch(_adminReviewsProvider(restaurantId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.reviews,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              rows.when(
                loading: () => const SizedBox(
                  height: 220,
                  child: ListSkeleton(count: 3, rowHeight: 72),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(errorMessage(e)),
                ),
                data: (list) => list.isEmpty
                    ? SizedBox(
                        height: 220,
                        child: EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: t.noReviewsYet,
                        ),
                      )
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => _ReviewTile(
                            review: list[i],
                            onReply: () => _answer(context, ref, list[i]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.onReply});

  final Review review;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  review.author.isEmpty ? t.reviewGuest : review.author,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '★' * review.rating,
                style: TextStyle(color: scheme.tertiary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(review.text, style: text.bodyMedium),
          if (review.reply != null && review.reply!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 10),
              child: Text(
                '${t.venueReply}: ${review.reply}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onReply, child: Text(t.replyToReview)),
          ),
        ],
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.initial});

  final String initial;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.venueReply),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 1000,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(t.reviewSend),
        ),
      ],
    );
  }
}
