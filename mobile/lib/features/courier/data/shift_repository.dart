import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Whether the courier is on the line. Off the line the server shows them no
/// orders and refuses to give them one.
class ShiftRepository {
  ShiftRepository(this._dio);

  final Dio _dio;

  Future<bool> read() async {
    final r = await _dio.get('/api/v1/me/shift');
    return (r.data as Map)['on_shift'] as bool;
  }

  Future<bool> set(bool on) async {
    final r = await _dio.post('/api/v1/me/shift', data: {'on': on});
    return (r.data as Map)['on_shift'] as bool;
  }
}

final shiftRepositoryProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(ref.watch(dioProvider)),
);

class Shift extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(shiftRepositoryProvider).read();

  /// Flips the switch on the server, then in the app: the switch never shows
  /// a state the server didn't accept (going off with an order in hand is
  /// refused, and the error reaches the caller).
  Future<void> set(bool on) async {
    final accepted = await ref.read(shiftRepositoryProvider).set(on);
    state = AsyncData(accepted);
  }
}

final shiftProvider = AsyncNotifierProvider<Shift, bool>(Shift.new);
