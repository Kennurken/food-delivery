import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class BillingConfig {
  const BillingConfig({this.card = false});

  final bool card;

  factory BillingConfig.fromJson(Map<String, dynamic> json) =>
      BillingConfig(card: json['card'] == true);
}

final billingConfigProvider = FutureProvider<BillingConfig>((ref) async {
  final r = await ref.watch(dioProvider).get('/api/v1/billing/config');
  return BillingConfig.fromJson(r.data as Map<String, dynamic>);
});
