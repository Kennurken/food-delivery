import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// The venue's side of a review: answering it.
class ReviewsAdminRepository {
  ReviewsAdminRepository(this._dio);

  final Dio _dio;

  Future<void> reply(int orderId, String text) async {
    await _dio.post(
      '/api/v1/admin/orders/$orderId/review-reply',
      data: {'text': text.trim()},
    );
  }
}

final reviewsAdminRepositoryProvider = Provider<ReviewsAdminRepository>(
  (ref) => ReviewsAdminRepository(ref.watch(dioProvider)),
);
