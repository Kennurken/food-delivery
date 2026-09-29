import '../../../core/utils/server_time.dart';

/// Per-delivery payout row for the courier's history.
class PayoutRow {
  const PayoutRow({
    required this.orderId,
    required this.restaurantName,
    required this.at,
    required this.payout,
    required this.payMethod,
    required this.cashHeld,
  });

  final int orderId;
  final String restaurantName;
  final DateTime at;
  final double payout;
  final String payMethod;
  final double cashHeld;

  factory PayoutRow.fromJson(Map<String, dynamic> json) => PayoutRow(
    orderId: (json['order_id'] as num?)?.toInt() ?? 0,
    restaurantName: json['restaurant_name'] as String? ?? '',
    at:
        parseServerTime(json['at'] as String?) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    payout: (json['payout'] as num?)?.toDouble() ?? 0,
    payMethod: json['pay_method'] as String? ?? '',
    cashHeld: (json['cash_held'] as num?)?.toDouble() ?? 0,
  );
}

class PayoutPage {
  const PayoutPage({required this.items, required this.nextBefore});

  final List<PayoutRow> items;
  final int? nextBefore;

  factory PayoutPage.fromJson(Map<String, dynamic> json) => PayoutPage(
    items: ((json['items'] as List?) ?? const [])
        .map((e) => PayoutRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    nextBefore: (json['next_before'] as num?)?.toInt(),
  );
}
