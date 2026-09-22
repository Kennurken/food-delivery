import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../restaurants/presentation/restaurant_screen.dart';

class QrTable {
  const QrTable({
    required this.token,
    required this.restaurantId,
    required this.tableName,
  });

  final String token;
  final int restaurantId;
  final String tableName;

  factory QrTable.fromJson(Map<String, dynamic> json) => QrTable(
    token: json['token'] as String,
    restaurantId: json['restaurant_id'] as int,
    tableName: (json['table'] as Map)['name'] as String? ?? 'Table',
  );
}

final qrTableProvider = FutureProvider.family<QrTable, String>((
  ref,
  token,
) async {
  final dio = ref.watch(dioProvider);
  final r = await dio.get('/api/v1/qr/$token');
  return QrTable.fromJson(r.data as Map<String, dynamic>);
});

class QrTableScreen extends ConsumerWidget {
  const QrTableScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qr = ref.watch(qrTableProvider(token));
    return qr.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(errorMessage(e))),
      ),
      data: (q) => RestaurantScreen(
        id: q.restaurantId,
        tableToken: q.token,
        tableLabel: q.tableName,
      ),
    );
  }
}
