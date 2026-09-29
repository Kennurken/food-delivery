import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/courier_earnings.dart';
import '../domain/payout_row.dart';

class EarningsRepository {
  EarningsRepository(this._dio);

  final Dio _dio;

  Future<CourierEarnings> fetch({int days = 7}) async {
    final r = await _dio.get(
      '/api/v1/me/earnings',
      queryParameters: {'days': days},
    );
    return CourierEarnings.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<PayoutPage> history({int? before}) async {
    final r = await _dio.get(
      '/api/v1/me/earnings/history',
      queryParameters: {'limit': 20, 'before': ?before},
    );
    return PayoutPage.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => EarningsRepository(ref.watch(dioProvider)),
);

/// The window the courier picked. Riverpod 3: a Notifier, never StateProvider.
class EarningsWindow extends Notifier<int> {
  @override
  int build() => 7;

  void set(int days) => state = days;
}

final earningsWindowProvider = NotifierProvider<EarningsWindow, int>(
  EarningsWindow.new,
);

final earningsProvider = FutureProvider<CourierEarnings>((ref) {
  final days = ref.watch(earningsWindowProvider);
  return ref.watch(earningsRepositoryProvider).fetch(days: days);
});

/// What the history list shows: the rows so far, where the next page starts,
/// and whether that page is on its way.
class PayoutHistoryState {
  const PayoutHistoryState({
    required this.rows,
    required this.nextBefore,
    this.loadingMore = false,
  });

  final List<PayoutRow> rows;
  final int? nextBefore;
  final bool loadingMore;

  bool get hasMore => nextBefore != null;
}

/// The courier's deliveries, newest first, a page at a time.
///
/// Loading the next page keeps the rows on screen: the list only grows. It
/// starts over when the wallet's window changes, the same moment the totals
/// above it reload.
class PayoutHistory extends AsyncNotifier<PayoutHistoryState> {
  @override
  Future<PayoutHistoryState> build() async {
    ref.watch(earningsWindowProvider);
    final page = await ref.watch(earningsRepositoryProvider).history();
    return PayoutHistoryState(rows: page.items, nextBefore: page.nextBefore);
  }

  Future<void> loadMore() async {
    final now = state.value;
    if (now == null || now.loadingMore || !now.hasMore) return;
    state = AsyncData(
      PayoutHistoryState(
        rows: now.rows,
        nextBefore: now.nextBefore,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(earningsRepositoryProvider)
          .history(before: now.nextBefore);
      state = AsyncData(
        PayoutHistoryState(
          rows: [...now.rows, ...page.items],
          nextBefore: page.nextBefore,
        ),
      );
    } catch (_) {
      // Keep what is on screen; the button comes back for another try.
      state = AsyncData(now);
      rethrow;
    }
  }
}

final payoutHistoryProvider =
    AsyncNotifierProvider<PayoutHistory, PayoutHistoryState>(PayoutHistory.new);
