import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
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

/// A table, reached by scanning its QR.
///
/// Nobody is asked to sign in here. If the scan resolves to a real table and
/// there is no session, one is created for it silently — a diner already
/// sitting at the table should not have to make an account to order from it.
class QrTableScreen extends ConsumerStatefulWidget {
  const QrTableScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<QrTableScreen> createState() => _QrTableScreenState();
}

class _QrTableScreenState extends ConsumerState<QrTableScreen> {
  var _asked = false;

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final qr = ref.watch(qrTableProvider(token));
    // Checked here rather than through ref.listen: the scan may already be
    // cached, and a listener only fires on a change it would then never see.
    // Only once it has resolved, too — a session is worth creating for a real
    // table, not for a mistyped link.
    if (qr.hasValue && !_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(authControllerProvider.notifier).ensureGuest(token));
      });
    }
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
