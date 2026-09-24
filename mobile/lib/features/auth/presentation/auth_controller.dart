import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../notifications/device_repository.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Holds current user. `null` = signed out. Loading only on app start.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    ref.listen(authExpiredProvider, (prev, next) {
      if (prev != null && next != prev) {
        unawaited(ref.read(deviceRepositoryProvider).forget());
        state = const AsyncData(null);
      }
    });
    final user = await ref.read(authRepositoryProvider).me();
    if (user != null) unawaited(ref.read(deviceRepositoryProvider).sync());
    return user;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email, password),
    );
    if (state.value != null) {
      unawaited(ref.read(deviceRepositoryProvider).sync());
    }
  }

  /// Signs in as a table guest if nobody is signed in. Does nothing when
  /// somebody already is — a regular customer scanning a QR keeps their own
  /// account and their order history with it.
  Future<void> ensureGuest(String qrToken) async {
    if (state.value != null) return;
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).guest(qrToken),
    );
  }

  Future<void> register({
    required String email,
    required String name,
    required String password,
    String? phone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .register(email: email, name: name, password: password, phone: phone),
    );
    if (state.value != null) {
      unawaited(ref.read(deviceRepositoryProvider).sync());
    }
  }

  /// Re-read /me after a profile change.
  Future<void> refresh() async {
    state = AsyncData(await ref.read(authRepositoryProvider).me());
  }

  Future<void> logout() async {
    await ref.read(deviceRepositoryProvider).forget();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
